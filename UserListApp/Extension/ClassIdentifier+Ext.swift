//
//  ClassIdentifier+Ext.swift
//  UserListApp
//
//  Created by vantientu on 5/31/25.
//

import UIKit

protocol ClassIdentifiable {
    static var classIdentifierString: String { get }
}

extension ClassIdentifiable where Self: UIViewController {
    static var classIdentifierString: String { String(describing: Self.self) }
}

extension ClassIdentifiable where Self: UITableViewCell {
    static var classIdentifierString: String { String(describing: Self.self) }
}

extension UIViewController: ClassIdentifiable { }

extension UITableViewCell: ClassIdentifiable {}
