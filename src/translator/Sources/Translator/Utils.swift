//
//  File.swift
//  
//
//  Created by Oleg Koptev on 20.05.2023.
//

import Foundation

enum MyError: Error {
  case runtimeError(String)
}

extension Sequence {
  func asyncMap<T>(
    _ transform: (Element) async throws -> T
  ) async rethrows -> [T] {
    var values = [T]()
    
    for element in self {
      try await values.append(transform(element))
    }
    
    return values
  }
}

extension Sequence {
  func concurrentMap<T>(
    _ transform: @escaping (Element) async throws -> T
  ) async throws -> [T] {
    let tasks = map { element in
      Task {
        try await transform(element)
      }
    }
    
    return try await tasks.asyncMap { task in
      try await task.value
    }
  }
}

extension Array {
    func split() -> [[Element]] {
        let ct = self.count
        let half = ct / 2
        let leftSplit = self[0 ..< half]
        let rightSplit = self[half ..< ct]
        return [Array(leftSplit), Array(rightSplit)]
    }
}