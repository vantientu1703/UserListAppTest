

import Foundation
import RxSwift

protocol UserListUsecase {
    func fetchUserList(size: Int, since: Int) -> Observable<[UserModel]>
    func fetchUserDetail(loginUserName: String) -> Observable<UserModel>
}

class DefaultUserListUsecase { 

    let service: UserClient = UserClient(dataProvider: TDataProvider(), serverURI: .common)
}

extension DefaultUserListUsecase: UserListUsecase {
    func fetchUserList(size: Int, since: Int) -> RxSwift.Observable<[UserModel]> {
        return service.fetchUserList(perPage: size, since: since)
    }
    
    func fetchUserDetail(loginUserName: String) -> RxSwift.Observable<UserModel> {
        return service.fetchUserDetail(loginUserName: loginUserName)
    }
}
