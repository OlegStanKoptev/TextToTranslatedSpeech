import Foundation
import ArgumentParser

@main
struct Translator: ParsableCommand {
  @Option var reader: String = "/Users/feldspar/Work/my_tools/translator/src/reader.scpt"
  @Option var input: String = "/Users/feldspar/Work/my_tools/translator/input.txt"
  @Option var output: String = "/Users/feldspar/Work/my_tools/translator/output"
  
  static func shell(_ command: String) -> String {
      let task = Process()
      let pipe = Pipe()
      
      task.standardOutput = pipe
      task.standardError = pipe
      task.arguments = ["-c", command]
      task.launchPath = "/bin/zsh"
      task.standardInput = nil
      task.launch()
      
      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      let output = String(data: data, encoding: .utf8)!
      
      return output
  }
  
  mutating func run() throws {
    let readerPath = reader
    let inputFilePath = input
    let outputFolderPath = output
    
    let semaphore = DispatchSemaphore(value: 0)
    Task {
      defer { semaphore.signal() }
      do {
        try await TranslatorImpl.act(inputFile: inputFilePath, outputFolder: outputFolderPath)
        _ = Translator.shell("osascript \(readerPath) \(outputFolderPath)")
        try TranslatorImpl.createAudio(outputFolder: outputFolderPath)
        _ = Translator.shell("/opt/homebrew/bin/ffmpeg -f concat -y -safe 0 -i \(outputFolderPath)/config -c copy \(outputFolderPath)/output.aiff")
        _ = Translator.shell("/opt/homebrew/bin/ffmpeg -i \(outputFolderPath)/output.aiff \(outputFolderPath)/../output.mp3")
        try TranslatorImpl.finish(outputFolder: outputFolderPath)
      } catch MyError.runtimeError(let message) {
        print(message)
      } catch {
        print(String(describing: error))
      }
    }
    semaphore.wait()
    
  }
}
