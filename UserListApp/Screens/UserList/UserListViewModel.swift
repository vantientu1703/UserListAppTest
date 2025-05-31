import Foundation
import RxSwift
import RxCocoa

/// ViewModel responsible for fetching, refreshing, and loading more users in a paginated list,
/// as well as handling user selection and error navigation.
public class UserListViewModel {
    
    /// Use-case or business logic object for retrieving user lists from a repository or API.
    let useCase: UserListUsecase
    
    /// Navigator responsible for page navigation actions such as showing details or errors.
    let navigator: UserListNavigator
    
    /// Fixed page size indicating how many users to fetch per request.
    let size = 20
    
    /// Tracks the current “since” offset (ID) for pagination.
    var since = 0
    
    /// Dispose bag to hold all RxSwift subscriptions for this ViewModel.
    let disposeBag = DisposeBag()

    /// Initializes the ViewModel with a use-case and navigator.
    /// - Parameters:
    ///   - useCase: The object responsible for interacting with data sources to fetch user lists.
    ///   - navigator: The object responsible for navigating between views (detail screen, error screens).
    public init(useCase: UserListUsecase, navigator: UserListNavigator) {
        self.useCase = useCase
        self.navigator = navigator
    }

    /// Transforms input observables (user actions) into output drivers (UI-binding data streams).
    /// This method builds and returns an Output struct containing a `userList` driver that emits
    /// the current list of users in a section format, automatically handling initial load, refresh,
    /// load more, error tracking, and navigation events.
    ///
    /// - Parameter input: `Input` containing observables for first load, refresh, load more, and item selection.
    /// - Returns: `Output` containing a `Driver<[UserSection]>` that the view can bind to for rendering.
    public func transform(_ input: Input) -> Output {
        
        // ErrorTracker collects any errors during network requests.
        let errorTracker = ErrorTracker()
        // ActivityIndicator tracks whether a network request is in progress (true) or idle (false).
        let indicator = ActivityIndicator()
        
        // MARK: - First Load Request
        // When `firstRequest` emits (e.g., the view appears), perform initial fetch with current `since`.
        let firstRequest = input.firstRequest
            .flatMapLatest { [weak self] _ -> Observable<[UserModel]> in
                // Safely unwrap `self`, otherwise return an empty observable
                guard let self = self else { return .empty() }
                // Fetch the first page of users; `cachable: true` means check cache first
                return self.useCase
                    .fetchUserList(size: self.size, since: self.since, cachable: true)
                    .trackActivity(indicator)      // Track loading indicator
                    .trackError(errorTracker)      // Track errors
                    .catchErrorAndJustCompleted()  // On error, complete without propagating
            }
        
        // MARK: - Refresh Request
        // When `refresh` emits (e.g., pull-to-refresh), debounce for 100ms, ensure not loading,
        // reset `since` to 0, and fetch fresh data without using cache (`cachable: false`).
        let refreshRequest = input.refresh
            .debounce(RxTimeInterval.milliseconds(100),
                      scheduler: ConcurrentDispatchQueueScheduler(queue: DispatchQueue.global()))
            .withLatestFrom(indicator)
            .filter({ !$0 }) // Only proceed if not currently loading
            .flatMapLatest { [weak self] _ -> Observable<[UserModel]> in
                guard let self = self else { return .empty() }
                // Reset pagination offset before refreshing
                self.since = 0
                return self.useCase
                    .fetchUserList(size: self.size, since: self.since, cachable: false)
                    .trackActivity(indicator)
                    .trackError(errorTracker)
                    .catchErrorAndJustCompleted()
            }
        
        // MARK: - Load More Request
        // When `loadMore` emits (e.g., user scrolls to bottom), check not loading, increment `since`,
        // then fetch the next page using cache if available.
        let loadMoreRequest = input.loadMore
            .withLatestFrom(indicator)
            .filter({ !$0 }) // Only if not currently loading
            .flatMapLatest { [weak self] _ -> Observable<[UserModel]> in
                guard let self = self else { return .empty() }
                // Advance offset by page size
                self.since += self.size
                return self.useCase
                    .fetchUserList(size: self.size, since: self.since, cachable: true)
                    .trackActivity(indicator)
                    .trackError(errorTracker)
                    .catchErrorAndJustCompleted()
            }
        
        // MARK: - Combine First Load + Load More into One Stream
        // Build a stream that emits a combined user array:
        // - Start with the initial page (`firstRequest`)
        // - Then every `loadMoreRequest` emission is scanned to prepend new results to existing list
        let loadMoreData = firstRequest.flatMapLatest { users in
            return loadMoreRequest
                .startWith([]) // Start with an empty array so that scan has an initial value
                .scan(users, accumulator: { result, newUsers in
                    return result + newUsers
                })
                .do(onNext: { users in
                    
                })
        }
        
        // Merge first load, refresh, and combined load-more streams. Then:
        // 1. distinctUntilChanged() to avoid emitting duplicates
        // 2. map each array of UserModel to remove duplicates via `uniqueIdentities()`
        // 3. wrap the resulting array in a `[UserSection.userList(items: ...)]` array so UI can bind sectioned data.
        let dataSection = Observable
            .merge([firstRequest, refreshRequest, loadMoreData])
            .distinctUntilChanged()
            .map({ $0.uniqueIdentities() })
            .do(onNext: { users in
                debugPrint("users load more count: \(users.count)")
            })
            .map { [UserSection.userList(items: $0)] }
        
        // MARK: - Error Handling
        // Whenever `ErrorTracker` emits an error, drive the navigator to show an error alert.
        errorTracker
            .asDriver()
            .drive(onNext: { [weak self] _ in
                self?.navigator.showError()
            })
            .disposed(by: disposeBag)
        
        // MARK: - Model Selection (Item Tapped)
        // Whenever `modelSelected` emits (user taps on a UserModel), navigate to the detail screen for that user.
        input.modelSelected
            .asDriverOnErrorJustComplete()
            .drive(onNext: { [weak self] model in
                guard let self = self else { return }
                self.navigator.showUserDetail(user: model)
            })
            .disposed(by: disposeBag)
        
        // Convert the `dataSection` observable to a `Driver` (UI-friendly) and return it in Output.
        return Output(userList: dataSection.asDriverOnErrorJustComplete())
    }
    
    /// Input struct contains all observables representing user events that this ViewModel listens to.
    public struct Input {
        /// Emits when the view first requests data (e.g., when viewDidLoad or viewWillAppear).
        let firstRequest: Observable<Void>
        /// Emits when the user triggers a refresh (e.g., pull-to-refresh).
        let refresh: Observable<Void>
        /// Emits when the user scrolls to the bottom to load more data.
        let loadMore: Observable<Void>
        /// Emits when the user taps on a user item to select it.
        let modelSelected: Observable<UserModel>
        
        /// Initializes Input with the specified observables.
        /// - Parameters:
        ///   - firstRequest: Observable<Void> for initial load.
        ///   - refresh: Observable<Void> for refresh events.
        ///   - loadMore: Observable<Void> for load-more events.
        ///   - modelSelected: Observable<UserModel> for item selection events.
        public init(
            firstRequest: Observable<Void>,
            refresh: Observable<Void>,
            loadMore: Observable<Void>,
            modelSelected: Observable<UserModel>
        ) {
            self.firstRequest = firstRequest
            self.refresh = refresh
            self.loadMore = loadMore
            self.modelSelected = modelSelected
        }
    }

    /// Output struct contains all data streams (Drivers) that this ViewModel exposes to the View.
    public struct Output {
        /// Driver emitting an array of `UserSection`, typically used to bind to a table or collection view.
        public let userList: Driver<[UserSection]>
    }
}
