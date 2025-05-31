//
//  UserListClient.swift
//  UserListApp
//
//  Created by vantientu on 5/31/25.
//

import RxSwift
import Foundation

protocol UserClientProtocol {
    func fetchUserList(perPage: Int, since: Int) -> Observable<[UserModel]>
    func fetchUserDetail(loginUserName: String) -> Observable<UserModel>
}

class UserClient: TBaseClient, UserClientProtocol {
    
    let dataCache = UserListCacheManager()
    
    func fetchUserDetail(loginUserName: String) -> RxSwift.Observable<UserModel> {
        return Observable<UserModel>.create { [weak self] observer  in
            guard let self else {
                return Disposables.create()
            }
            let parameters: [String: String]? = nil
            let request = constructRequest(with: "/users/\(loginUserName)", method: .GET, parameters: parameters)
            
            objectResponse(from: request) { (result: Swift.Result<UserModel, Error>) in
                switch result {
                case .success(let data):
                    observer.onNext(data)
                    observer.onCompleted()
                case .failure(let error):
                    observer.onError(error)
                }
            }
            return Disposables.create()
        }
    }
    
    
    func fetchUserList(perPage: Int, since: Int) -> Observable<[UserModel]> {
        return Observable<[UserModel]>.create { [weak self] observer  in
            guard let self else {
                return Disposables.create()
            }
            let paramters = ["per_page": "\(perPage)",
                             "since": "\(since)"]
            let request = constructRequest(with: "/users", method: .GET, parameters: paramters)
            
            let key = request?.url?.absoluteString ?? ""
            let data = self.dataCache.getUserList(forKey: key)
            
            if !data.isEmpty {
                observer.onNext(data)
                observer.onCompleted()
                return Disposables.create()
            }
            
            objectResponse(from: request) { [weak self] (result: Swift.Result<[UserModel], Error>) in
                guard let self else { return }
                switch result {
                case .success(let data):
                    observer.onNext(data)
                    observer.onCompleted()
                    if !data.isEmpty {
                        self.dataCache.setUserList(data, forKey: key)
                    }
                case .failure(let error):
                    observer.onError(error)
                }
            }
            return Disposables.create()
        }
    }
}
