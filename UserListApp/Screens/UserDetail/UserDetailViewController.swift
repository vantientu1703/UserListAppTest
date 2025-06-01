
import UIKit
import RxSwift
import RxCocoa
import Kingfisher

class UserDetailViewController: UIViewController {
    
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var loactionLabel: UILabel!
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var avatarImageView: UIImageView!
    @IBOutlet weak var numberOfFollowersLabel: UILabel!
    @IBOutlet weak var numberOfFollowingLabel: UILabel!
    
    private let disposeBag = DisposeBag()
    
    let viewModel: UserDetailViewModel
    
    init(viewModel: UserDetailViewModel) {
        self.viewModel = viewModel
        super.init(nibName: UserDetailViewController.classIdentifierString, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        bindViewModel()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.containerView.roundCornerWithShadow(cornerRadius: 8,
                                                 shadowRadius: 3,
                                                 offsetX: 0,
                                                 offsetY: 3,
                                                 color: .black.withAlphaComponent(0.2),
                                                 opacity: 1)
    }
    
    func setupUser(_ user: UserModel) {
        userNameLabel.text = user.login
        if let location = user.location {
            loactionLabel.text = location
        } else {
            loactionLabel.text = "--"
        }
        
        if let followers = user.followers {
            numberOfFollowersLabel.text = "\(followers)"
        } else {
            numberOfFollowersLabel.text = "--"
        }
        if let following = user.following {
            numberOfFollowingLabel.text = "\(following)"
        } else {
            numberOfFollowingLabel.text = "--"
        }
        if let url = URL(string: user.avatarURL ?? "") {
            avatarImageView.kf.setImage(with: url, placeholder: UIImage(), options: [.cacheOriginalImage]) { result in }
        }
    }
}

extension UserDetailViewController {
    func bindViewModel() {
        let input = UserDetailViewModel.Input(backTriggerred: backButton.rx.tap.mapToVoid())
        let output = viewModel.transform(input)
        output.userDetail
            .drive(onNext: { [weak self] user in
                if let self = self {
                    self.setupUser(user)
                }
            })
            .disposed(by: disposeBag)
    }
}
