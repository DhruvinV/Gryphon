//
// Copyright 2018 Vinícius Jorge Vendramini
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation

private func gryphonTemplates() {
    let _string1 = ""
    let _string2 = ""
    let _string3 = ""
    let _stringArray: ArrayClass<String>? = []
    let _stringArray1: ArrayClass<String> = []
    let _stringArray2: ArrayClass<String> = []
    let _fileExtension1 = FileExtension.swift
    let _fileExtension2 = FileExtension.swift
    let _timeInterval: TimeInterval = 0

    _ = Utilities.file(_string1, wasModifiedLaterThan: _string2)
    _ = "Utilities.fileWasModifiedLaterThan(_string1, _string2)"

    _ = Utilities.files(_stringArray1, wereModifiedLaterThan: _stringArray2)
    _ = "Utilities.filesWereModifiedLaterThan(_stringArray1, _stringArray2)"

    _ = Utilities.createFile(named: _string1, inDirectory: _string2, containing: _string3)
    _ = "Utilities.createFileAndDirectory(" +
        "fileName = _string1, directory = _string2, contents = _string3)"

    _ = Utilities.getFiles(_stringArray, inDirectory: _string1, withExtension: _fileExtension1)
    _ = "getFiles(" +
        "selectedFiles = _stringArray, directory = _string1, fileExtension = _fileExtension1)"

    _ = Utilities.getFiles(inDirectory: _string1, withExtension: _fileExtension1)
    _ = "getFiles(directory = _string1, fileExtension = _fileExtension1)"

    _ = Utilities.getAbsoultePath(forFile: _string1)
    _ = "Utilities.getAbsoultePath(file = _string1)"

    _ = Utilities.createFileIfNeeded(at: _string1)
    _ = "Utilities.createFileIfNeeded(filePath = _string1)"

    Utilities.createFile(atPath: _string1, containing: _string2)
    _ = "Utilities.createFile(filePath = _string1, contents = _string2)"

    _ = Utilities.needsToUpdateFiles(
        _stringArray, in: _string1, from: _fileExtension1, to: _fileExtension2)
    _ = "Utilities.needsToUpdateFiles(" +
        "files = _stringArray, " +
        "folder = _string1, " +
        "originExtension = _fileExtension1, " +
        "destinationExtension = _fileExtension2)"

    _ = Utilities.needsToUpdateFiles(
        in: _string1, from: _fileExtension1, to: _fileExtension2)
    _ = "Utilities.needsToUpdateFiles(" +
        "folder = _string1, " +
        "originExtension = _fileExtension1, " +
        "destinationExtension = _fileExtension2)"

    // Shell translations
    _ = Shell.runShellCommand(
        _string1, arguments: _stringArray1, fromFolder: _string2, timeout: _timeInterval)
    _ = "Shell.runShellCommand(_string1, arguments = _stringArray1, currentFolder = _string2, " +
        "timeout = _timeInterval)"

    _ = Shell.runShellCommand(
        _string1, arguments: _stringArray1, fromFolder: _string2)
    _ = "Shell.runShellCommand(_string1, arguments = _stringArray1, currentFolder = _string2)"

    _ = Shell.runShellCommand(
        _string1, arguments: _stringArray1, timeout: _timeInterval)
    _ = "Shell.runShellCommand(_string1, arguments = _stringArray1, timeout = _timeInterval)"

    _ = Shell.runShellCommand(
        _string1, arguments: _stringArray1)
    _ = "Shell.runShellCommand(_string1, arguments = _stringArray1)"

    //
    _ = Shell.runShellCommand(_stringArray1, fromFolder: _string1, timeout: _timeInterval)
    _ = "Shell.runShellCommand(_stringArray1, currentFolder = _string1, timeout = _timeInterval)"

    _ = Shell.runShellCommand(_stringArray1, fromFolder: _string1)
    _ = "Shell.runShellCommand(_stringArray1, currentFolder = _string1)"

    _ = Shell.runShellCommand(_stringArray1, timeout: _timeInterval)
    _ = "Shell.runShellCommand(_stringArray1, timeout = _timeInterval)"

    _ = Shell.runShellCommand(_stringArray1)
    _ = "Shell.runShellCommand(_stringArray1)"
}

public class Utilities {
    internal static func expandSwiftAbbreviation(_ name: String) -> String {
        // Separate snake case and capitalize
        var nameComponents = name.split(withStringSeparator: "_").map { $0.capitalized }

        // Expand swift abbreviations
        nameComponents = nameComponents.map { (word: String) -> String in
            switch word {
            case "Decl": return "Declaration"
            case "Declref": return "Declaration Reference"
            case "Expr": return "Expression"
            case "Func": return "Function"
            case "Ident": return "Identity"
            case "Paren": return "Parentheses"
            case "Ref": return "Reference"
            case "Stmt": return "Statement"
            case "Var": return "Variable"
            default: return word
            }
        }

        // Join words into a single string
        return nameComponents.joined(separator: " ")
    }
}

public enum FileExtension: String {
    // This should be the same as the extension in the dumpAST.pl and separateASTs.pl files
    case swiftASTDump
    case swiftAST
    case gryphonASTRaw
    case gryphonAST
    case output
    case kt
    case swift
}

extension String {
    func withExtension(_ fileExtension: FileExtension) -> String {
        return self + "." + fileExtension.rawValue
    }
}

extension Utilities {
    public static func changeExtension(of filePath: String, to newExtension: FileExtension)
        -> String
    {
        let components = filePath.split(withStringSeparator: "/", omittingEmptySubsequences: false)
        let newComponents = ArrayClass<String>(components.dropLast().map { String($0) })
        let nameComponent = components.last!
        let nameComponents =
            nameComponent.split(withStringSeparator: ".", omittingEmptySubsequences: false)

        // If there's no extension
        guard nameComponents.count > 1 else {
            return filePath.withExtension(newExtension)
        }

        let nameWithoutExtension = nameComponents.dropLast().joined(separator: ".")
        let newName = nameWithoutExtension.withExtension(newExtension)
        newComponents.append(newName)
        return newComponents.joined(separator: "/")
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////

enum FileError: Error, CustomStringConvertible {
    case outdatedFile(inFolder: String)

    var description: String {
        switch self {
        case let .outdatedFile(inFolder: folder):
            return "One of the files in the \(folder) folder is outdated.\n" +
                "Try running the preBuildScript.sh and the test suite to update compilation " +
            "files."
        }
    }
}

internal var libraryFilesHaveBeenUpdated = false
internal var testFilesHaveBeenUpdated = false

extension Utilities {
    static public func updateLibraryFiles() throws {
        libraryUpdateLock.lock() // kotlin: ignore
        // insert: libraryUpdateLock.acquire()

        // TODO: defers should always be the first statement, or try-finally's should be adjusted
        defer {
            libraryUpdateLock.unlock() // kotlin: ignore
            // insert: libraryUpdateLock.release()
        }

        guard !libraryFilesHaveBeenUpdated else {
            return
        }

        let libraryTemplatesFolder = "Library Templates"
        if needsToUpdateFiles(in: libraryTemplatesFolder, from: .swift, to: .swiftASTDump) {
            throw FileError.outdatedFile(inFolder: libraryTemplatesFolder)
        }

        Compiler.log("\t* Updating library files...")

        let templateFilePaths =
            getFiles(inDirectory: libraryTemplatesFolder, withExtension: .swiftASTDump)
        let asts = try Compiler.transpileGryphonRawASTs(fromASTDumpFiles: templateFilePaths)

        for ast in asts {
			_ = RecordTemplatesTranspilationPass(
				ast: ast,
				context: TranspilationContext.globalContext).run()
        }

        libraryFilesHaveBeenUpdated = true

        Compiler.log("\t* Done!")
    }

    static public func updateTestFiles() throws {
        guard !testFilesHaveBeenUpdated else {
            return
        }

        try updateLibraryFiles()

        Compiler.log("\t* Updating unit test files...")

        let testFilesFolder = "Test Files"
        if needsToUpdateFiles(in: testFilesFolder, from: .swift, to: .swiftASTDump) {
            throw FileError.outdatedFile(inFolder: testFilesFolder)
        }

        testFilesHaveBeenUpdated = true

        Compiler.log("\t* Done!")
    }

    static internal func needsToUpdateFiles(
        _ files: ArrayClass<String>? = nil,
        in folder: String,
        from originExtension: FileExtension,
        to destinationExtension: FileExtension,
        outputFileMap: OutputFileMap? = nil) -> Bool
    {
        let testFiles = getFiles(files, inDirectory: folder, withExtension: originExtension)

        for originFile in testFiles {
            let destinationFilePath = outputFileMap?.getOutputFile(
                forInputFile: originFile,
                outputType: OutputFileMap.OutputType(fileExtension: destinationExtension)!)
                ?? Utilities.changeExtension(of: originFile, to: destinationExtension)

            let destinationFileWasJustCreated =
                Utilities.createFileIfNeeded(at: destinationFilePath)
            let destinationFileIsOutdated = destinationFileWasJustCreated ||
                Utilities.file(originFile, wasModifiedLaterThan: destinationFilePath)

            if destinationFileIsOutdated {
                return true
            }
        }

        return false
    }
}

extension Utilities {
    static func splitTypeList(
        _ typeList: String,
        separators: ArrayClass<String> = [",", ":"])
        -> ArrayClass<String>
    {
        var bracketsLevel = 0
        let result: ArrayClass<String> = []
        var currentResult = ""
        var remainingString = Substring(typeList)

        var index = typeList.startIndex

        while index < typeList.endIndex {
            let character = typeList[index]

            // If we're not inside brackets and we've found a separator
            if bracketsLevel <= 0,
                let foundSeparator = separators.first(where: { remainingString.hasPrefix($0) })
            {
                // Skip the separator
                index = typeList.index(index, offsetBy: foundSeparator.count - 1)

                // Add the built result to the array
                result.append(currentResult)
                currentResult = ""
            }
            else if character == "<" || character == "[" || character == "(" {
                bracketsLevel += 1
                currentResult.append(character)
            }
            else if character == ">" || character == "]" || character == ")" {
                bracketsLevel -= 1
                currentResult.append(character)
            }
            else if character == " " {
                if bracketsLevel > 0 {
                    currentResult.append(character)
                }
            }
            else {
                currentResult.append(character)
            }

            remainingString = remainingString.dropFirst()
            index = typeList.index(after: index)
        }

        // Add the last result that was being built
        if !currentResult.isEmpty {
            result.append(currentResult)
        }

        return result
    }

    static func isInEnvelopingParentheses(_ typeName: String) -> Bool {
        var parenthesesLevel = 0

        guard typeName.hasPrefix("("), typeName.hasSuffix(")") else {
            return false
        }

        let lastValidIndex = typeName.index(before: typeName.endIndex)

        for index in typeName.indices {
            let character = typeName[index]

            if character == "(" {
                parenthesesLevel += 1
            }
            else if character == ")" {
                parenthesesLevel -= 1
            }

            // If the first parentheses closes before the end of the string
            if parenthesesLevel == 0, index != lastValidIndex {
                return false
            }
        }

        return true
    }

    static func getTypeMapping(for typeName: String) -> String? {
        let typeMappings: DictionaryClass = [
            "Bool": "Boolean",
            "Error": "Exception",
            "UInt8": "UByte",
            "UInt16": "UShort",
            "UInt32": "UInt",
            "UInt64": "ULong",
            "Int8": "Byte",
            "Int16": "Short",
            "Int32": "Int",
            "Int64": "Long",
            "Float32": "Float",
            "Float64": "Double",
            "Character": "Char",

            "String.Index": "Int",
            "Substring.Index": "Int",
            "Substring": "String",
            "String.SubSequence": "String",
            "Substring.SubSequence": "String",
            "Substring.Element": "Char",
            "String.Element": "Char",
            "Range<String.Index>": "IntRange",
            "Range<Int>": "IntRange",
            "Array<Element>.Index": "Int",
        ]

        return typeMappings[typeName]
    }
}