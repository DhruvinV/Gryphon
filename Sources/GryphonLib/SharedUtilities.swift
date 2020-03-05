//
// Copyright 2018 Vinicius Jorge Vendramini
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

// gryphon output: Sources/GryphonLib/SharedUtilities.swiftAST
// gryphon output: Sources/GryphonLib/SharedUtilities.gryphonASTRaw
// gryphon output: Sources/GryphonLib/SharedUtilities.gryphonAST
// gryphon output: Bootstrap/SharedUtilities.kt

import Foundation

private func gryphonTemplates() {
    let _string1 = ""
    let _string2 = ""
    let _string3 = ""
    let _stringArray: MutableList<String>? = []
    let _stringArray1: MutableList<String> = []
    let _stringArray2: MutableList<String> = []
    let _fileExtension1 = FileExtension.swift
    let _timeInterval: TimeInterval = 0

    _ = Utilities.file(_string1, wasModifiedLaterThan: _string2)
    _ = "Utilities.fileWasModifiedLaterThan(_string1, _string2)"

    _ = Utilities.files(_stringArray1, wereModifiedLaterThan: _stringArray2)
    _ = "Utilities.filesWereModifiedLaterThan(_stringArray1, _stringArray2)"

    _ = Utilities.createFile(named: _string1, inDirectory: _string2, containing: _string3)
    _ = "Utilities.createFileAndDirectory(" +
        "fileName = _string1, directory = _string2, contents = _string3)"

    _ = Utilities.getFiles(_stringArray, inDirectory: _string1, withExtension: _fileExtension1)
    _ = "Utilities.getFiles(" +
        "selectedFiles = _stringArray, directory = _string1, fileExtension = _fileExtension1)"

    _ = Utilities.getFiles(inDirectory: _string1, withExtension: _fileExtension1)
    _ = "Utilities.getFiles(directory = _string1, fileExtension = _fileExtension1)"

    _ = Utilities.getAbsoultePath(forFile: _string1)
    _ = "Utilities.getAbsoultePath(file = _string1)"

	_ = Utilities.fileExists(at: _string1)
	_ = "Utilities.fileExists(filePath = _string1)"

    _ = Utilities.createFileIfNeeded(at: _string1)
    _ = "Utilities.createFileIfNeeded(filePath = _string1)"

	Utilities.createFolderIfNeeded(at: _string1)
    _ = "Utilities.createFolderIfNeeded(path = _string1)"

    Utilities.createFile(atPath: _string1, containing: _string2)
    _ = "Utilities.createFile(filePath = _string1, contents = _string2)"

	Utilities.deleteFolder(at: _string1)
	_ = "Utilities.deleteFolder(path = _string1)"

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

/// Stores all hard-coded file names and paths. Changes to these paths might need to be reflected in
/// preBuildScript.sh, prepareForBootstrapTests.sh, and dumpASTs.pl
public class SupportingFile {
	let name: String

	private init(_ name: String) {
		self.name = name
	}

	var relativePath: String {
		if let folder = self.folder {
			return "\(folder)/\(name)"
		}
		else {
			return name
		}
	}

	/// Returns the location of the file (its parent folder) or nil if it's in the current folder
	var folder: String? {
		switch name {
		case SupportingFile.xcFileList.name:
			return nil
		case SupportingFile.mapKotlinErrorsToSwift.name,
			SupportingFile.mapGradleErrorsToSwift.name,
			SupportingFile.makeGryphonTargets.name,
			SupportingFile.compileKotlin.name:

			return SupportingFile.gryphonScriptsFolder
		default:
			return SupportingFile.gryphonBuildFolder
		}
	}

	var absolutePath: String {
		return Utilities.getAbsoultePath(forFile: relativePath)
	}

	//
	static public func pathOfSwiftASTDumpFile(forSwiftFile swiftFile: String) -> String {
		let relativePath = Utilities.getRelativePath(forFile: swiftFile)
		let pathInGryphonFolder = "\(astDumpsFolder)/\(relativePath)"
		let astDumpPath = Utilities.changeExtension(of: pathInGryphonFolder, to: .swiftASTDump)
		return astDumpPath
	}

	static public func pathOfKotlinErrorMapFile(forKotlinFile kotlinFile: String) -> String {
		let relativePath = Utilities.getRelativePath(forFile: kotlinFile)
		let pathInGryphonFolder = "\(kotlinErrorMapsFolder)/\(relativePath)"
		let errorMapPath = Utilities.changeExtension(of: pathInGryphonFolder, to: .kotlinErrorMap)
		return errorMapPath
	}

	// Folders
	public static let gryphonBuildFolder = ".gryphon"
	public static let gryphonScriptsFolder = "\(gryphonBuildFolder)/scripts"
	public static let kotlinErrorMapsFolder = "\(gryphonBuildFolder)/KotlinErrorMaps"
	public static let astDumpsFolder = "\(gryphonBuildFolder)/ASTDumps"

	// Files in the project folder
	public static let xcFileList = SupportingFile("gryphonInputFiles.xcfilelist")

	// Files in the Gryphon build folder ("/path/to/project/.gryphon")
	public static let gryphonTemplatesLibrary = SupportingFile("GryphonTemplatesLibrary.swift")
	public static let gryphonTemplatesLibraryASTDump = SupportingFile(
		Utilities.changeExtension(of: gryphonTemplatesLibrary.name, to: .swiftASTDump))
	public static let temporaryOutputFileMap = SupportingFile("output-file-map.json")
	public static let astDumpsScript = SupportingFile("updateASTDumps.sh")
	public static let gryphonXCTest = SupportingFile("GryphonXCTest.swift")

	// Files in the Gryphon scripts folder ("/path/to/project/.gryphon/scripts")
	public static let mapKotlinErrorsToSwift = SupportingFile("mapKotlinErrorsToSwift.swift")
	public static let mapGradleErrorsToSwift = SupportingFile("mapGradleErrorsToSwift.swift")
	public static let makeGryphonTargets = SupportingFile("makeGryphonTargets.rb")
	public static let compileKotlin = SupportingFile("compileKotlin.sh")
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
	case kotlinErrorMap
    case kt
    case swift

	case xcfilelist
	case xcodeproj
}

extension String {
    func withExtension(_ fileExtension: FileExtension) -> String {
        return self + "." + fileExtension.rawValue
    }
}

extension Utilities {
    public static func changeExtension(
		of filePath: String,
		to newExtension: FileExtension)
        -> String
    {
        let components = filePath.split(withStringSeparator: "/", omittingEmptySubsequences: false)
        let newComponents = MutableList<String>(components.dropLast())
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

	public static func getExtension(of filePath: String) -> FileExtension? {
        let components = filePath.split(withStringSeparator: "/", omittingEmptySubsequences: false)
        let nameComponent = components.last!
        let nameComponents =
            nameComponent.split(withStringSeparator: ".", omittingEmptySubsequences: false)

        // If there's no extension
        guard let extensionString = nameComponents.last else {
            return nil
        }

        return FileExtension(rawValue: extensionString)
    }

	public static func fileHasExtension(_ filePath: String, _ testExtension: FileExtension) -> Bool
	{
		if let fileExtension = getExtension(of: filePath),
			fileExtension == testExtension
		{
			return true
		}
		else {
			return false
		}
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

private var templatesLibraryHasBeenProcessed = false
private var testCasesHaveBeenUpdated = false

extension Utilities {
    static public func processGryphonTemplatesLibrary() throws {
        libraryUpdateLock.lock() // gryphon ignore
        // gryphon insert: libraryUpdateLock.acquire()

        // TODO: defers should always be the first statement, or try-finally's should be adjusted
        defer {
            libraryUpdateLock.unlock() // gryphon ignore
            // gryphon insert: libraryUpdateLock.release()
        }

        guard !templatesLibraryHasBeenProcessed else {
            return
        }

        let astArray = try Compiler.transpileGryphonRawASTs(
			fromASTDumpFiles: [SupportingFile.gryphonTemplatesLibraryASTDump.relativePath],
			withContext: TranspilationContext.globalContext)

        let ast = astArray[0]
		_ = RecordTemplatesTranspilationPass(
			ast: ast,
			context: TranspilationContext.globalContext).run()

        templatesLibraryHasBeenProcessed = true

        Compiler.log("\t* Done!")
    }

	// TODO: Send this (and associated code) to the test suite and rename this method
    static public func updateTestCases() throws {
        guard !testCasesHaveBeenUpdated else {
            return
        }

        try processGryphonTemplatesLibrary()

        Compiler.log("\t* Updating unit test files...")

        let testCasesFolder = "Test cases"
        if needsToDumpASTForSwiftFiles(in: testCasesFolder) {
            throw FileError.outdatedFile(inFolder: testCasesFolder)
        }

        testCasesHaveBeenUpdated = true

        Compiler.log("\t* Done!")
    }

    static internal func needsToDumpASTForSwiftFiles(
        _ swiftFiles: MutableList<String>? = nil,
        in folder: String)
		-> Bool
    {
		let files = getFiles(swiftFiles, inDirectory: folder, withExtension: .swift)

        for swiftFile in files {
			let astDumpFilePath: String
			// Normal files should go from "./path/to/file.swift" to
			// "./.gryphon/path/to/file.swiftASTDump". Files that are already in "./.gryphon", such
			// as the stdlib templates file, are special cases and should be dumped at "./.gryphon"
			// (rather than "./.gryphon/.gryphon", which is what the normal algorithm would return).
			if folder.hasSuffix(SupportingFile.gryphonBuildFolder) ||
				folder.hasSuffix(SupportingFile.gryphonBuildFolder + "/")
			{
				astDumpFilePath = Utilities.changeExtension(of: swiftFile, to: .swiftASTDump)
			}
			else {
				astDumpFilePath = SupportingFile.pathOfSwiftASTDumpFile(forSwiftFile: swiftFile)
			}

            let astDumpFileWasJustCreated =
                Utilities.createFileIfNeeded(at: astDumpFilePath)
            let astDumpFileIsOutdated = astDumpFileWasJustCreated ||
                Utilities.file(swiftFile, wasModifiedLaterThan: astDumpFilePath)

            if astDumpFileIsOutdated {
                return true
            }
        }

        return false
    }

	public static func getRelativePath(forFile file: String) -> String {
		let currentDirectoryPath = Utilities.getCurrentFolder()
		let absoluteFilePath = getAbsoultePath(forFile: file)
		return String(absoluteFilePath.dropFirst(currentDirectoryPath.count + 1))
	}
}

extension Utilities {
	/// Splits a type using the given separators, taking into consideration possible separators.
	/// For instance, "(A, (B, C))" becomes ["A", "(B, C)"] rather than ["A", "(B", "C)"].
    static func splitTypeList( // gryphon pure
        _ typeList: String,
        separators: MutableList<String> = [",", ":"])
        -> MutableList<String>
    {
        var bracketsLevel = 0
        let result: MutableList<String> = []
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
                index = typeList.index(index, offsetBy: foundSeparator.count)
				remainingString = typeList[index...]

                // Add the built result to the array
                result.append(currentResult)
                currentResult = ""
				continue
            }
			else if remainingString.hasPrefix("->") {
				// Avoid having the '>' in "->" be counted as a closing '>'
				currentResult.append("->")
				index = typeList.index(index, offsetBy: 2)
				remainingString = typeList[index...]
				continue
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
        let typeMappings: MutableMap = [
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
			"List<Element>.Index": "Int",
			"MutableList<Element>.Index": "Int",
        ]

        return typeMappings[typeName]
    }
}
