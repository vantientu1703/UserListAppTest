//
//  UserModel.swift
//  UserListApp
//
//  Created by vantientu on 5/29/25.

import RxDataSources
import Foundation

/// Model đại diện cho một người dùng (User)
struct UserModel: Codable {
    /// Tên đăng nhập (login username)
    let login: String?
    
    /// URL ảnh đại diện của người dùng
    let avatarURL: String?
    
    /// URL trang GitHub của người dùng
    let htmlURL: String?
    
    /// Thành phố/quốc gia nơi người dùng đang sinh sống
    let location: String?
    
    /// Số người đang theo dõi người dùng (followers)
    let followers: Int?
    
    /// Số người mà người dùng đang theo dõi (following)
    let following: Int?

    private enum CodingKeys: String, CodingKey {
        case login
        case avatarURL  = "avatar_url"
        case htmlURL    = "html_url"
        case location
        case followers
        case following
    }
}

extension UserModel: Equatable {
    static func ==(rhs: UserModel, lhs: UserModel) -> Bool {
        return rhs.login == lhs.login &&
        rhs.avatarURL == lhs.avatarURL &&
        rhs.htmlURL == lhs.htmlURL &&
        rhs.location == lhs.location &&
        rhs.followers == lhs.followers &&
        rhs.following == lhs.following
    }
}
