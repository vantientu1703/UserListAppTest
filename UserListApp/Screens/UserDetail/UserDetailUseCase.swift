import Foundation
import RxSwift

protocol UserDetailUsecase {
    func fetchUserDetail(login: String) -> Observable<UserModel>
}

class DefaultUserDetailUsecase { 

    let service = UserClient(dataProvider: TDataProvider(), serverURI: .common)

    init() {
        
    }
}

extension DefaultUserDetailUsecase: UserDetailUsecase {
    func fetchUserDetail(login: String) -> RxSwift.Observable<UserModel> {
        return self.service.fetchUserDetail(loginUserName: login)
    }
}
