//
//  TBaseClient.swift
//  UserListApp
//
//  Created by vantientu on 5/29/25.
//

import UIKit

/// Enumeration defining possible server URIs (environments) the client might use.
/// Currently only `.common`, but can be extended to include staging/production or other hosts.
enum TServerURI {
    case common
}

/// Base client class responsible for constructing and executing HTTP requests.
/// Other API-specific client classes should inherit from this class.
/// Inherits from NSObject to support Objective-C runtime features if needed.
class TBaseClient: NSObject {
    
    /// Supported HTTP methods for RESTful requests.
    enum HTTPMethod: String, Codable {
        case GET
        case PUT
        case DELETE
        case PATCH
        case POST
        
        /// Returns the raw string value for the HTTP verb, used to set `URLRequest.httpMethod`.
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
    
    /// The data provider is responsible for executing network tasks (e.g., URLSession wrapper).
    let dataProvider: TDataProvider
    
    /// Indicates which server URI (environment) this client targets. Currently unused beyond `.common`.
    let serverURI: TServerURI
    
    /// Initializes the base client with a data provider and a chosen server URI.
    /// - Parameters:
    ///   - dataProvider: An object responsible for performing HTTP tasks.
    ///   - serverURI: The server environment or base endpoint to use.
    init(dataProvider: TDataProvider, serverURI: TServerURI) {
        self.dataProvider = dataProvider
        self.serverURI = serverURI
    }
    
    /// Returns the base URL for all API requests. If the string literal is invalid, the app will crash.
    /// In production, you might want to handle this more gracefully or inject the base URL.
    /// - Returns: A valid URL pointing to the API host (e.g., https://api.github.com).
    func getBaseURL() -> URL {
        guard let url = URL(string: "https://api.github.com") else {
            fatalError("Invalid base URL string")
        }
        return url
    }
    
    /// Constructs a URLRequest for a given endpoint, HTTP method, parameters, headers, and optional query parameters.
    ///
    /// - Parameters:
    ///   - path: The URL path relative to the base URL (e.g., "/users" or "/users/{username}").
    ///   - method: The HTTP method to use (GET, POST, etc.). Default is GET.
    ///   - parameters: An optional `Codable` object. If provided:
    ///       • For GET/DELETE methods, its JSON-encoded keys/values become query items.
    ///       • For PUT/POST/PATCH methods, its JSON-encoded data becomes the HTTP body.
    ///   - headers: A dictionary of HTTP headers to set on the request. Defaults to JSON accept/content-type.
    ///   - queryParam: An optional dictionary of string key/value pairs to explicitly add as query parameters.
    ///
    /// - Returns: A configured `URLRequest` if URL construction succeeds, or `nil` if URLComponents fails.
    func constructRequest<Parameters: Codable>(
        with path: String,
        method: HTTPMethod = .GET,
        parameters: Parameters? = nil,
        headers: [String: String] = [
            "Accept": "application/json",
            "Content-Type": "application/json"
        ],
        queryParam: [String: String]? = nil
    ) -> URLRequest? {
        // Build the base URL + path. If path is empty, use base URL directly.
        let baseUrl = getBaseURL()
        var url: URL {
            if path.isEmpty {
                return baseUrl
            }
            return baseUrl.appendingPathComponent(path)
        }
        
        // Use URLComponents to append query items
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        
        // If explicit query parameters are provided, convert them to URLQueryItems
        if let queryParameters = queryParam {
            var queryItems: [URLQueryItem] = []
            for (key, value) in queryParameters {
                queryItems.append(URLQueryItem(name: key, value: value))
            }
            components.queryItems = queryItems
        }
        
        // If a Codable `parameters` object is provided, JSON-encode it
        var jsonData: Data?
        if let parameters {
            jsonData = try? JSONEncoder().encode(parameters)
            
            // If the method is GET or DELETE, convert the JSON data into query items
            if [.GET, .DELETE].contains(method), let data = jsonData {
                let params = (try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]) ?? [:]
                var queryItems: [URLQueryItem] = []
                for (key, value) in params {
                    queryItems.append(URLQueryItem(name: key, value: "\(value)"))
                }
                components.queryItems = queryItems
            }
        }
        
        // Build the final URL from URLComponents
        guard let componentUrl = components.url else {
            return nil
        }
        
        // Create the URLRequest and apply headers
        var httpsRequest = URLRequest(url: componentUrl)
        for (key, value) in headers {
            httpsRequest.addValue(value, forHTTPHeaderField: key)
        }
        // Set the HTTP method (e.g., "GET", "POST")
        httpsRequest.httpMethod = method.value
        
        // For methods that support a request body, attach the JSON-encoded data
        if let jsonData = jsonData, [.PUT, .POST, .PATCH].contains(method) {
            httpsRequest.httpBody = jsonData
        }
        
        return httpsRequest
    }
    
    /// Performs a network request using the dataProvider and attempts to decode the response JSON into a Codable model `T`.
    ///
    /// - Parameters:
    ///   - request: The `URLRequest` to execute. If `nil`, completion returns `.invalidURL` error.
    ///   - completion: A closure called with `Result<T, Error>` when the request finishes or fails.
    func objectResponse<T: Codable>(
        from request: URLRequest?,
        completion: @escaping (Swift.Result<T, Error>) -> Void
    ) {
        // If the request is nil, immediately return an invalidURL error
        guard let request else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        // Print the request URL for debugging purposes
        debugPrint("request: \(request.url?.absoluteString ?? "none")")
        
        // Execute the request via the dataProvider (e.g., URLSession)
        dataProvider.executeTask(request) { response, data, error in
            // If no response, return invalidData error
            guard let response else {
                completion(.failure(APIError.invalidData))
                return
            }
            
            // Check HTTP status code is in the 200-299 range
            let httpStatusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard 200..<300 ~= httpStatusCode else {
                completion(.failure(APIError.responseError))
                return
            }
            
            // If there's no data, return invalidData error
            guard let data else {
                completion(.failure(APIError.invalidData))
                return
            }
            
            do {
                // Attempt to decode the data into the expected model type `T`
                let item = try JSONDecoder().decode(T.self, from: data)
                
                // Print the pretty-printed JSON response for debugging
                debugPrint("Response:")
                debugPrint(data.prettyPrintedJSONString ?? "")
                
                // Return the successfully decoded model
                completion(.success(item))
            } catch {
                // If decoding fails, return a decodingFailed error
                completion(.failure(APIError.decodingFailed))
            }
        }
    }
}

/// Extension on Data to provide a “pretty printed” JSON string, useful for debug logging.
/// Converts raw Data into an object, then re-serializes it with the `.prettyPrinted` option.
extension Data {
    var prettyPrintedJSONString: NSString? {
        guard let object = try? JSONSerialization.jsonObject(with: self, options: []),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
              let prettyPrintedString = NSString(
                  data: data,
                  encoding: String.Encoding.utf8.rawValue
              ) else {
            return nil
        }
        return prettyPrintedString
    }
}
