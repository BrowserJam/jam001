//
//  Loader.swift
//  Stynx
//
//  Created by Samuel Atkins on 14/09/2024.
//

import Foundation

func load_url(_ url: URL) async throws -> (URLResponse, Data?) {
    let request = URLRequest(url: url)
    return try await withCheckedThrowingContinuation { continuation in
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                continuation.resume(throwing: error)
                return
            }
            continuation.resume(returning: (response!, data))
        }
        task.resume()
    }
}
