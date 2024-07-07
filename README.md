# ScriptingBridgeGen
Creates Swift APIs for using some macOS apps.
This tool automates the entire process of creating Swift files for using ScriptingBridge.

## Installation
TBD

> [!NOTE]
Before building a tool for the first time, you need to run `swift package resolve && swift .build/checkouts/ClangSwift/utils/make-pkgconfig.swift`.

## Usage
TBD

## Motivation
[SwiftScripting](https://github.com/tingraldi/SwiftScripting) was a great tool for creating Swift APIs for using ScriptingBridge.
However, it is no longer maintained and does not work on the current mac because of its Python version.
This tool is an attempt to create a similar tool that works with the latest version of Swift.
