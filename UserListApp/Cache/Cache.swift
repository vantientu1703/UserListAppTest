import Foundation

/// A generic cache that stores values in memory with expiration using NSCache.
/// - Key: The type of the cache key (must conform to Hashable).
/// - Value: The type of the cached value.
final class Cache<Key: Hashable, Value> {
    
    /// Underlying NSCache storing `Entry` objects, keyed by `WrappedKey`.
    private let wrapped = NSCache<WrappedKey, Entry>()
    
    /// Closure providing the current date; used to calculate expiration.
    private let dateProvider: () -> Date
    
    /// How long (in seconds) each cache entry remains valid.
    private let entryLifetime: TimeInterval
    
    /// Helper object that tracks all active keys in the cache.
    private let keyTracker = KeyTracker()
    
    /// Initializes a new Cache.
    /// - Parameters:
    ///   - dateProvider: Closure returning current Date (default: Date.init).
    ///   - entryLifetime: Time interval before entries expire (default: 12 hours).
    init(dateProvider: @escaping () -> Date = Date.init,
         entryLifetime: TimeInterval = 12 * 60 * 60) {
        
        self.dateProvider = dateProvider
        self.entryLifetime = entryLifetime
        
        // Assign delegate so that `keyTracker` is notified when NSCache evicts entries
        wrapped.delegate = keyTracker
    }
    
    /// Inserts a value into the cache under the given key.
    /// Calculates an expiration date based on the current date plus `entryLifetime`.
    /// - Parameters:
    ///   - value: The value to cache.
    ///   - key: The key under which to store this value.
    func insert(_ value: Value, forKey key: Key) {
        // Compute expiration date by adding entryLifetime to the current date
        let expirationDate = dateProvider().addingTimeInterval(entryLifetime)
        // Wrap the key, value, and expiration date into an Entry
        let entry = Entry(key: key, value: value, expirationDate: expirationDate)
        // Store the Entry in the NSCache using a WrappedKey wrapper
        wrapped.setObject(entry, forKey: WrappedKey(key))
        // Track the key so we know which keys exist in the cache
        keyTracker.keys.insert(key)
    }
    
    /// Retrieves the cached value for the given key, if it exists and has not expired.
    /// - Parameter key: The key to look up.
    /// - Returns: The cached value, or nil if not found or expired.
    func value(forKey key: Key) -> Value? {
        // Attempt to get the Entry from NSCache
        guard let entry = wrapped.object(forKey: WrappedKey(key)) else {
            return nil
        }
        
        // If the current date is after the expiration date, remove and return nil
        guard dateProvider() < entry.expirationDate else {
            removeValue(forKey: key)
            return nil
        }
        
        // Otherwise, return the stored value
        return entry.value
    }
    
    /// Removes the cached entry for the given key, if it exists.
    /// - Parameter key: The key whose value should be removed.
    func removeValue(forKey key: Key) {
        wrapped.removeObject(forKey: WrappedKey(key))
        // NSCacheDelegate (KeyTracker) will automatically remove the key from its set
    }
    
    /// Represents a single cache entry, containing the key, value, and expiration date.
    final class Entry {
        let key: Key
        let value: Value
        let expirationDate: Date
        
        /// Initializes a new Entry.
        /// - Parameters:
        ///   - key: The key for this entry.
        ///   - value: The cached value.
        ///   - expirationDate: Date at which this entry expires.
        init(key: Key, value: Value, expirationDate: Date) {
            self.key = key
            self.value = value
            self.expirationDate = expirationDate
        }
    }
}

// MARK: - KeyTracker: NSCacheDelegate to track evicted keys

private extension Cache {
    /// Tracks which keys are currently stored in the NSCache.
    final class KeyTracker: NSObject, NSCacheDelegate {
        /// Set of all keys currently in the cache.
        var keys = Set<Key>()
        
        /// Called by NSCache when it evicts an object.
        /// Removes the associated key from the `keys` set.
        func cache(_ cache: NSCache<AnyObject, AnyObject>,
                   willEvictObject object: Any) {
            guard let entry = object as? Entry else {
                return
            }
            // Remove the key from our tracker when the entry is evicted
            keys.remove(entry.key)
        }
    }
}

// MARK: - WrappedKey: NSObject wrapper for Hashable Key

private extension Cache {
    /// Wraps a generic Hashable `Key` so it can be used as an NSObject key in NSCache.
    final class WrappedKey: NSObject {
        let key: Key
        
        init(_ key: Key) { self.key = key }
        
        /// Must override hash to match the underlying key's hashValue.
        override var hash: Int { return key.hashValue }
        
        /// Determines equality by comparing the underlying Key.
        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? WrappedKey else {
                return false
            }
            return other.key == key
        }
    }
}

// MARK: - Subscript convenience for reading/writing

extension Cache {
    /// Allows syntax `cache[key]` to get or set values.
    subscript(key: Key) -> Value? {
        get {
            return value(forKey: key)
        }
        set {
            guard let newValue = newValue else {
                // If setting nil, remove the key
                removeValue(forKey: key)
                return
            }
            // Otherwise, insert the new value
            insert(newValue, forKey: key)
        }
    }
}

// MARK: - Codable conformance for Entry (requires Key & Value to be Codable)

extension Cache.Entry: Codable where Key: Codable, Value: Codable {}

// MARK: - Helper methods for encoding/decoding Cache

private extension Cache {
    /// Retrieves an existing Entry from NSCache if it exists and is not expired.
    /// Used when encoding the cache to skip expired entries.
    /// - Parameter key: The key to look up.
    /// - Returns: Entry if present and valid, else nil.
    func entry(forKey key: Key) -> Entry? {
        guard let entry = wrapped.object(forKey: WrappedKey(key)) else {
            return nil
        }
        // If expired, remove and return nil
        guard dateProvider() < entry.expirationDate else {
            removeValue(forKey: key)
            return nil
        }
        return entry
    }
    
    /// Inserts an Entry back into NSCache, updating the keyTracker accordingly.
    /// Used when decoding the cache from disk.
    /// - Parameter entry: The Entry to insert.
    func insert(_ entry: Entry) {
        wrapped.setObject(entry, forKey: WrappedKey(entry.key))
        keyTracker.keys.insert(entry.key)
    }
}

extension Cache: Codable where Key: Codable, Value: Codable {
    /// Initializes a Cache from decoded JSON data.
    /// Decodes an array of `Entry` objects and re-inserts them into NSCache.
    /// - Parameter decoder: JSON decoder.
    convenience init(from decoder: Decoder) throws {
        self.init()
        
        // Decode array of Entry (each Entry: Key, Value, expirationDate)
        let container = try decoder.singleValueContainer()
        let entries = try container.decode([Entry].self)
        // Insert each entry back into our NSCache
        entries.forEach(insert)
    }
    
    /// Encodes the Cache to JSON by writing out all non-expired entries.
    /// - Parameter encoder: JSON encoder.
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        // Get all valid entries (using entry(forKey:)) and encode them as an array
        try container.encode(keyTracker.keys.compactMap(entry))
    }
}

// MARK: - Disk persistence for Cache when Key & Value are Codable

extension Cache where Key: Codable, Value: Codable {
    
    /// Returns a file URL in the Caches directory for a given cache name.
    /// - Parameters:
    ///   - name: The base file name (without extension).
    ///   - fileManager: FileManager instance (default: .default).
    /// - Returns: URL pointing to ".../Caches/{name}.cache".
    /// - Throws: Error if Caches directory cannot be found.
    private static func cacheFileURL(
        named name: String,
        using fileManager: FileManager = .default
    ) throws -> URL {
        let folderURLs = fileManager.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )
        // Ensure we have a Caches directory
        guard let cachesDirectory = folderURLs.first else {
            throw NSError(
                domain: "CacheError",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Caches directory not found"]
            )
        }
        // Append the file name + ".cache"
        return cachesDirectory.appendingPathComponent(name + ".cache")
    }
    
    /// Saves the entire cache to disk as JSON.
    /// - Parameters:
    ///   - name: File name (without extension).
    ///   - fileManager: FileManager to use (default: .default).
    /// - Throws: An error if encoding or writing fails.
    func saveToDisk(
        withName name: String,
        using fileManager: FileManager = .default
    ) throws {
        // Build the file URL in Caches directory
        let fileURL = try Cache.cacheFileURL(named: name, using: fileManager)
        // Encode self (the Cache) into Data via JSONEncoder
        let data = try JSONEncoder().encode(self)
        // Write the data to disk
        try data.write(to: fileURL)
    }
    
    /// Removes the cache file from disk, if it exists.
    /// - Parameters:
    ///   - name: File name (without extension).
    ///   - fileManager: FileManager to use (default: .default).
    /// - Throws: Error if removal fails.
    func removeFromDisk(
        withName name: String,
        using fileManager: FileManager = .default
    ) throws {
        let fileURL = try Cache.cacheFileURL(named: name, using: fileManager)
        // If file exists at that path, delete it
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }
    
    /// Loads a cache from disk by reading and decoding JSON.
    /// - Parameters:
    ///   - name: File name (without extension).
    ///   - fileManager: FileManager to use (default: .default).
    /// - Returns: A decoded Cache instance.
    /// - Throws: Error if reading or decoding fails.
    static func getCache(
        withName name: String,
        using fileManager: FileManager = .default
    ) throws -> Self {
        let fileURL = try Cache.cacheFileURL(named: name, using: fileManager)
        // Read raw data from the file
        let data = try Data(contentsOf: fileURL)
        // Decode the Cache from JSON
        return try JSONDecoder().decode(Self.self, from: data)
    }
}

// MARK: - Specialized typealias for caching user lists

/// A specialized Cache mapping String keys (e.g. request URL) to an array of `UserModel`.
typealias DataCache<T: Codable> = Cache<String, T>

/// Manages the user-list-specific cache, handling both in-memory and on-disk storage.
class DataCacheManager<T: Codable> {
    
    /// The fixed file name (without extension) under Caches directory for persisting user-list cache.
    private let dataCachedName = "DataCache"
    
    /// The in-memory cache instance.
    let cache: DataCache<T>
    
    /// Initializes the manager by attempting to load a previously saved cache from disk.
    /// If loading fails, creates a new empty cache.
    init() {
        if let diskCache: DataCache<T> = try? DataCache.getCache(withName: dataCachedName) {
            self.cache = diskCache
            return
        }
        // If no existing file or decoding fails, create a fresh cache
        self.cache = DataCache<T>()
    }
    
    /// Stores a user-list array in the cache under a given key, then saves the cache to disk.
    /// - Parameters:
    ///   - userList: Array of `UserModel` to cache.
    ///   - key: Typically the request URL string used as cache key.
    func set(_ data: T, forKey key: String) {
        cache.insert(data, forKey: key)
        // Attempt to save the updated cache to disk; ignore any errors
        try? cache.saveToDisk(withName: dataCachedName)
    }
    
    /// Retrieves a cached user-list for the given key. Returns an empty array if not found or expired.
    /// - Parameter key: The cache key (URL string).
    /// - Returns: Cached `[UserModel]` or an empty array.
    func get(forKey key: String) -> T? {
        return cache.value(forKey: key)
    }
}
