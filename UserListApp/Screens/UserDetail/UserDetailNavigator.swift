import Foundation
import RxSwift

protocol UserDetailNavigator {
    func pop()
    func showError()
}

class DefaultUserDetailNavigator { 

    weak var navigation: UINavigationController?

    init(navigation: UINavigationController?) {
        self.navigation = navigation
    }
}

extension DefaultUserDetailNavigator: UserDetailNavigator {
    
    func showError() {
        let alert = UIAlertController(title: "Opps! Something went wrong.",
                                      message: "Something error occurred while fetching users. Please try again later.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        self.navigation?.present(alert, animated: true)
    }
    
    func pop() {
        self.navigation?.popViewController(animated: true)
    }
}
