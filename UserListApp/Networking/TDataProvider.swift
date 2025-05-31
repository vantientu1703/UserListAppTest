//
//  TDataProvider.swift
//  UserListApp
//
//  Created by vantientu on 5/29/25.
//

import UIKit

enum APIError: Error {
    case noInternet
    case invalidURL
    case decodingFailed
    case invalidData
    case responseError
}

struct APIErrorResponse: Codable {
    let code: String?
    let messsage: String?
}

@objc public protocol NetworkingCancelable {
    func cancel()
    var isCancelable: Bool { get }
}

extension URLSessionTask: NetworkingCancelable {
    public var isCancelable: Bool {
        return state == .running
    }
}

class TDataProvider: NSObject {
    let session: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config)
    }()
    
    @discardableResult
    func executeTask(_ request: URLRequest, completion: ((URLResponse?, Data?, Error?) -> Void)? = nil) -> NetworkingCancelable? {
        let task = session.dataTask(with: request) { data, response, error in
            completion?(response, data, error)
        }
        task.resume()
        return task
    }
}

