import Foundation
import RxSwift

/// Protocol defining the use-case interface for fetching user lists and user details.
/// This abstraction allows the ViewModel or other layers to depend on an interface rather than a concrete service.
public protocol UserListUsecase {
    /// Fetch a paginated list of users.
    /// - Parameters:
    ///   - size: Number of users to fetch in one page.
    ///   - since: Offset or ID from which to start fetching the next page.
    ///   - cachable: Whether to attempt to read from cache before making a network call.
    /// - Returns: An Observable emitting an array of `UserModel` or an error.
    func fetchUserList(size: Int, since: Int, cachable: Bool) -> Observable<[UserModel]>
}

/// Default implementation of `UserListUsecase`.
/// Uses `UserClient` (which encapsulates network & caching logic) to perform the actual data retrieval.
class DefaultUserListUsecase {
    /// The underlying service responsible for network requests and caching.
    /// Initialized with a default `TDataProvider` (URLSession-based) and a common server URI.
    let service: UserClient = UserClient(dataProvider: TDataProvider(), serverURI: .common)
}

/// Conform `DefaultUserListUsecase` to the `UserListUsecase` protocol,
/// forwarding each call to the underlying `UserClient`.
extension DefaultUserListUsecase: UserListUsecase {
    /// Fetch a paginated list of users by delegating to `UserClient`.
    /// - SeeAlso: `UserClient.fetchUserList(perPage:since:cachable:)`
    func fetchUserList(size: Int, since: Int, cachable: Bool) -> RxSwift.Observable<[UserModel]> {
        return service.fetchUserList(perPage: size, since: since, cachable: cachable)
    }
}
