import XCTest
import RxSwift
import RxCocoa
import RxTest
import RxBlocking
import UserListApp

// MARK: - Unit Tests

/// Test suite cho UserDetailViewModel
final class UserDetailViewModelTests: XCTestCase {
    
    var scheduler: TestScheduler!
    var disposeBag: DisposeBag!
    
    override func setUp() {
        super.setUp()
        // Khởi tạo TestScheduler để có thể điều khiển thời gian nếu cần (chưa sử dụng sâu trong các test này)
        scheduler = TestScheduler(initialClock: 0)
        // Mỗi test sẽ sử dụng một DisposeBag mới để thu dọn subscription
        disposeBag = DisposeBag()
    }
    
    override func tearDown() {
        // Giải phóng các đối tượng sau khi test kết thúc
        scheduler = nil
        disposeBag = nil
        super.tearDown()
    }
    
    /// 1. Test khi backTriggerred được emit, navigator.pop() phải được gọi đúng 1 lần
    func test_BackTrigger_CallsNavigatorPop() {
        // Chuẩn bị dữ liệu dummy user
        let dummyUser = UserModel(login: "dummy")
        // MockUsecaseSuccess luôn trả về dummyUser, nhưng test này không quan tâm đến fetchUserDetail
        let useCase = MockUsecaseSuccess(returning: dummyUser)
        let navigator = MockNavigator()
        // Tạo ViewModel với dummyUser, useCase mock và navigator mock
        let viewModel = UserDetailViewModel(user: dummyUser, useCase: useCase, navigator: navigator)
        
        // Tạo một PublishSubject để mô phỏng backTriggerred
        let backSubject = PublishSubject<Void>()
        // Đóng gói PublishSubject làm Input cho ViewModel
        let input = UserDetailViewModel.Input(backTriggerred: backSubject.asObservable())
        
        // Gọi transform để bắt đầu lắng nghe backTriggerred
        _ = viewModel.transform(input)
        
        // Emit một giá trị bất kỳ để simulate user nhấn back
        backSubject.onNext(())
        
        // Kiểm tra navigator.pop() phải được gọi đúng 1 lần
        XCTAssertEqual(navigator.popCallCount, 1, "backTriggerred phải gọi pop() đúng 1 lần")
    }
    
    /// 2. Test khi fetchUserDetail trả về thành công, Output.userDetail phải emit đúng UserModel
    func test_FetchUserDetail_Success_EmitsUserDetail() throws {
        // Chuẩn bị UserModel mong đợi
        let expectedUser = UserModel(login: "johndoe")
        // MockUsecaseSuccess trả về expectedUser khi gọi fetchUserDetail
        let useCase = MockUsecaseSuccess(returning: expectedUser)
        let navigator = MockNavigator()
        let viewModel = UserDetailViewModel(user: expectedUser, useCase: useCase, navigator: navigator)
        
        // Tạo Input với backTriggerred = never (không quan tâm back ở test này)
        let input = UserDetailViewModel.Input(backTriggerred: Observable.never())
        // Gọi transform để lấy Output
        let output = viewModel.transform(input)
        
        // Đổi Driver<UserModel> thành Observable<UserModel> và block đến khi có giá trị emit
        let emitted = try output.userDetail
            .asObservable()
            .toBlocking(timeout: 1)
            .first()
        
        // So sánh giá trị emit với expectedUser
        XCTAssertEqual(emitted, expectedUser, "Output.userDetail phải emit đúng UserModel trả về từ useCase")
        
        // Vì useCase không trả lỗi, navigator.showError() không được gọi
        XCTAssertEqual(navigator.showErrorCallCount, 0, "Không có lỗi => showError() không được gọi")
    }
    
    /// 3. Test khi fetchUserDetail trả về error, navigator.showError() phải được gọi ít nhất 1 lần
    func test_FetchUserDetail_Error_CallsNavigatorShowError() {
        // 1. Chuẩn bị dữ liệu dummy user
        let dummyUser = UserModel(login: "errorUser")
        // Tạo một NSError để mock useCase trả về lỗi
        let testError = NSError(domain: "Test", code: -1, userInfo: nil)
        // MockUsecaseError sẽ đưa về Observable.error(testError)
        let useCase = MockUsecaseError(error: testError)
        let navigator = MockNavigator()
        // Tạo ViewModel với dummyUser, useCase error, navigator mock
        let viewModel = UserDetailViewModel(user: dummyUser, useCase: useCase, navigator: navigator)
        
        // Input chỉ có backTriggerred = never (không quan tâm back ở test này)
        let input = UserDetailViewModel.Input(backTriggerred: Observable.never())
        let output = viewModel.transform(input)
        
        // Tạo expectation để đợi navigator.showError() được gọi
        let expectation = self.expectation(description: "Expect showError called")
        
        // Subscribe vào output.userDetail driver để trigger pipeline (mặc dù không emit giá trị nào do error)
        output.userDetail
            .drive()
            .disposed(by: disposeBag)
        
        // Đợi một khoảng thời gian nhỏ để ErrorTracker catch error và gọi navigator.showError()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Nếu showErrorCallCount > 0 => test pass
            if navigator.showErrorCallCount > 0 {
                expectation.fulfill()
            }
        }
        
        // Timeout là 1 giây, nếu sau 1 giây chưa fulfill => test thất bại
        waitForExpectations(timeout: 1.0, handler: nil)
        
        // Sau khi fulfill, kiểm tra showErrorCallCount phải bằng 1
        XCTAssertEqual(navigator.showErrorCallCount, 1, "fetchUserDetail error => phải gọi navigator.showError() đúng 1 lần")
    }
}


// MARK: - Mock Classes

/// Mock UseCase khi fetchUserDetail thành công (trả về một UserModel)
private final class MockUsecaseSuccess: UserDetailUsecase {
    let userToReturn: UserModel
    
    init(returning user: UserModel) {
        self.userToReturn = user
    }
    
    func fetchUserDetail(login: String, cachable: Bool) -> Observable<UserModel> {
        // Trả về ngay lập tức một giá trị UserModel
        return Observable.just(userToReturn)
    }
}

/// Mock UseCase khi fetchUserDetail trả về lỗi
private final class MockUsecaseError: UserDetailUsecase {
    let errorToReturn: Error
    
    init(error: Error) {
        self.errorToReturn = error
    }
    
    func fetchUserDetail(login: String, cachable: Bool) -> Observable<UserModel> {
        // Trả về ngay lập tức một lỗi
        return Observable.error(errorToReturn)
    }
}

/// Mock Navigator để đếm số lần pop() và showError()
private final class MockNavigator: UserDetailNavigator {
    private(set) var popCallCount = 0
    private(set) var showErrorCallCount = 0
    
    func pop() {
        popCallCount += 1
    }
    
    func showError() {
        showErrorCallCount += 1
    }
}
