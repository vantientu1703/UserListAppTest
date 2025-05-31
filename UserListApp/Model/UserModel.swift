//
//  UserModel.swift
//  UserListApp
//
//  Created by vantientu on 5/29/25.

import RxDataSources
import Foundation

/// Model đại diện cho một người dùng (User)
public struct UserModel: Codable {
    /// Tên đăng nhập (login username)
    public let login: String?
    
    /// URL ảnh đại diện của người dùng
    var avatarURL: String?
    
    /// URL trang GitHub của người dùng
    var htmlURL: String?
    
    /// Thành phố/quốc gia nơi người dùng đang sinh sống
    var location: String?
    
    /// Số người đang theo dõi người dùng (followers)
    var followers: Int?
    
    /// Số người mà người dùng đang theo dõi (following)
    var following: Int?

    private enum CodingKeys: String, CodingKey {
        case login
        case avatarURL  = "avatar_url"
        case htmlURL    = "html_url"
        case location
        case followers
        case following
    }
    
    public init(login: String) {
        self.login = login
    }
}

extension UserModel: Equatable {
    static public func ==(rhs: UserModel, lhs: UserModel) -> Bool {
        return rhs.login == lhs.login &&
        rhs.avatarURL == lhs.avatarURL &&
        rhs.htmlURL == lhs.htmlURL &&
        rhs.location == lhs.location &&
        rhs.followers == lhs.followers &&
        rhs.following == lhs.following
    }
}
