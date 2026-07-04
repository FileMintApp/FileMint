import FileMintCore
import Foundation

let arguments = CommandLine.arguments

guard arguments.count == 2 else {
    fputs("Usage: filemint-harness <cases.json>\n", stderr)
    exit(64)
}

let casesURL = URL(fileURLWithPath: arguments[1])
let data = try Data(contentsOf: casesURL)
let cases = try JSONDecoder().decode([FileCreationHarnessCase].self, from: data)
let workspace = FileManager.default.temporaryDirectory
    .appendingPathComponent("FileMintHarness", isDirectory: true)

try? FileManager.default.removeItem(at: workspace)
try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: workspace) }

let results = try HarnessRunner.run(cases: cases, workspaceRoot: workspace)
let failures = results.filter { !$0.passed }

for result in results {
    let mark = result.passed ? "PASS" : "FAIL"
    print("\(mark) \(result.name) -> \(result.createdFileName)")
}

if !failures.isEmpty {
    exit(1)
}
