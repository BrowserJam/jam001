//
//  Loader.swift
//  Stynx
//
//  Created by Samuel Atkins on 14/09/2024.
//

import Foundation

extension URLResponse {
    func textEncoding() -> String.Encoding? {
        guard let textEncodingName else {
            return nil
        }
        let cfe = CFStringConvertIANACharSetNameToEncoding(textEncodingName as CFString)
        guard cfe != kCFStringEncodingInvalidId else {
            return nil
        }
        
        return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfe))
    }
}

func load_url(_ url: URL) async throws -> (HTTPURLResponse, Data?) {
    let request = URLRequest(url: url)
    return try await withCheckedThrowingContinuation { continuation in
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                continuation.resume(throwing: error)
                return
            }
            guard response is HTTPURLResponse else {
                continuation.resume(throwing: LoadError.NonHTTPResponse)
                return
            }
            continuation.resume(returning: (response as! HTTPURLResponse, data))
        }
        task.resume()
    }
}

enum LoadError : Error {
    case EmptyResponse
    case NonHTTPResponse
    case UnableToDecode(encoding: String?)
}

func load_text(url: URL) async throws -> String {
    let (response, data) = try await load_url(url)
    guard let data else {
        throw LoadError.EmptyResponse
    }
    
    let encoding = response.textEncoding() ?? String.Encoding.utf8
    let text = String(data: data, encoding: encoding)
    guard let text else {
        throw LoadError.UnableToDecode(encoding: response.textEncodingName)
    }
    return text
}
