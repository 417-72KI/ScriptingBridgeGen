import Foundation
import Clang
import SwiftSyntax
import SwiftSyntaxBuilder

final class SBHeaderProcessor {
    private let headerFileUrl: URL
    private let lines: [String]
    private(set) var output = ""

    init(headerFileUrl: URL) throws {
        self.headerFileUrl = headerFileUrl
        lines = String(data: try Data(contentsOf: headerFileUrl), encoding: .utf8)?
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init) ?? []
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
        try emitSyntax(baseProtocols)

        let headerFilePath = headerFileUrl.path()
        let localChildren: [Cursor] = translationUnit.cursor.children().lazy
            .filter {
                let ptr = $0.range.asClang().ptr_data
                return ptr.0 != nil && ptr.1 != nil
            }
            .filter { $0.range.start.file.name == headerFilePath }
        let enums = localChildren.compactMap { $0 as? EnumDecl }
        try emitEnums(enums)
        try emitLine()

        try localChildren.compactMap { $0 as? ObjCProtocolDecl }
            .forEach(emitProtocol(_:))

        let categories = localChildren.compactMap { $0 as? ObjCCategoryDecl }
        let categoryDict = try gatherCategories(categories)
        try localChildren.compactMap { $0 as? ObjCInterfaceDecl }
            .forEach { try emitProtocol($0, withCategories: categoryDict) }
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

    var baseProtocols: some SyntaxProtocol {
        CodeBlockItemListSyntax {
            ProtocolDeclSyntax(
                attributes: "@objc",
                modifiers: DeclModifierListSyntax {
                    DeclModifierSyntax(name: .keyword(.public))
                },
                name: "SBObjectProtocol",
                inheritanceClause: InheritanceClauseSyntax {
                    InheritedTypeSyntax(type: "NSObjectProtocol" as TypeSyntax)
                }
            ) {
                FunctionDeclSyntax(
                    name: "get",
                    signature: FunctionSignatureSyntax(
                        parameterClause: .init(parameters: []),
                        returnClause: .init(type: "Any?" as TypeSyntax)
                    )
                )
            }
            ProtocolDeclSyntax(
                leadingTrivia: .newline,
                attributes: "@objc",
                modifiers: DeclModifierListSyntax {
                    DeclModifierSyntax(name: .keyword(.public))
                },
                name: "SBApplicationProtocol",
                inheritanceClause: InheritanceClauseSyntax {
                    InheritedTypeSyntax(type: "SBObjectProtocol" as TypeSyntax)
                }
            ) {
                FunctionDeclSyntax(
                    name: "activate",
                    signature: FunctionSignatureSyntax(
                        parameterClause: .init(parameters: [])
                    )
                )
                VariableDeclSyntax(
                    bindingSpecifier: .keyword(.var)
                ) {
                    PatternBindingSyntax(
                        pattern: IdentifierPatternSyntax(identifier: "delegate"),
                        typeAnnotation: TypeAnnotationSyntax(
                            type: "SBApplicationDelegate?" as TypeSyntax
                        ),
                        accessorBlock: AccessorBlockSyntax(
                            accessors: .accessors(
                                AccessorDeclListSyntax {
                                    AccessorDeclSyntax(accessorSpecifier: .keyword(.get))
                                    AccessorDeclSyntax(accessorSpecifier: .keyword(.set))
                                }
                            )
                        )
                    )
                }
                VariableDeclSyntax(
                    bindingSpecifier: .keyword(.var)
                ) {
                    PatternBindingSyntax(
                        pattern: IdentifierPatternSyntax(identifier: "isRunning"),
                        typeAnnotation: TypeAnnotationSyntax(
                            type: "Bool" as TypeSyntax
                        ),
                        accessorBlock: AccessorBlockSyntax(
                            accessors: .accessors(
                                AccessorDeclListSyntax {
                                    AccessorDeclSyntax(accessorSpecifier: .keyword(.get))
                                }
                            )
                        )
                    )
                }
            }
        }
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
                    let convertedCase = try enumCase(
                        rawCase.displayName,
                        prefix: displayName
                    )
                    return EnumCaseDeclSyntax {
                        EnumCaseElementSyntax(
                            leadingTrivia: .space,
                            name: .identifier(convertedCase)
                                .with(\.trailingTrivia, .space),
                            rawValue: InitializerClauseSyntax(
                                equal: .equalToken(trailingTrivia: .space),
                                value: IntegerLiteralExprSyntax(
                                    literal: .integerLiteral(String(format: "0x%02x", rawCase.value))
                                )
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
                memberBlock: .init(members: .init(caseSyntaxList))
            )
            try emitSyntax(syntax)
        }
        func enumCase(_ objcEnumCase: String, prefix: String) throws -> String {
            let strippedCase = objcEnumCase.trimmingPrefix(prefix)
            let allCapsRe = #/^([A-Z]+)($)/#
            let singleCapRe = #/^([A-Z])([^A-Z]+.*)/#
            let multipleCapsRe = #/^([A-Z]+)([A-Z]([^0-9]+.*))/#
            let capsToDigitRe = #/^([A-Z]+)([0-9]+.*)/#
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
}

private extension SBHeaderProcessor {
    func emitProtocol(_ decl: Cursor, 
                      withCategories categories: [String: [any Cursor]]) throws {
        precondition(decl is ObjCInterfaceDecl || decl is ObjCProtocolDecl)
        let protocolName = decl.displayName
        try emitLine("// MARK: \(protocolName)")

        func cursorSuperEntity(_ cursor: Cursor) -> String? {
            let tokens = cursor.translationUnit.tokens(in: cursor.range)
                .map { $0.spelling(in: cursor.translationUnit) }
            return if tokens[3] == ":", tokens.count > 4 {
                tokens[4]
            } else {
                nil
            }
        }

        let superEntity = cursorSuperEntity(decl)
        var implementedProtocols: [String] = []
        let isInterface: Bool
        if case let interfaceDecl as ObjCInterfaceDecl = decl {
            isInterface = true
            implementedProtocols = interfaceDecl.children()
                .compactMap { $0 as? ObjCProtocolRef }
                .map(\.displayName)
            if let superEntity {
                let superProtocol = if !superEntity.starts(with: "SB") {
                    superEntity
                } else {
                    "\(superEntity)Protocol"
                }
                implementedProtocols.insert(superProtocol, at: 0)
            }
        } else {
            isInterface = false
            implementedProtocols = if let superEntity {
                [superEntity]
            } else {
                []
            }
        }
        
        let children = decl.children() + categories[protocolName, default: []]

        // getters are declared by property
        var declaredFunctions: [String] = children.lazy
            .compactMap { $0 as? ObjCPropertyDecl }
            .map(\.displayName)
        var declaredProperties: [String] = []
        var declItems: [any DeclSyntaxProtocol] = []
        for child in children {
            if let propertyDecl = child as? ObjCPropertyDecl,
               !declaredProperties.contains(propertyDecl.displayName) {
                let propertyName = propertyDecl.displayName
                let propertyType = propertyDecl.type
                if let swiftType = convertType(propertyType) {
                    defer { declaredProperties.append(propertyName) }
                    let lineComment = extractLineComment(from: lines[propertyDecl.range.start.line - 1])
                    let syntax = VariableDeclSyntax(
                        attributes: AttributeListSyntax {
                            .attribute("@objc")
                        },
                        modifiers: DeclModifierListSyntax {
                            .init(name: .keyword(.optional))
                        },
                        bindingSpecifier: .keyword(.var),
                        bindingsBuilder: {
                            PatternBindingSyntax(
                                pattern: IdentifierPatternSyntax(
                                    identifier: .identifier(propertyName)
                                ),
                                typeAnnotation: TypeAnnotationSyntax(
                                    type: TypeSyntax(stringLiteral: swiftType)
                                ),
                                accessorBlock: AccessorBlockSyntax(
                                    accessors: .accessors(
                                        AccessorDeclListSyntax {
                                            AccessorDeclSyntax(accessorSpecifier: .keyword(.get))
                                        }
                                    )
                                )
                            )
                        },
                        trailingTrivia: lineComment.flatMap {
                            [.spaces(1), .lineComment($0)]
                        }
                    )
                    declItems.append(syntax)
                }
            } else if let methodDecl = child as? ObjCInstanceMethodDecl,
                      !declaredFunctions.contains(methodDecl.displayName) {
                defer { declaredFunctions.append(methodDecl.displayName) }
                let functionNameAndLabels = methodDecl.displayName
                    .split(separator: ":")
                    .map(String.init)
                let functionName = functionNameAndLabels[0]
                let params = methodDecl.children()
                    .compactMap { $0 as? ParmDecl }
                let returnType = methodDecl.children()
                    .first { !($0 is ParmDecl) }?.type
                    .flatMap(convertType)
                let lineComment = extractLineComment(from: lines[methodDecl.range.start.line - 1])
                let syntax = FunctionDeclSyntax(
                    attributes: "@objc",
                    modifiers: DeclModifierListSyntax {
                        DeclModifierSyntax(name: .keyword(.optional))
                    },
                    name: TokenSyntax(stringLiteral: functionName),
                    signature: FunctionSignatureSyntax(
                        parameterClause: FunctionParameterClauseSyntax {
                            for (position, param) in params.enumerated() {
                                let label = functionNameAndLabels[position]
                                let paramName = param.displayName
                                FunctionParameterSyntax(
                                    firstName: position == 0 ? .wildcardToken() : TokenSyntax(stringLiteral: label),
                                    secondName: label == paramName ? nil : TokenSyntax(stringLiteral: paramName),
                                    type: TypeSyntax(stringLiteral: convertType(param.type, asArg: true) ?? "")
                                )
                            }
                        },
                        returnClause: returnType.flatMap {
                            ReturnClauseSyntax(type: TypeSyntax(stringLiteral: $0))
                        }
                    ),
                    trailingTrivia: lineComment.flatMap {
                        [.spaces(1), .lineComment($0)]
                    }
                )
                declItems.append(syntax)
            } else if let protocolRef = child as? ObjCProtocolRef,
                      !implementedProtocols.contains(protocolRef.displayName) {
                implementedProtocols.append(protocolRef.displayName)
            }
        }

        let protocolSyntax = ProtocolDeclSyntax(
            attributes: AttributeListSyntax {
                .attribute("@objc")
            },
            modifiers: DeclModifierListSyntax {
                DeclModifierSyntax(name: .keyword(.public))
            },
            name: .identifier(protocolName),
            inheritanceClause: implementedProtocols.isEmpty ? nil : InheritanceClauseSyntax {
                InheritedTypeListSyntax {
                    for implementedProtocol in implementedProtocols {
                        InheritedTypeSyntax(type: TypeSyntax(stringLiteral: implementedProtocol))
                    }
                }
            }
        ) {
            for item in declItems {
                item
            }
        }
        let syntax = CodeBlockItemListSyntax {
            protocolSyntax
            if isInterface {
                let extensionClass = if let superEntity,
                    superEntity.starts(with: "SB") {
                        superEntity
                    } else {
                        "SBObject"
                    }
                ExtensionDeclSyntax(
                    extendedType: TypeSyntax(stringLiteral: extensionClass),
                    inheritanceClause: InheritanceClauseSyntax {
                        InheritedTypeSyntax(type: TypeSyntax(stringLiteral: protocolName))
                    }
                ) {}
            }
        }
        try emitSyntax(syntax)
        try emitLine()
    }

    func emitProtocol(_ decl: Cursor) throws {
        try emitProtocol(decl, withCategories: [:])
    }

    func gatherCategories(_ categories: [ObjCCategoryDecl]) throws -> [String: [any Cursor]] {
        var categoryDict: [String: [any Cursor]] = [:]
        categories.forEach {
            let children = $0.children().filter { !($0 is ObjCClassRef) }
            let classItem = $0.children().compactMap { $0 as? ObjCClassRef }[0]
            let key = classItem.displayName
            categoryDict[key] = if let items = categoryDict[key] {
                items + children
            } else {
                children
            }
        }
        return categoryDict
    }
}

private extension SBHeaderProcessor {
    func emitSyntax(_ syntax: some SyntaxProtocol) throws {
        try emitLine(syntax.formatted(using: HeaderFormat()).description)
    }

    func emitLine(_ line: String = "") throws {
        output += line + "\n"
    }
}

// MARK: -
private func convertType(_ objcType: CType?) -> String? {
    convertType(objcType, asArg: false)
}

private func convertType(_ objcType: CType?, asArg: Bool) -> String? {
    guard let objcType else { return nil }
    
    func removingPointer(from typeString: some StringProtocol) -> String {
        String(typeString.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")[0])
    }

    var resultType: String?
    if let genericMatch = objcType.description.firstMatch(of: #/(.*)<(.*)>.*/#) {
        let baseType = removingPointer(from: genericMatch.output.1)
        let genericParts = genericMatch.output.2.split(separator: ",")
            .map(removingPointer(from:))
            .map { typeDic[$0] ?? $0 }
        resultType = if baseType == "NSSet" {
            "Set<\(genericParts.joined(separator: ","))>"
        } else {
            "[\(genericParts.joined(separator: ","))]"
        }
    } else {
        let objcType = removingPointer(from: objcType.description)
        resultType = typeDic[objcType] ?? objcType
    }
    // if asArg,
    //    (objcType is ObjCIdType || objcType is ObjCObjectPointerType) {
    //     resultType? += "!"
    // }
    return resultType
}

// MARK: -
private func extractLineComment(from line: String) -> String? {
    let parts = line.components(separatedBy: "//")
    return if parts.count == 2 {
        "//\(parts[1])"
    } else {
        nil
    }
}
