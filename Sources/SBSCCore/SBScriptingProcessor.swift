import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder
import Util

final class SBScriptingProcessor {
    private let sdefFileUrl: URL
    private(set) var outputFileName: String!
    private(set) var output = ""

    init(sdefFileUrl: URL) {
        self.sdefFileUrl = sdefFileUrl
    }
}

extension SBScriptingProcessor {
    func process() throws {
        let names = try extractCases(xpath: "//suite/class/@name", keyword: "name")
            .union(try extractCases(xpath: "//suite/class-extension/@extends", keyword: "extends"))
            .sorted()
        let appName = sdefFileUrl.deletingPathExtension().lastPathComponent
        let enumName = "\(appName)Scripting"
        defer { outputFileName = "\(enumName).swift" }
        let syntax = try EnumDeclSyntax(
            modifiers: DeclModifierListSyntax {
                DeclModifierSyntax(name: .keyword(.public))
            },
            name: TokenSyntax(stringLiteral: enumName),
            inheritanceClause: InheritanceClauseSyntax {
                InheritedTypeSyntax(type: TypeSyntax(stringLiteral: "String"))
            }
        ) {
            for name in names {
                let enumCaseBase = name.replacingOccurrences(of: #"""#, with: "")
                    .replacingOccurrences(of: "-", with: " ")
                    .split(separator: " ")
                    .map(\.capitalized)
                    .joined()
                try EnumCaseDeclSyntax {
                    EnumCaseElementSyntax(
                        name: .identifier(try enumCase(enumCaseBase)),
                        rawValue: InitializerClauseSyntax(value: ExprSyntax(stringLiteral: name))
                    )
                }
            }
        }
        output = syntax.formatted().description
    }
}

private extension SBScriptingProcessor {
    func extractCases(xpath: String, keyword: String) throws -> Set<String> {
        func xmllint(xpath: String, filePath: String) throws -> String? {
            let process = Process()
            process.executableURL = URL(filePath: "/usr/bin/xmllint")
            process.arguments = [
                "--xpath",
                xpath,
                filePath
            ]
            let stdout = Pipe()
            process.standardOutput = stdout
            try process.run()
            process.waitUntilExit()
            guard let data = try stdout.fileHandleForReading.readToEnd() else { return nil }
            return String(data: data, encoding: .utf8)
        }
        guard let result = try xmllint(
            xpath: xpath,
            filePath: sdefFileUrl.path()
        ) else { return [] }
        return result.split(separator: "\n").lazy
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .compactMap { $0.split(separator: "\(keyword)=").last }
            .filter(\.isNotEmpty)
            .reduce(into: Set()) { $0.insert(String($1)) }
    }
}
