import Foundation
import SwiftBasicFormat
import SwiftSyntax

final class HeaderFormat: BasicFormat {
    override func requiresNewline(between first: TokenSyntax?, and second: TokenSyntax?) -> Bool {
        switch (first?.tokenKind, second?.tokenKind) {
        case (.leftBrace, .rightBrace):
            return false
        case (.leftBrace, .keyword(.get)),
             (.keyword(.get), .keyword(.set)),
             (.keyword(.get), .rightBrace),
             (.keyword(.set), .rightBrace):
            var node = Syntax(first!)
            while let parent = node.parent {
                defer { node = parent }
                if parent.is(AccessorBlockSyntax.self) {
                    return false
                }
            }
        default: break
        }
        return super.requiresNewline(between: first, and: second)
    }

    // FIXME: remove when it becomes consistent with Python-built one
    override func requiresWhitespace(between first: TokenSyntax?, and second: TokenSyntax?) -> Bool {
        if case .colon = second?.tokenKind {
            var node = Syntax(first)
            while let parent = node?.parent {
                defer { node = parent }
                if parent.is(EnumDeclSyntax.self) {
                    return true
                }
                // print(parent)
                // print(parent.kind)
            }
        }
        return super.requiresWhitespace(between: first, and: second)
    }

    override func visit(_ node: ProtocolDeclSyntax) -> DeclSyntax {
        super.visit(node.with(\.trailingTrivia, .newline))
    }

    override func visit(_ node: EnumDeclSyntax) -> DeclSyntax {
        super.visit(node.with(\.trailingTrivia, .newline))
    }

    override func visit(_ node: VariableDeclSyntax) -> DeclSyntax {
        if let item = node.parent?.as(MemberBlockItemSyntax.self),
           let list = item.parent?.as(MemberBlockItemListSyntax.self),
           let index = list.index(of: item),
           index != list.indices.first {
            let previousItem = list[list.index(before: index)]
            if previousItem.decl.kind != node.kind {
                return super.visit(node.with(\.leadingTrivia, .newlines(2)))
            }
        }
        return super.visit(node)
    }

    override func visit(_ node: FunctionDeclSyntax) -> DeclSyntax {
        if let item = node.parent?.as(MemberBlockItemSyntax.self),
           let list = item.parent?.as(MemberBlockItemListSyntax.self),
           let index = list.index(of: item),
           index != list.indices.first {
            let previousItem = list[list.index(before: index)]
            if previousItem.decl.kind != node.kind {
                return super.visit(node.with(\.leadingTrivia, .newlines(2)))
            }
        }
        return super.visit(node)
    }
}
