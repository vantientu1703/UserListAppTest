
import UIKit
import RxSwift
import RxCocoa
import RxDataSources


class UserListViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    private let disposeBag = DisposeBag()
    
    let refreshControl = UIRefreshControl()
    
    // Khai báo DataSource
    let dataSource: RxTableViewSectionedAnimatedDataSource<UserSection> = {
        let ds = RxTableViewSectionedAnimatedDataSource<UserSection>(
            configureCell: { dataSource, tableView, indexPath, user in
                let cell = tableView.dequeueCell(UserTableViewCell.self, forIndexPath: indexPath)
                cell.config(user: user)
                return cell
            }
        )
        // Tùy chỉnh animation (tuỳ chọn)
        ds.animationConfiguration = AnimationConfiguration(
            insertAnimation: .fade,
            reloadAnimation: .fade,
            deleteAnimation: .fade
        )
        return ds
    }()
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    let viewModel: UserListViewModel
    
    init(viewModel: UserListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: UserListViewController.classIdentifierString, bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        bindViewModel()
    }
    
    func setupViews() {
        tableView.refreshControl = refreshControl
        tableView.registerCellByNib(UserTableViewCell.self)
    }
}

extension UserListViewController {
    func bindViewModel() {
        let refreshTriggered = refreshControl.rx.controlEvent(.valueChanged).mapToVoid()
            .do(onNext: { [weak self] _ in
                self?.refreshControl.endRefreshing()
            })
        let loadMoreTriggered = tableView.rx.reachedBottom
            .debounce(.milliseconds(100), scheduler: ConcurrentDispatchQueueScheduler(queue: .global()))
        let modelSelected = tableView.rx.modelSelected(UserModel.self).asObservable()
        
        let input = UserListViewModel.Input(firstRequest: .just(()),
                                            refresh: refreshTriggered,
                                            loadMore: loadMoreTriggered,
                                            modelSelected: modelSelected)
        
        let output = viewModel.transform(input)
        
        output.userList
            .drive(tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)
    }
}
