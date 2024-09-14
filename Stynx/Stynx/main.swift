//
//  main.swift
//  Stynx
//
//  Created by Samuel Atkins on 14/09/2024.
//

import Foundation

print("Hello, World!")

do {
    let (response, data) = try await load_url(URL(string: "http://info.cern.ch/hypertext/WWW/TheProject.html")!)
    print("Got a response!")
    print("Metadata:", response)
    print("Contents:\n", data ?? "*empty*")
} catch {
    print("THING WENT WRONG:", error)
}
