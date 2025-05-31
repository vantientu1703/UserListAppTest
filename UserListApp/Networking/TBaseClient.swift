//
//  TBaseClient.swift
//  UserListApp
//
//  Created by vantientu on 5/29/25.
//

import UIKit

enum TServerURI {
    case common
}

class TBaseClient: NSObject {
    
    enum HTTPMethod: String, Codable {
        case GET
        case PUT
        case DELETE
        case PATCH
        case POST
        
        var value: String {
            switch self {
            case .GET: return "GET"
            case .PUT: return "PUT"
            case .DELETE: return "DELETE"
            case .PATCH: return "PATCH"
            case .POST: return "POST"
            }
        }
    }
    
    let dataProvider: TDataProvider
    let serverURI: TServerURI
    
    init(dataProvider: TDataProvider, serverURI: TServerURI) {
        self.dataProvider = dataProvider
        self.serverURI = serverURI
    }
    
    func getBaseURL() -> URL {
        guard let url = URL(string: "https://api.github.com") else {
            fatalError()
        }
        return url
    }
    
    func constructRequest<Parameters: Codable>(with path: String,
                                               method: HTTPMethod = .GET,
                                               parameters: Parameters? = nil,
                                               headers: [String: String] = [
                                                "Accept": "application/json",
                                                "Content-Type": "application/json"],
                                               queryParam: [String: String]? = nil) -> URLRequest? {
        let baseUrl = getBaseURL()
        var url: URL {
            if path.isEmpty {
                return baseUrl
            }
            return baseUrl.appendingPathComponent(path)
        }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        
        if let queryParameters = queryParam {
            var queryItems: [URLQueryItem] = []
            for (key, value) in queryParameters {
                let item = URLQueryItem(name: key, value: value)
                queryItems.append(item)
            }
            components.queryItems = queryItems
        }
        
        var jsonData: Data?
        if let parameters {
            jsonData = try? JSONEncoder().encode(parameters)
            if [.GET, .DELETE].contains(method), let data = jsonData {
                let params = (try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]) ?? [:]
                var queryItems: [URLQueryItem] = []
                for (key, value) in params {
                    let item = URLQueryItem(name: key, value: "\(value)")
                    queryItems.append(item)
                }
                components.queryItems = queryItems
            }
        }
        
        guard let componetUrl = components.url else {
            return nil
        }
        
        var httpsRequest = URLRequest(url: componetUrl)
        for (key, value) in headers {
            httpsRequest.addValue(value, forHTTPHeaderField: key)
        }
        httpsRequest.httpMethod = method.value
        
        if let jsonData = jsonData, [.PUT, .POST, .PATCH].contains(method) {
            httpsRequest.httpBody = jsonData
        }
        return httpsRequest
    }
    
    func objectResponse<T: Codable>(from request: URLRequest?, completion: @escaping (Swift.Result<T, Error>) -> Void) {
        guard let request else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        debugPrint("request: \(request.url?.absoluteString ?? "none")")
        
        dataProvider.executeTask(request) { response, data, error in
            guard let response else {
                completion(.failure(APIError.invalidData))
                return
            }
            
            let httpUrlResponseCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard 200..<300 ~= httpUrlResponseCode else {
                completion(.failure(APIError.responseError))
                return
            }
            
            guard let data else {
                completion(.failure(APIError.invalidData))
                return
            }
            do {
                let item = try JSONDecoder().decode(T.self, from: data)
                
                debugPrint("Response: ")
                debugPrint(data.prettyPrintedJSONString ?? "")
                
                completion(.success(item))
            } catch {
                completion(.failure(APIError.decodingFailed))
            }
        }
    }
}

extension Data {
    var prettyPrintedJSONString: NSString? { /// NSString gives us a nice sanitized debugDescription
        guard let object = try? JSONSerialization.jsonObject(with: self, options: []),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
              let prettyPrintedString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) else { return nil }
        
        return prettyPrintedString
    }
}
