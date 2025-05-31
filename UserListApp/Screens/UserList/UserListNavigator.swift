import Foundation
import RxSwift

protocol UserListNavigator {
    func showError()
    func showUserDetail(user: UserModel)
}

class DefaultUserListNavigator { 

    weak var navigation: UINavigationController?

    init(navigation: UINavigationController?) {
        self.navigation = navigation
    }
}

extension DefaultUserListNavigator: UserListNavigator {
    func showError() {
        let alert = UIAlertController(title: "Opps! Something went wrong.",
                                      message: "Something error occurred while fetching users. Please try again later.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        self.navigation?.present(alert, animated: true)
    }
    
    func showUserDetail(user: UserModel) {
        let navigator = DefaultUserDetailNavigator(navigation: self.navigation)
        let useCase = DefaultUserDetailUsecase()
        let viewModel = UserDetailViewModel(user: user, useCase: useCase, navigator: navigator)
        let vc = UserDetailViewController(viewModel: viewModel)
        self.navigation?.pushViewController(vc, animated: true)
    }
}
