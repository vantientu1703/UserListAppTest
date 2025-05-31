import XCTest
import RxSwift
import RxCocoa
import RxTest
import RxBlocking
import UserListApp

// MARK: - Mock Classes

/// Mock cho UserListUsecase, trả về dữ liệu tùy vào tham số `since`
private final class MockUsecase: UserListUsecase {
    /// Không dùng trong test này, chỉ để tránh compiler lỗi
    func fetchUserDetail(loginUserName: String) -> RxSwift.Observable<UserListApp.UserModel> {
        return .empty()
    }
    
    /// Trang đầu (since = 0)
    private let firstPage: [UserModel]
    /// Trang thứ hai (since = size)
    private let secondPage: [UserModel]
    /// Nếu `since` nằm trong tập này => trả về lỗi
    private let errorOn: Set<Int>
    
    init(firstPage: [UserModel], secondPage: [UserModel], errorOn: Set<Int> = []) {
        self.firstPage = firstPage
        self.secondPage = secondPage
        self.errorOn = errorOn
    }
    
    func fetchUserList(size: Int, since: Int, cachable: Bool) -> Observable<[UserModel]> {
        // 1. Nếu since nằm trong errorOn, trả về Observable.error
        if errorOn.contains(since) {
            return Observable.error(NSError(domain: "TestError", code: -1, userInfo: nil))
        }
        // 2. Nếu since == 0, trả về firstPage
        if since == 0 {
            return Observable.just(firstPage)
        }
        // 3. Nếu since == size (mặc định size = 20), trả về secondPage
        if since == size {
            return Observable.just(secondPage)
        }
        // 4. Nếu không thuộc trường hợp trên, giả lập trả về mảng rỗng
        return Observable.just([])
    }
}

/// Mock cho UserListNavigator, ghi nhận số lần gọi hàm và thông tin cuối cùng
private final class MockNavigator: UserListNavigator {
    private(set) var showErrorCallCount = 0
    private(set) var showUserDetailCallCount = 0
    private(set) var lastUserDetail: UserModel?
    
    func showError() {
        showErrorCallCount += 1
    }
    
    func showUserDetail(user: UserModel) {
        showUserDetailCallCount += 1
        lastUserDetail = user
    }
}

// MARK: - Các Extension hỗ trợ Testing

fileprivate extension Array where Element == UserModel {
    /// Giả sử `uniqueIdentities()` loại bỏ trùng lặp theo `login`
    func uniqueIdentities() -> [UserModel] {
        return Array(Set(self))
    }
}

fileprivate extension ObservableType {
    /// Chuyển Observable sang Driver, bỏ qua mọi lỗi (just complete)
    func asDriverOnErrorJustComplete() -> Driver<Element> {
        return self.asObservable().asDriver { _ in
            return Driver.empty()
        }
    }
}

// MARK: - Unit Tests

final class UserListViewModelTests: XCTestCase {
    
    var disposeBag: DisposeBag!
    
    override func setUp() {
        super.setUp()
        // Khởi tạo disposeBag cho mỗi test
        disposeBag = DisposeBag()
    }
    
    override func tearDown() {
        // Giải phóng disposeBag sau mỗi test
        disposeBag = nil
        super.tearDown()
    }
    
    // 1. Test initial load: ngay sau khi transform(_:) được gọi và phát firstRequest,
    //    phải emit dữ liệu của firstPage
    func test_initialLoad_emitsFirstPageSection() throws {
        // 1. Chuẩn bị dữ liệu mẫu
        let userA = UserModel(login: "A")
        let userB = UserModel(login: "B")
        
        let firstPage = [userA, userB]
        // secondPage không sử dụng trong test này, có thể đặt rỗng
        let secondPage: [UserModel] = []
        
        // Tạo mock usecase trả về firstPage khi since = 0
        let useCase = MockUsecase(firstPage: firstPage, secondPage: secondPage)
        let navigator = MockNavigator()
        let viewModel = UserListViewModel(useCase: useCase, navigator: navigator)
        
        // 2. Tạo một PublishSubject để trigger firstRequest
        let firstRequest = PublishSubject<Void>()
        
        // 3. Tạo input với firstRequest bật/tắt, còn các stream khác là never()
        let input = UserListViewModel.Input(
            firstRequest: firstRequest,
            refresh: Observable.never(),
            loadMore: Observable.never(),
            modelSelected: Observable.never()
        )
        
        // 4. Gọi transform để lấy Output
        let output = viewModel.transform(input)
        
        // 5. Khi phát firstRequest, ViewModel sẽ thực hiện initial request
        firstRequest.onNext(())  // emit để bắt đầu fetchUserList(since: 0)
        
        // 6. Subscribe vào output.userList để kiểm tra kết quả
        output.userList
            .drive(onNext: { items in
                // 6a. Chắc chắn rằng phần tử trả về có đúng 2 user (A, B)
                XCTAssertEqual(items.count, 2)
                // 6b. Vì không có lỗi trong quá trình fetch => showError() không được gọi
                XCTAssertEqual(navigator.showErrorCallCount, 0)
            })
            .disposed(by: disposeBag)
    }
    
    // 2. Test loadMore: sau khi initial load, gọi loadMore => emit thêm phần kết hợp ([second] + [first])
    func test_loadMore_appendsSecondPageBelowFirst() throws {
        // 1. Chuẩn bị dữ liệu mẫu
        let userA = UserModel(login: "A")
        let userB = UserModel(login: "B")
        let userC = UserModel(login: "C")
        
        let firstPage = [userA, userB]
        let secondPage = [userC]  // Khi since = size, trả về mảng chứa userC
        
        // Tạo mock usecase trả về firstPage (since=0) và secondPage (since=20)
        let useCase = MockUsecase(firstPage: firstPage, secondPage: secondPage)
        let navigator = MockNavigator()
        let viewModel = UserListViewModel(useCase: useCase, navigator: navigator)
        
        // 2. Tạo các PublishSubject để trigger firstRequest và loadMore
        let firstRequest = PublishSubject<Void>()
        let loadMoreSubject = PublishSubject<Void>()
        
        // 3. Tạo input: ban đầu firstRequest được kích hoạt, loadMore khi chúng ta gọi onNext()
        let input = UserListViewModel.Input(
            firstRequest: firstRequest,
            refresh: Observable.never(),
            loadMore: loadMoreSubject.asObservable(),
            modelSelected: Observable.never()
        )
        
        // 4. Lấy Output và subscribe để test
        let output = viewModel.transform(input)
        
        // 5. Phát initial request (since=0)
        firstRequest.onNext(())
        
        // Vì mock usecase trả về Observable.just(...), request thực thi đồng bộ.
        // Chúng ta sleep 1 giây để chắc chắn pipeline xử lý xong initial,
        // sau đó trigger loadMore để lấy trang kế tiếp.
        sleep(1)
        
        // 6. Phát loadMore => since tăng lên size (20), fetchUserList sẽ trả về secondPage
        loadMoreSubject.onNext(())
        
        // 7. Subscribe vào output.userList để kiểm tra kết quả sau loadMore
        output.userList
            .drive(onNext: { items in
                // 7a. Sau loadMore, tổng số phần tử phải là 3 ([C] + [A,B])
                XCTAssertEqual(items.count, 3)
                // 7b. Không có lỗi => navigator.showError() không được gọi
                XCTAssertEqual(navigator.showErrorCallCount, 0)
            })
            .disposed(by: disposeBag)
    }
    
    // 3. Test refresh: ban đầu load xong, khi trigger refresh sau >=0.1s, since phải reset = 0 và emit lại firstPage
    func test_refresh_resetsSinceAndEmitsFreshFirstPage() {
        // 1. Chuẩn bị dữ liệu mẫu: lần đầu trả [A,B], lần refresh trả [D]
        let userA = UserModel(login: "A")
        let userB = UserModel(login: "B")
        let userD = UserModel(login: "D")
        
        let initialFirstPage = [userA, userB]
        let freshFirstPage = [userD]
        
        // Custom Usecase: lần đầu gọi trả initialFirstPage, lần thứ hai (refresh) thì trả freshFirstPage
        class OverrideUsecase: UserListUsecase {
            func fetchUserDetail(loginUserName: String) -> RxSwift.Observable<UserListApp.UserModel> {
                .empty()
            }
            
            let firstPage: [UserModel]
            let refreshPage: [UserModel]
            var haveRefreshed = false
            
            init(firstPage: [UserModel], refreshPage: [UserModel]) {
                self.firstPage = firstPage
                self.refreshPage = refreshPage
            }
            
            func fetchUserList(size: Int, since: Int, cachable: Bool) -> Observable<[UserModel]> {
                if haveRefreshed {
                    // Nếu đã refresh => trả freshFirstPage
                    return Observable.just(refreshPage)
                } else {
                    // Lần đầu tiên => trả initialFirstPage
                    haveRefreshed = true
                    return Observable.just(firstPage)
                }
            }
        }
        
        let useCase = OverrideUsecase(firstPage: initialFirstPage, refreshPage: freshFirstPage)
        let navigator = MockNavigator()
        let viewModel = UserListViewModel(useCase: useCase, navigator: navigator)
        
        // 2. Tạo PublishSubject để trigger firstRequest và refresh
        let firstSubject = PublishSubject<Void>()
        let refreshSubject = PublishSubject<Void>()
        
        // 3. Tạo input: firstRequest để load lần đầu,
        //    refresh để load lại (sau khi đã debounce 0.1s)
        let input = UserListViewModel.Input(
            firstRequest: firstSubject,
            refresh: refreshSubject.asObservable(),
            loadMore: Observable.never(),
            modelSelected: Observable.never()
        )
        
        // 4. Lấy Output
        let output = viewModel.transform(input)
        
        // 5. Trigger initial load (since = 0)
        firstSubject.onNext(())
        // Sleep 1 giây để pipeline hoàn thành initial load (để distinctUntilChanged không chặn)
        sleep(1)
        // 6. Trigger refresh: do có debounce 0.1s, ta chờ >= 0.1 giây trước khi gọi onNext()
        refreshSubject.onNext(())
        
        // 7. Subscribe vào output.userList để kiểm tra emission sau refresh
        output.userList
            .drive(onNext: { items in
                // 7a. Sau khi refresh, since đã reset = 0, useCase trả freshFirstPage = [D]
                XCTAssertEqual(items.count, 1)
                // 7b. Không có lỗi => navigator.showError() không được gọi
                XCTAssertEqual(navigator.showErrorCallCount, 0)
            })
            .disposed(by: disposeBag)
    }
    
    // 4. Test modelSelected => navigator.showUserDetail(...) phải được gọi đúng 1 lần với user tương ứng
    func test_modelSelected_triggersNavigatorShowUserDetail() {
        // 1. Chuẩn bị dữ liệu mẫu
        let userA = UserModel(login: "A")
        let firstPage = [userA]
        
        // Tạo mock usecase trả về firstPage (nhưng trong test này không cần dùng đến response)
        let useCase = MockUsecase(firstPage: firstPage, secondPage: [])
        let navigator = MockNavigator()
        let viewModel = UserListViewModel(useCase: useCase, navigator: navigator)
        
        // 2. Tạo PublishSubject để trigger modelSelected, và firstRequest để khởi động pipeline
        let firstRequest = PublishSubject<Void>()
        let modelSelectSubject = PublishSubject<UserModel>()
        
        // 3. Tạo input: firstRequest để khởi tạo ban đầu, modelSelected để test navigator.showUserDetail
        let input = UserListViewModel.Input(
            firstRequest: firstRequest,
            refresh: Observable.never(),
            loadMore: Observable.never(),
            modelSelected: modelSelectSubject.asObservable()
        )
        
        // 4. Thực thi transform để bắt đầu lắng nghe modelSelected
        _ = viewModel.transform(input)
        
        // 5. Trigger initial load (để activate pipeline; dù không kiểm tra data ở test này)
        firstRequest.onNext(())
        
        // 6. Ban đầu, showUserDetailCallCount phải là 0
        XCTAssertEqual(navigator.showUserDetailCallCount, 0)
        
        // 7. Khi phát event modelSelected với userA
        modelSelectSubject.onNext(userA)
        
        // 8. Kết quả: navigator.showUserDetail phải được gọi 1 lần và lastUserDetail = userA
        XCTAssertEqual(navigator.showUserDetailCallCount, 1)
        XCTAssertEqual(navigator.lastUserDetail, userA)
    }
    
    // 5. Test khi fetchUserList trả về error => navigator.showError() phải được gọi ít nhất 1 lần
    func test_fetchUserList_error_triggersNavigatorShowError() {
        // 1. Chuẩn bị dữ liệu mẫu: firstPage chỉ để tránh compiler, nhưng thực tế since=0 => trả lỗi
        let userA = UserModel(login: "A")
        let firstPage = [userA]
        
        // Tạo mock Usecase: khi since = 0 => lỗi (errorOn = [0])
        let useCase = MockUsecase(firstPage: firstPage, secondPage: [], errorOn: [0])
        let navigator = MockNavigator()
        let viewModel = UserListViewModel(useCase: useCase, navigator: navigator)
        
        // 2. Tạo PublishSubject để trigger firstRequest
        let firstRequest = PublishSubject<Void>()
        
        // 3. Tạo input: firstRequest để khởi động fetchUserList, các stream khác là never()
        let input = UserListViewModel.Input(
            firstRequest: firstRequest,
            refresh: Observable.never(),
            loadMore: Observable.never(),
            modelSelected: Observable.never()
        )
        let output = viewModel.transform(input)
        
        // 4. Subscribe driver để “kéo” toàn bộ pipeline, bất kể kết quả emit ra
        output.userList
            .drive()
            .disposed(by: disposeBag)
        
        // 5. Trigger initial request (khi since = 0, useCase trả về error)
        firstRequest.onNext(())
        
        // 6. Chờ một khoảng rất ngắn để ErrorTracker catch error và gọi navigator.showError()
        let exp = expectation(description: "Wait for showError")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
        
        // 7. Kết quả: navigator.showErrorCallCount phải >= 1
        XCTAssertGreaterThanOrEqual(navigator.showErrorCallCount, 1)
    }
}
