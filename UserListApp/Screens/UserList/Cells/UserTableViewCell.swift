//
//  UserTableViewCell.swift
//  UserListApp
//
//  Created by vantientu on 5/31/25.
//

import UIKit
import Kingfisher
import RxSwift

class UserTableViewCell: UITableViewCell {
    
    @IBOutlet weak var containerView: UIView!
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var avatarImageView: UIImageView!
    @IBOutlet weak var linkButton: UIButton!
    
    var disposeBag: DisposeBag = DisposeBag()
    
    override func prepareForReuse() {
        super.prepareForReuse()
        disposeBag = DisposeBag()
        self.containerView.removeRoundCornerWithShadow()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        avatarImageView.backgroundColor = .purple.withAlphaComponent(0.2)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.containerView.roundCornerWithShadow(cornerRadius: 8,
                                                 shadowRadius: 4,
                                                 offsetX: 0,
                                                 offsetY: 3,
                                                 color: .black.withAlphaComponent(0.2),
                                                 opacity: 1)
    }
    
    func config(user: UserModel) {
        if let url = URL(string: user.avatarURL ?? "") {
            avatarImageView.kf.setImage(with: url, placeholder: UIImage(), options: [.cacheOriginalImage]) { result in }
        }
        self.nameLabel.text = user.login
        
        let attributteString = NSAttributedString(string: user.htmlURL ?? "",
                                                  attributes: [.foregroundColor : UIColor.systemBlue,
                                                               .underlineStyle: NSUnderlineStyle.single.rawValue,
                                                               .underlineColor: UIColor.systemBlue])
        self.linkButton.setAttributedTitle(attributteString, for: .normal)
        
        linkButton.rx.tap
            .do (onNext: { _ in
                if let url = URL(string: user.htmlURL ?? "") {
                    UIApplication.shared.open(url)
                }
            })
            .subscribe()
            .disposed(by: disposeBag)
    }
}
