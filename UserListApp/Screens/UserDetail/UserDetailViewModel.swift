
import Foundation
import RxSwift
import RxCocoa

class UserDetailViewModel {
    
    let useCase: UserDetailUsecase
    let navigator: UserDetailNavigator
    let user: UserModel
    
    let disposeBag = DisposeBag()
    
    init(user: UserModel,
         useCase: UserDetailUsecase,
         navigator: UserDetailNavigator) {
        self.useCase = useCase
        self.navigator = navigator
        self.user = user
    }
    
    func transform(_ input: Input) -> Output {
        
        let errorTracker = ErrorTracker()
        let indicator = ActivityIndicator()
        
        input.backTriggerred
            .subscribe( onNext: { [weak self] in
                self?.navigator.pop()
            })
            .disposed(by: disposeBag)
        
        let userDetailRequest = self.useCase.fetchUserDetail(login: user.login ?? "")
            .trackError(errorTracker)
            .trackActivity(indicator)
            .catchErrorAndJustCompleted()
        
        errorTracker.asDriver()
            .drive(onNext: { [weak self] _ in
                self?.navigator.showError()
            })
            .disposed(by: disposeBag)
        
        return Output(userDetail: userDetailRequest.asDriverOnErrorJustComplete())
    }
    
    struct Input {
        let backTriggerred: Observable<Void>
    }
    
    struct Output {
        let userDetail: Driver<UserModel>
    }
}
