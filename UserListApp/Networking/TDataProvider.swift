//
//  TDataProvider.swift
//  UserListApp
//
//  Created by vantientu on 5/29/25.
//

import UIKit

/// Common API error cases that can occur during networking operations.
enum APIError: Error {
    /// No network connection available.
    case noInternet
    /// The URL string was invalid or could not be formed into a URL.
    case invalidURL
    /// JSON decoding of the response data failed.
    case decodingFailed
    /// The response data was missing or corrupted.
    case invalidData
    /// The HTTP response code was not in the 200–299 success range.
    case responseError
}

/// Represents an error response from the server, if the server sends back JSON containing an error message.
/// - `code`: A machine-readable error code (optional).
/// - `messsage`: A human-readable error message (optional).
struct APIErrorResponse: Codable {
    let code: String?
    let messsage: String?
}

/// Protocol to represent a cancelable networking task.
/// Classes or structs conforming to this protocol must implement `cancel()` and report whether they can still be canceled.
@objc public protocol NetworkingCancelable {
    /// Cancels the in-progress network request.
    func cancel()
    /// Returns true if the request is currently running and can be canceled.
    var isCancelable: Bool { get }
}

/// Extend URLSessionTask to conform to NetworkingCancelable, so any data task can be canceled.
extension URLSessionTask: NetworkingCancelable {
    /// Returns true if the task is currently in the running state.
    public var isCancelable: Bool {
        return state == .running
    }
}

/// A simple data provider that wraps URLSession for performing HTTP requests.
class TDataProvider: NSObject {
    /// The shared URLSession used for all network tasks.
    /// Configuration is default; can be customized if needed (e.g., timeout, caching).
    let session: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config)
    }()
    
    /// Executes a data task with the given URLRequest and calls the completion closure upon completion.
    ///
    /// - Parameters:
    ///   - request: The URLRequest to perform.
    ///   - completion: An optional closure that is invoked when the request completes, receiving:
    ///       • URLResponse? - the URL response if any
    ///       • Data? - the raw data returned by the server
    ///       • Error? - any networking or decoding error that occurred
    ///
    /// - Returns: An object conforming to `NetworkingCancelable` (specifically the `URLSessionDataTask`),
    ///   which can be used to cancel the request if it is still running.
    @discardableResult
    func executeTask(
        _ request: URLRequest,
        completion: ((URLResponse?, Data?, Error?) -> Void)? = nil
    ) -> NetworkingCancelable? {
        // Create a data task with the request and completion handler
        let task = session.dataTask(with: request) { data, response, error in
            // Invoke the completion closure, passing response, data, and error
            completion?(response, data, error)
        }
        // Start the network request immediately
        task.resume()
        // Return the task so it can be canceled if needed
        return task
    }
}
