import Foundation
import RxSwift
import RxCocoa

/// ViewModel responsible for fetching and exposing detailed information for a single user,
/// and handling navigation events (e.g., going back, showing errors).
public class UserDetailViewModel {
    
    /// Use-case or business logic object for fetching user details.
    let useCase: UserDetailUsecase
    
    /// Navigator responsible for handling navigation actions (pop, show error, etc.).
    let navigator: UserDetailNavigator
    
    /// The UserModel representing the current user for which details are shown.
    let user: UserModel
    
    /// Dispose bag to hold all RxSwift subscriptions for this ViewModel.
    let disposeBag = DisposeBag()
    
    /// Initializes the ViewModel with the given user, use case, and navigator.
    /// - Parameters:
    ///   - user: The UserModel containing basic user data (e.g., login/username).
    ///   - useCase: The object responsible for fetching user detail from a repository or API.
    ///   - navigator: The object responsible for navigation actions (pop, showError).
    public init(
        user: UserModel,
        useCase: UserDetailUsecase,
        navigator: UserDetailNavigator
    ) {
        self.useCase = useCase
        self.navigator = navigator
        self.user = user
    }
    
    /// Transforms an Input into an Output by wiring up Rx chains for user detail fetching and navigation.
    /// - Parameter input: `Input` struct containing observables for user-triggered events (e.g., back button).
    /// - Returns: `Output` struct containing a Driver that emits `UserModel` details.
    public func transform(_ input: Input) -> Output {
        
        // ErrorTracker tracks any errors emitted during the user detail request.
        let errorTracker = ErrorTracker()
        // ActivityIndicator tracks the loading state of the user detail request.
        let indicator = ActivityIndicator()
        
        // Subscribe to the back button trigger. When backTriggerred emits,
        // instruct the navigator to pop (go back).
        input.backTriggerred
            .subscribe(onNext: { [weak self] in
                self?.navigator.pop()
            })
            .disposed(by: disposeBag)
        
        // Build an observable pipeline to fetch user detail:
        // 1. Call `fetchUserDetail(login:)` on the use case with the user's login.
        // 2. Track any errors (via `trackError`) so that ErrorTracker can respond.
        // 3. Track loading state (via `trackActivity`) so the ActivityIndicator toggles.
        // 4. If an error occurs, `catchErrorAndJustCompleted` will swallow the error
        //    and complete the sequence (preventing it from propagating further).
        let userDetailRequest = self.useCase
            .fetchUserDetail(login: user.login ?? "", cachable: true)
            .trackError(errorTracker)
            .trackActivity(indicator)
            .catchErrorAndJustCompleted()
        
        // Whenever ErrorTracker emits an error, drive the navigator to show an error alert.
        errorTracker
            .asDriver()
            .drive(onNext: { [weak self] _ in
                self?.navigator.showError()
            })
            .disposed(by: disposeBag)
        
        // Convert the user detail observable into a Driver (UI-friendly) and return it as Output.
        return Output(userDetail: Driver.merge([userDetailRequest.asDriverOnErrorJustComplete(), .just(user)]))
    }
    
    /// Input struct defines all events (as observables) that the ViewModel can respond to.
    public struct Input {
        /// Observable that emits when the back action is triggered (e.g., user taps back button).
        public let backTriggerred: Observable<Void>
        
        /// Initializes Input with a back trigger observable.
        /// - Parameter backTriggerred: Observable<Void> that fires when user requests to go back.
        public init(backTriggerred: Observable<Void>) {
            self.backTriggerred = backTriggerred
        }
    }
    
    /// Output struct defines all streams (as Drivers) that the ViewModel exposes to the View.
    public struct Output {
        /// Driver emitting the fetched `UserModel` detail.
        public let userDetail: Driver<UserModel>
    }
}
