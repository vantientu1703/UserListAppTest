//
//  UserViewModel.swift
//  UserListApp
//
//  Created by vantientu on 5/31/25.
//

import UIKit
import RxDataSources

extension UserModel: IdentifiableType {
    public typealias Identity = String
    
    var value: String {
        return "\(login ?? "")\(avatarURL ?? "")\(htmlURL ?? "")\(location ?? "")\(followers ?? 0)\(following ?? 0)"
    }
    
    public var identity: String {
        return login ?? ""
    }
}

public enum UserSection: AnimatableSectionModelType {
    
    case userList(items: [UserModel])
    
    public var items: [UserModel] {
        switch self {
        case .userList(let items):
            return items
        }
    }
    
    public init(original: UserSection, items: [UserModel]) {
        switch original {
        case .userList:
            self = .userList(items: items)
        }
    }
    
    public var identity: String {
        switch self {
        case .userList: return "user_list"
        }
    }
    
    public typealias Item = UserModel
    
    public typealias Identity = String
}

extension UserSection: Equatable {
    public static func ==(rhs: UserSection, lhs: UserSection) -> Bool {
        return rhs.identity == lhs.identity
    }
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
    public func uniqueIdentities() -> [UserModel] {
        var uniques: [UserModel] = []
        forEach { u in
            if !uniques.contains(u) {
                uniques.append(u)
            }
        }
        return uniques
    }
}
