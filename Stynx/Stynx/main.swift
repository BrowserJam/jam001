//
//  main.swift
//  Stynx
//
//  Created by Samuel Atkins on 14/09/2024.
//

import Foundation

do {
    let url = URL(string: "http://info.cern.ch/hypertext/WWW/TheProject.html")!
    let text = try await load_text(url: url)
    print(text)
    
    let document = parse_html(from: text)
    print(document.debug_string())
} catch {
    print("THING WENT WRONG:", error)
}
