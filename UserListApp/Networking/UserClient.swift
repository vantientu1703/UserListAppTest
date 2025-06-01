//
//  UserListClient.swift
//  UserListApp
//
//  Created by vantientu on 5/31/25.
//

import RxSwift
import Foundation

/// Protocol defining methods for fetching a list of users and fetching a single user's details.
/// Any client responsible for user-related network requests should conform to this protocol.
protocol UserClientProtocol {
    /// Fetch a paginated list of users.
    /// - Parameters:
    ///   - perPage: Number of users to return per page.
    ///   - since: Offset or ID indicating where to start fetching users.
    ///   - cachable: Whether to attempt to load results from cache before making a network request.
    /// - Returns: An Observable emitting an array of UserModel or an error.
    func fetchUserList(perPage: Int, since: Int, cachable: Bool) -> Observable<[UserModel]>
    
    /// Fetch detailed information for a single user by username.
    /// - Parameter loginUserName: The login (username) of the user to fetch.
    /// - Returns: An Observable emitting the UserModel or an error.
    func fetchUserDetail(loginUserName: String) -> Observable<UserModel>
}

/// Concrete implementation of `UserClientProtocol`. Responsible for sending API requests
/// related to users and caching certain results.
/// Inherits from `TBaseClient` to reuse common request-building and response-handling logic.
class UserClient: TBaseClient, UserClientProtocol {
    
    /// Cache manager for storing and retrieving paginated user lists to minimize duplicate requests.
    let dataCache = DataCacheManager<[UserModel]>()
    
    // MARK: - Fetch User Detail
    
    /// Fetch detailed information for a single user by login (username).
    /// - Parameter loginUserName: The login (username) of the user to fetch.
    /// - Returns: An Observable that emits a `UserModel` on success or an error on failure.
    func fetchUserDetail(loginUserName: String) -> RxSwift.Observable<UserModel> {
        // Create an Observable that wraps the network call
        return Observable<UserModel>.create { [weak self] observer in
            // If `self` has been deallocated, do nothing further
            guard let self = self else {
                return Disposables.create()
            }
            // Build the GET request for "/users/{loginUserName}"
            let parameters: [String: String]? = nil
            let request = constructRequest(
                with: "/users/\(loginUserName)",
                method: .GET,
                parameters: parameters
            )
            
            // Use the helper `objectResponse` to perform the network call and decode into UserModel
            objectResponse(from: request) { (result: Swift.Result<UserModel, Error>) in
                switch result {
                case .success(let data):
                    // On success, emit the decoded UserModel and complete
                    observer.onNext(data)
                    observer.onCompleted()
                case .failure(let error):
                    // On failure, emit the error
                    observer.onError(error)
                }
            }
            // Return a disposable since there's no cancelable resource here (URLSession is managed internally)
            return Disposables.create()
        }
    }
    
    // MARK: - Fetch User List
    
    /// Fetch a paginated list of users, with optional caching.
    /// - Parameters:
    ///   - perPage: Number of users per page.
    ///   - since: Offset or ID to begin fetching users from.
    ///   - cachable: Whether to check the cache first for existing data before making a network call.
    /// - Returns: An Observable that emits an array of `UserModel` or an error.
    func fetchUserList(perPage: Int, since: Int, cachable: Bool) -> Observable<[UserModel]> {
        return Observable<[UserModel]>.create { [weak self] observer in
            // If `self` has been deallocated, stop processing
            guard let self = self else {
                return Disposables.create()
            }
            // Build query parameters for pagination
            let parameters = [
                "per_page": "\(perPage)",
                "since": "\(since)"
            ]
            // Construct the GET request for "/users?per_page={perPage}&since={since}"
            let request = constructRequest(
                with: "/users",
                method: .GET,
                parameters: parameters
            )
            
            // Generate a cache key from the full URL string for this request
            let key = request?.url?.absoluteString ?? ""
            
            // If caching is enabled, attempt to load from cache first
            if cachable {
                let cachedData: [UserModel] = self.dataCache.get(forKey: key) ?? []
                // If cache contains non-empty data, emit it immediately and complete
                if !cachedData.isEmpty {
                    observer.onNext(cachedData)
                    observer.onCompleted()
                    return Disposables.create()
                }
            }
            
            // Otherwise, proceed with a network request
            objectResponse(from: request) { [weak self] (result: Swift.Result<[UserModel], Error>) in
                // If `self` has been deallocated, do nothing further
                guard let self = self else { return }
                switch result {
                case .success(let data):
                    // On success, emit the array of UserModel and complete
                    observer.onNext(data)
                    observer.onCompleted()
                    // If the returned data is non-empty, save it in the cache for future calls
                    if !data.isEmpty {
                        self.dataCache.set(data, forKey: key)
                    }
                case .failure(let error):
                    // On failure, emit the error
                    observer.onError(error)
                }
            }
            // Return a disposable since the network task is handled by URLSession (no explicit cancellation here)
            return Disposables.create()
        }
    }
}
