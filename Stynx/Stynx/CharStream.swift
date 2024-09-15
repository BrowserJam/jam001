//
//  CharStream.swift
//  Stynx
//
//  Created by Samuel Atkins on 14/09/2024.
//

import Foundation

class CharStream {
    let input: String.UnicodeScalarView
    
    var index: String.UnicodeScalarView.Index
    var position: Int = 0
    
    init (of input: String) {
        self.input = input.unicodeScalars
        self.index = self.input.startIndex
    }
    
    func peek(_ offset: Int = 0) -> Character? {
        guard position + offset < input.count else {
            return nil
        }
        return Character(input[input.index(index, offsetBy: offset)])
    }
    
    func next() -> Character? {
        guard position < input.count else {
            return nil
        }
        
        let result = Character(input[index])
        
        position += 1
        index = input.index(after: index)
        return result
    }
    
    var isDone: Bool {
        get { return peek() == nil }
    }
    
    // Run the block of code in a transaction.
    // If it returns nil, the stream is reset to its previous state.
    func transaction<Result>(_ closure: () -> Result?) -> Result? {
        let initialIndex = self.index
        let initialPosition = self.position
        
        guard let result = closure() else {
            self.index = initialIndex
            self.position = initialPosition
            return nil
        }
        
        return result
    }
}
