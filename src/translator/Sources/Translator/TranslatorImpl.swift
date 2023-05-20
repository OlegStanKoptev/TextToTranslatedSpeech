//
//  File.swift
//  
//
//  Created by Oleg Koptev on 20.05.2023.
//

import Foundation

struct TranslateRequest: Codable {
  var folderId: String = "<folderId>"
  var texts: [String]
  var targetLanguageCode: String = "ru"
  var sourceLanguageCode: String = "en"
}

struct TranslateResponseTranslation: Codable {
  var text: String
}

struct TranslateResponse: Codable {
  var translations: [TranslateResponseTranslation]
}

struct TranslatorImpl {
  static func act(inputFile: String, outputFolder: String) async throws {
    let fileUrl = URL(filePath: inputFile)
    let targetFolderUrl = URL(filePath: outputFolder)
    try await parseTextFromFileAndTranslate(fileUrl: fileUrl, targetFolderUrl: targetFolderUrl)
  }
  
  static func createAudio(outputFolder: String) throws {
    let configPath = outputFolder + "/config"
    if (!FileManager.default.fileExists(atPath: configPath)) {
      FileManager.default.createFile(atPath: configPath, contents: nil)
    }
    let allFiles = try FileManager.default.contentsOfDirectory(atPath: outputFolder)
    let numberOfSamples = allFiles.filter { $0.hasSuffix(".txt") }.count / 2
    if let handle = try? FileHandle(forWritingTo: URL(filePath: configPath)) {
        handle.seekToEndOfFile()
        for i in 0..<numberOfSamples {
          let content = "file '\(i)_en.aiff'\nfile '\(i)_ru.aiff'\nfile '\(i)_en.aiff'\n"
          handle.write(content.data(using: .utf8)!)
        }
        handle.closeFile()
    }
  }
  
  static func finish(outputFolder: String) throws {
    try FileManager.default.removeItem(atPath: outputFolder)
  }
  
  private static func separateIntoSentences(text: String) -> [String] {
    let tagger = NSLinguisticTagger(tagSchemes: [.tokenType], options: 0)
    tagger.string = text
    var sentences = [String]()
    let range = NSRange(location: 0, length: text.utf16.count)
    tagger.enumerateTags(in: range, unit: .sentence, scheme: .tokenType, options: [.omitPunctuation, .omitWhitespace]) { _, tokenRange, _ in
      let sentence = (text as NSString).substring(with: tokenRange).trimmingCharacters(in: .whitespacesAndNewlines)
      if !sentence.isEmpty {
        sentences.append(sentence)
      }
    }
    return sentences
  }
  
  private static func translate(sentences: [String], symbolsLimit: Int) async throws -> [String] {
    guard sentences.count == 1 || sentences.reduce(0, { $0 + $1.count }) < symbolsLimit else {
      let texts = sentences.split()
      let translatedTexts = try await texts.asyncMap { try await translate(sentences: $0, symbolsLimit: symbolsLimit) }
      return Array(translatedTexts.joined())
    }
    let translationAPIKey = "<translationKey>"
    let translateRequest = TranslateRequest(texts: sentences)
    let url = URL(string: "https://translate.api.cloud.yandex.net/translate/v2/translate")!
    var request = URLRequest(url: url)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(translationAPIKey)", forHTTPHeaderField: "Authorization")
    request.httpMethod = "POST"
    request.httpBody = try JSONEncoder().encode(translateRequest)
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else { throw MyError.runtimeError("") }
    guard (200...299).contains(httpResponse.statusCode) else {
      if let body = String(data: data, encoding: .utf8) {
        throw MyError.runtimeError(body)
      } else {
        throw MyError.runtimeError(String(describing: httpResponse))
      }
    }
    let content = try JSONDecoder().decode(TranslateResponse.self, from: data)
    return content.translations.map { $0.text }
  }
  
  private static func parseTextFromFileAndTranslate(fileUrl: URL, targetFolderUrl: URL) async throws {
    let filePath = fileUrl.path()
    let targetFolderPath = targetFolderUrl.path()
    guard FileManager.default.fileExists(atPath: filePath) else { throw MyError.runtimeError("input file doesn't exist") }
    var isDirectory: ObjCBool = true
    let targetDirectoryExists = FileManager.default.fileExists(atPath: targetFolderPath, isDirectory: &isDirectory) && isDirectory.boolValue
    if !targetDirectoryExists {
      try FileManager.default.createDirectory(at: targetFolderUrl, withIntermediateDirectories: false)
    }
    let contensOfDirectory = try FileManager.default.contentsOfDirectory(atPath: targetFolderPath)
    let targetDirectoryIsEmpty = contensOfDirectory.isEmpty || (contensOfDirectory.count == 1 && contensOfDirectory[0] == ".DS_Store")
    guard targetDirectoryIsEmpty else { throw MyError.runtimeError("output folder already exists or is not empty") }
    let originalText = try String(contentsOf: fileUrl)
    let originalSentences = separateIntoSentences(text: originalText).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    let translatedSentences = try await translate(sentences: originalSentences, symbolsLimit: 8000)
    let pairedSentences = zip(originalSentences, translatedSentences)
    for (index, (original, translation)) in pairedSentences.enumerated() {
      try original.write(to: targetFolderUrl.appending(path: "/\(index)_en.txt"), atomically: true, encoding: .utf8)
      try translation.write(to: targetFolderUrl.appending(path: "/\(index)_ru.txt"), atomically: true, encoding: .utf8)
    }
  }
}
