import Foundation
import RxSwift

/// Protocol defining the user detail use-case interface.
/// Any implementing class should provide a method to fetch detailed information for a user by login.
public protocol UserDetailUsecase {
    /// Fetches detailed information for a single user, given their login (username).
    /// - Parameter login: The username of the user whose details are to be fetched.
    /// - Returns: An Observable emitting the UserModel on success or an error on failure.
    func fetchUserDetail(login: String, cachable: Bool) -> Observable<UserModel>
}

/// Default implementation of the UserDetailUsecase protocol.
/// Internally uses a `UserClient` to perform the network request.
class DefaultUserDetailUsecase {
    /// Underlying service responsible for making HTTP requests and parsing responses.
    /// Initialized with a default TDataProvider and points to the common server URI.
    let service = UserClient(dataProvider: TDataProvider(), serverURI: .common)
}

/// Extend DefaultUserDetailUsecase to conform to UserDetailUsecase.
/// Forwards calls to the underlying `UserClient`.
extension DefaultUserDetailUsecase: UserDetailUsecase {
    /// Fetches user detail by delegating to the `UserClient`.
    /// - Parameter login: The username of the user to retrieve.
    /// - Returns: An Observable that emits the `UserModel` or an error.
    func fetchUserDetail(login: String, cachable: Bool) -> RxSwift.Observable<UserModel> {
        return self.service.fetchUserDetail(loginUserName: login, cachable: cachable)
    }
}
