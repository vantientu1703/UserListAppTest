//
//  UserViewModel.swift
//  UserListApp
//
//  Created by vantientu on 5/31/25.
//

import UIKit
import RxDataSources

extension UserModel: IdentifiableType {
    typealias Identity = String
    
    var identity: String {
        return "\(login ?? "")\(avatarURL ?? "")\(htmlURL ?? "")\(location ?? "")\(followers ?? 0)\(following ?? 0)"
    }
}

enum UserSection: AnimatableSectionModelType {
    
    case userList(items: [UserModel])
    
    var items: [UserModel] {
        switch self {
            
        case .userList(let items):
            return items
        }
    }
    
    init(original: UserSection, items: [UserModel]) {
        switch original {
        case .userList(let items):
            self = .userList(items: items)
        }
    }
    
    var identity: String {
        switch self {
        case .userList(let items): return items.map { $0.identity }.joined()
        }
    }
    
    typealias Item = UserModel
    
    typealias Identity = String
}

extension UserModel: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(login ?? "")
        hasher.combine(avatarURL ?? "")
        hasher.combine(htmlURL ?? "")
        hasher.combine(location ?? "")
        hasher.combine(followers ?? 0)
        hasher.combine(following ?? 0)
    }
}

extension Array where Element == UserModel {
    func uniqueIdentities() -> [UserModel] {
        return Array(Set(self))
    }
}
