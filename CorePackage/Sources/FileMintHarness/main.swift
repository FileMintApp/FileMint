import FileMintCore
import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())
// Keep usage errors machine-readable when a valid JSON format flag was supplied.
let wantsJSON = zip(arguments, arguments.dropFirst()).contains { $0 == "--format" && $1 == "json" }
var format = "text"
var input: String?
var sawFormat = false
var invalidArguments = false
var index = 0
while index < arguments.count {
    let argument = arguments[index]
    if argument == "--format" {
        index += 1
        if sawFormat || index >= arguments.count || !["text", "json"].contains(arguments[index]) {
            invalidArguments = true
            break
        }
        sawFormat = true
        format = arguments[index]
    } else if argument.hasPrefix("-") || input != nil {
        invalidArguments = true
        break
    } else {
        input = argument
    }
    index += 1
}

let report: HarnessReport
if invalidArguments || input == nil {
    report = .usageError()
    format = wantsJSON ? "json" : "text"
} else {
    do {
        let suite = try HarnessSuite.load(from: URL(fileURLWithPath: input!))
        report = HarnessRunner.run(suite)
    } catch {
        report = .inputError(error)
    }
}

do {
    let data = format == "json" ? try report.jsonData() : Data(report.text().utf8)
    try FileHandle.standardOutput.write(contentsOf: data + Data([10]))
} catch {
    fputs("ERROR report output failed\n", stderr)
    exit(2)
}
exit(report.exitCode)
