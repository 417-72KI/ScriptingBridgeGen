import Foundation
import Clang
import SwiftSyntax
import SwiftSyntaxBuilder

final class SBHeaderProcessor {
    private let headerFileUrl: URL
    private(set) var output = ""

    init(headerFileUrl: URL) {
        self.headerFileUrl = headerFileUrl
    }
}

extension SBHeaderProcessor {
    func emitSwift() throws {
        let xcodePath = try xcodePath
        let translationUnit = try TranslationUnit(
            filename: headerFileUrl.path(),
            commandLineArgs: [
                "-ObjC",
                "-I\(xcodePath)/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include/",
                "-F\(xcodePath)/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/",
            ]
        )
        var inclusions: [String] = []
        translationUnit.visitInclusion { includedFile, inclusionStack in
            if inclusionStack.count == 1 {
                let include = URL(filePath: includedFile.name)
                    .deletingPathExtension()
                    .lastPathComponent
                inclusions.append(include)
            }
        }
        try inclusions.sorted()
            .map { ImportDeclSyntax(path: [.init(name: .identifier($0))]) }
            .forEach(emitSyntax(_:))
        try emitLine()
        try emitLine(baseProtocols)
        try emitLine()

        let headerFilePath = headerFileUrl.path()
        let localChildren: [Cursor] = translationUnit.cursor.children().lazy
            .filter {
                let ptr = $0.range.asClang().ptr_data
                return ptr.0 != nil && ptr.1 != nil
            }
            .filter { $0.range.start.file.name == headerFilePath }
        let enums = localChildren.compactMap { $0 as? EnumDecl }
        try emitEnums(enums)
        try localChildren.compactMap { $0 as? ObjCProtocolDecl }
            .forEach(emitProtocol(_:))
        let categories = localChildren.compactMap { $0 as? ObjCCategoryDecl }
        try gatherCategories(categories)
        try localChildren.compactMap { $0 as? ObjCInterfaceDecl }
            .forEach(emitProtocol)
    }
}

private extension SBHeaderProcessor {
    var xcodePath: String {
        get throws {
            let process = Process()
            process.executableURL = URL(filePath: "/usr/bin/xcode-select")
            process.arguments = ["-p"]
            let stdout = Pipe()
            process.standardOutput = stdout
            try process.run()
            process.waitUntilExit()
            return try stdout.fileHandleForReading
                .readToEnd()
                .flatMap { String(data: $0, encoding: .utf8) } ?? ""
        }
    }

    var baseProtocols: String {
        """
        @objc public protocol SBObjectProtocol: NSObjectProtocol {
            func get() -> Any!
        }

        @objc public protocol SBApplicationProtocol: SBObjectProtocol {
            func activate()
            var delegate: SBApplicationDelegate! { get set }
            var isRunning: Bool { get }
        }
        """
    }
}

private extension SBHeaderProcessor {
    func emitEnums(_ cursors: [EnumDecl]) throws {
        func emitEnum(_ cursor: EnumDecl) throws {
            let displayName = cursor.displayName
            try emitLine("// MARK: \(displayName)")
            let caseSyntaxList = try cursor.children().lazy
                .compactMap { $0 as? EnumConstantDecl }
                .map { rawCase in
                    let convertedCase = try enumCase(rawCase.displayName,
                                                     prefix: displayName)
                    return EnumCaseDeclSyntax {
                        EnumCaseElementSyntax(
                            leadingTrivia: .space,
                            name: .identifier(convertedCase)
                                .with(\.trailingTrivia, .space),
                            rawValue: InitializerClauseSyntax(
                                equal: .equalToken(trailingTrivia: .space),
                                value: IntegerLiteralExprSyntax(literal: .integerLiteral(String(format: "0x%02x", rawCase.value)))
                            ),
                            trailingTrivia: [
                                .spaces(1),
                                .blockComment("/* '\(rawCase.value.hexChars)' */")
                            ]
                        )
                    }
                }
                .map { MemberBlockItemSyntax(decl: $0) }

            let syntax = EnumDeclSyntax(
                attributes: AttributeListSyntax {
                    .attribute("@objc")
                },
                modifiers: DeclModifierListSyntax {
                    DeclModifierSyntax(name: .keyword(.public))
                },
                name: .identifier(displayName),
                inheritanceClause: InheritanceClauseSyntax {
                    InheritedTypeSyntax(type: TypeSyntax("AEKeyword"))
                },
                memberBlock: .init(members: .init(caseSyntaxList)),
                trailingTrivia: .newline
            )
            try emitSyntax(syntax)
        }
        func enumCase(_ objcEnumCase: String, prefix: String) throws -> String {
            let strippedCase = objcEnumCase.trimmingPrefix(prefix)
            let allCapsRe = #/([A-Z]+)($)/#
            let singleCapRe = #/([A-Z])([^A-Z]+.*)/#
            let multipleCapsRe = #/([A-Z]+)([A-Z]([^0-9]+.*))/#
            let capsToDigitRe = #/([A-Z]+)([0-9]+.*)/#
            return if let match = strippedCase.firstMatch(of: allCapsRe) {
                match.output.1.lowercased() + match.output.2
            } else if let match = strippedCase.firstMatch(of: singleCapRe) {
                match.output.1.lowercased() + match.output.2
            } else if let match = strippedCase.firstMatch(of: capsToDigitRe) {
                match.output.1.lowercased() + match.output.2
            } else if let match = strippedCase.firstMatch(of: multipleCapsRe) {
                match.output.1.lowercased() + match.output.2
            } else {
                String(strippedCase)
            }
        }
        try cursors.forEach(emitEnum(_:))
    }

    func emitProtocol(_ decl: Cursor) throws {
        precondition(decl is ObjCInterfaceDecl || decl is ObjCProtocolDecl)
        // print(decl)
    }

    func gatherCategories(_ categories: [ObjCCategoryDecl]) throws {
        // print(categories)
    }
}

private extension SBHeaderProcessor {
    func emitSyntax(_ syntax: some SyntaxProtocol) throws {
        try emitLine(syntax.formatted().description)
    }

    func emitLine(_ line: String = "") throws {
        output += line + "\n"
    }
}
