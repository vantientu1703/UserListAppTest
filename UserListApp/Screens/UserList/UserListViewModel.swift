
import Foundation
import RxSwift
import RxCocoa

class UserListViewModel {
    
    let useCase: UserListUsecase
    let navigator: UserListNavigator
    
    let size = 20
    var since = 0
    
    let disposeBag = DisposeBag()

    init(useCase: UserListUsecase, navigator: UserListNavigator) {
        self.useCase = useCase
        self.navigator = navigator
    }

    func transform(_ input: Input) -> Output {
        let firstLoad = Observable.just(())
        
        let errorTracker = ErrorTracker()
        let indicator = ActivityIndicator()
        
        let firstRequest = firstLoad
            .flatMapLatest { [weak self] _ -> Observable<[UserModel]> in
                guard let self else { return .empty() }
                return self.useCase.fetchUserList(size: self.size, since: self.since)
                    .trackActivity(indicator)
                    .trackError(errorTracker)
                    .catchErrorAndJustCompleted()
            }
        
        let refreshRequest = input.refresh
            .debounce(RxTimeInterval.milliseconds(100), scheduler: ConcurrentDispatchQueueScheduler(queue: DispatchQueue.global()))
            .withLatestFrom(indicator)
            .filter({ !$0 })
            .flatMapLatest { [weak self] _ -> Observable<[UserModel]> in
                guard let self else { return .empty() }
                self.since = 0
                return self.useCase.fetchUserList(size: self.size, since: self.since)
                    .trackActivity(indicator)
                    .trackError(errorTracker)
                    .catchErrorAndJustCompleted()
            }
        
        let loadMoreRequest = input.loadMore
            .withLatestFrom(indicator)
            .filter({ !$0 })
            .flatMapLatest { [weak self] _ -> Observable<[UserModel]> in
                guard let self else { return .empty() }
                self.since += self.size
                return self.useCase.fetchUserList(size: self.size, since: self.since)
                    .trackActivity(indicator)
                    .trackError(errorTracker)
                    .catchErrorAndJustCompleted()
            }
        
        let loadMoreData = firstRequest.flatMapLatest { users in
            return loadMoreRequest.startWith([])
                .scan(users) { pr, res in
                    return res + pr
                }
        }
        
        let dataSection = Observable.merge([firstRequest,
                                            refreshRequest,
                                            loadMoreData])
            .distinctUntilChanged()
            .map({ $0.uniqueIdentities() })
            .map { [UserSection.userList(items: $0)] }
        
        errorTracker
            .asDriver()
            .drive { [weak self] _ in
                self?.navigator.showError()
            }
            .disposed(by: disposeBag)
        
        input.modelSelected
            .asDriverOnErrorJustComplete()
            .drive { [weak self] model in
                guard let self else { return }
                self.navigator.showUserDetail(user: model)
            }
            .disposed(by: disposeBag)
        
        return Output(userList: dataSection.asDriverOnErrorJustComplete())
    }
    
    struct Input {
        let refresh: Observable<Void>
        let loadMore: Observable<Void>
        let modelSelected: Observable<UserModel>
    }

    struct Output {
        let userList: Driver<[UserSection]>
    }
}
