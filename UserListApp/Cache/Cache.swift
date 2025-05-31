
import Foundation


final class Cache<Key: Hashable, Value> {
    
    private let wrapped = NSCache<WrappedKey, Entry>()
    private let dateProvider: () -> Date
    private let entryLifetime: TimeInterval
    private let keyTracker = KeyTracker()
    
    init(dateProvider: @escaping () -> Date = Date.init,
         entryLifetime: TimeInterval = 12 * 60 * 60) {
        
        self.dateProvider = dateProvider
        self.entryLifetime = entryLifetime
        wrapped.delegate = keyTracker
    }
    
    func insert(_ value: Value, forKey key: Key) {
        let date = dateProvider().addingTimeInterval(entryLifetime)
        let entry = Entry(key: key, value: value, expirationDate: date)
        wrapped.setObject(entry, forKey: WrappedKey(key))
        keyTracker.keys.insert(key)
    }
    
    func value(forKey key: Key) -> Value? {
        guard let entry = wrapped.object(forKey: WrappedKey(key)) else {
            return nil
        }
        
        guard dateProvider() < entry.expirationDate else {
            // Discard values that have expired
            removeValue(forKey: key)
            return nil
        }
        
        return entry.value
    }
    
    func removeValue(forKey key: Key) {
        wrapped.removeObject(forKey: WrappedKey(key))
    }
    
    final class Entry {
        let key: Key
        let value: Value
        let expirationDate: Date
        
        init(key: Key, value: Value, expirationDate: Date) {
            self.key = key
            self.value = value
            self.expirationDate = expirationDate
        }
    }
}

private extension Cache {
    final class KeyTracker: NSObject, NSCacheDelegate {
        var keys = Set<Key>()
        
        func cache(_ cache: NSCache<AnyObject, AnyObject>,
                   willEvictObject object: Any) {
            guard let entry = object as? Entry else {
                return
            }
            
            keys.remove(entry.key)
        }
    }
}

private extension Cache {
    final class WrappedKey: NSObject {
        let key: Key
        
        init(_ key: Key) { self.key = key }
        
        override var hash: Int { return key.hashValue }
        
        override func isEqual(_ object: Any?) -> Bool {
            guard let value = object as? WrappedKey else {
                return false
            }
            
            return value.key == key
        }
    }
}

extension Cache {
    subscript(key: Key) -> Value? {
        get { return value(forKey: key) }
        set {
            guard let value = newValue else {
                removeValue(forKey: key)
                return
            }
            
            insert(value, forKey: key)
        }
    }
}

extension Cache.Entry: Codable where Key: Codable, Value: Codable {}

private extension Cache {
    func entry(forKey key: Key) -> Entry? {
        guard let entry = wrapped.object(forKey: WrappedKey(key)) else {
            return nil
        }
        
        guard dateProvider() < entry.expirationDate else {
            removeValue(forKey: key)
            return nil
        }
        
        return entry
    }
    
    func insert(_ entry: Entry) {
        wrapped.setObject(entry, forKey: WrappedKey(entry.key))
        keyTracker.keys.insert(entry.key)
    }
}

extension Cache: Codable where Key: Codable, Value: Codable {
    convenience init(from decoder: Decoder) throws {
        self.init()
        
        let container = try decoder.singleValueContainer()
        let entries = try container.decode([Entry].self)
        entries.forEach(insert)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(keyTracker.keys.compactMap(entry))
    }
}

extension Cache where Key: Codable, Value: Codable {
    
    private static func cacheFileURL(
        named name: String,
        using fileManager: FileManager = .default
    ) throws -> URL {
        let folderURLs = fileManager.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )
        guard let cachesDirectory = folderURLs.first else {
            throw NSError(
                domain: "CacheError",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "not found cache"]
            )
        }
        return cachesDirectory.appendingPathComponent(name + ".cache")
    }
    
    func saveToDisk(
        withName name: String,
        using fileManager: FileManager = .default
    ) throws {
        let fileURL = try Cache.cacheFileURL(named: name, using: fileManager)
        let data = try JSONEncoder().encode(self)
        try data.write(to: fileURL)
    }
    
    func removeFromDisk(
        withName name: String,
        using fileManager: FileManager = .default
    ) throws {
        let fileURL = try Cache.cacheFileURL(named: name, using: fileManager)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }
    
    /// Load cache từ disk và trả về một instance mới
    static func getCache(
        withName name: String,
        using fileManager: FileManager = .default
    ) throws -> Self {
        let fileURL = try Cache.cacheFileURL(named: name, using: fileManager)
        
        // Đọc data và decode
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(Self.self, from: data)
    }
}


typealias UserListCache = Cache<String, [UserModel]>


class UserListCacheManager {
    
    private let dataCachedName = "DataCache"
    let cache: UserListCache
    
    init() {
        if let cache = try? UserListCache.getCache(withName: dataCachedName) {
            self.cache = cache
            return
        }
        self.cache = UserListCache.init()
    }
    
    func setUserList(_ userList: [UserModel], forKey key: String) {
        cache.insert(userList, forKey: key)
        try? cache.saveToDisk(withName: dataCachedName)
    }
    
    func getUserList(forKey key: String) -> [UserModel] {
        cache.value(forKey: key) ?? []
    }
}
