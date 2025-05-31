import Foundation
import RxSwift

/// Protocol defining navigation actions related to the User Detail screen.
/// Any navigator responsible for User Detail flow should conform to this.
public protocol UserDetailNavigator {
    /// Pop the current view controller (go back).
    func pop()
    /// Show a generic error alert (e.g., when fetch fails).
    func showError()
}

/// Default implementation of `UserDetailNavigator` that uses a `UINavigationController`
/// to perform navigation and present alerts.
class DefaultUserDetailNavigator {
    /// A weak reference to the navigation controller used to push/pop or present alerts.
    weak var navigation: UINavigationController?
    
    /// Initialize with a navigation controller. Pass `nil` if not available.
    /// - Parameter navigation: The `UINavigationController` used for navigation.
    init(navigation: UINavigationController?) {
        self.navigation = navigation
    }
}

/// Conform `DefaultUserDetailNavigator` to the `UserDetailNavigator` protocol.
extension DefaultUserDetailNavigator: UserDetailNavigator {
    
    /// Present a generic alert indicating something went wrong.
    /// The alert has a title, message, and a single "OK" button to dismiss.
    func showError() {
        let alert = UIAlertController(
            title: "Oops! Something went wrong.",
            message: "An error occurred while fetching user details. Please try again later.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        // Present the alert modally over the current view controller.
        self.navigation?.present(alert, animated: true)
    }
    
    /// Pop the top view controller from the navigation stack, animating the transition.
    func pop() {
        self.navigation?.popViewController(animated: true)
    }
}
