//
//  HTMLParser.swift
//  Stynx
//
//  Created by Samuel Atkins on 14/09/2024.
//

import Foundation


let INDENT = "  "

enum DOMNode {
    case Document(children: [DOMNode])
    case Tag(name: String, attributes: [String:String?], children: [DOMNode])
    case Text(contents: String)
    
    func debugString(indent: Int = 0) -> String {
        let indentString = String(repeating: INDENT, count: indent)
        switch self {
        case .Document(let children):
            var description = "\(indentString)Document\n"
            for child in children {
                description.append(child.debugString(indent: indent + 1))
            }
            return description;
            
        case .Tag(let name, let attributes, let children):
            var description = "\(indentString)Tag (\(name)) attributes: (\(attributes))\n"
            for child in children {
                description.append(child.debugString(indent: indent + 1))
            }
            return description
            
        case .Text(let contents):
            return "\(indentString)Text (\(contents))\n"
        }
    }
}


func parse_html(from text: String) -> DOMNode {
    let children: [DOMNode] = []
    
    var stream = CharStream(of: text)
    
    enum State {
        case Text
        case InStartTag
        case InEndTag
        case InComment
    }
    
    while !stream.isDone {
        // I don't know what I'm doing
    }
    
    return DOMNode.Document(children: children)
}
