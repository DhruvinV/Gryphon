/*
* Copyright 2018 Vinícius Jorge Vendramini
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

import Foundation
// declaration: import java.io.File
// declaration: import java.io.FileWriter

private func gryphonTemplates() {
	let _string1 = ""
	let _string2 = ""
	let _string3 = ""

	_ = Utilities.file(_string1, wasModifiedLaterThan: _string2)
	_ = "Utilities.fileWasModifiedLaterThan(_string1, _string2)"

	_ = Utilities.createFile(named: _string1, inDirectory: _string2, containing: _string3)
	_ = """
Utilities.createFileAndDirectory(fileName = _string1, directory = _string2, contents = _string3)
"""
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
		var newComponents = components.dropLast()
			.map { String($0) } // kotlin: ignore
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

extension Utilities { // kotlin: ignore
	public static func file(
		_ filePath: String, wasModifiedLaterThan otherFilePath: String) -> Bool
	{
		let fileManager = FileManager.default
		let fileAttributes = try! fileManager.attributesOfItem(atPath: filePath)
		let otherFileAttributes = try! fileManager.attributesOfItem(atPath: otherFilePath)

		let fileModifiedDate = fileAttributes[.modificationDate] as! Date
		let otherFileModifiedDate = otherFileAttributes[.modificationDate] as! Date

		let howMuchLater = fileModifiedDate.timeIntervalSince(otherFileModifiedDate)

		return howMuchLater > 0
	}
}

// declaration: fun Utilities.Companion.fileWasModifiedLaterThan(
// declaration: 	filePath: String, otherFilePath: String): Boolean
// declaration: {
// declaration: 	val file = File(filePath)
// declaration: 	val fileModifiedDate = file.lastModified()
// declaration: 	val otherFile = File(otherFilePath)
// declaration: 	val otherFileModifiedDate = otherFile.lastModified()
// declaration: 	val isAfter = fileModifiedDate > otherFileModifiedDate
// declaration: 	return isAfter
// declaration: }

class OS { // kotlin: ignore
	#if os(macOS)
	static let osName = "macOS"
	#else
	static let osName = "Linux"
	#endif

	#if arch(x86_64)
	static let architecture = "x86_64"
	#elseif arch(i386)
	static let architecture = "i386"
	#endif

	public static let systemIdentifier: String = osName + "-" + architecture

	public static let buildFolder = ".kotlinBuild-\(systemIdentifier)"
}

// declaration:
// declaration: class OS {
// declaration: 	companion object {
// declaration: 		val javaOSName = System.getProperty("os.name")
// declaration: 		val osName = if (javaOSName == "Mac OS X") { "macOS" } else { "Linux" }
// declaration:
// declaration: 		val javaArchitecture = System.getProperty("os.arch")
// declaration: 		val architecture = if (javaArchitecture == "x86_64") { "x86_64" }
// declaration: 			else { "i386" }
// declaration:
// declaration: 		val systemIdentifier: String = osName + "-" + architecture
// declaration: 		val buildFolder = ".kotlinBuild-${systemIdentifier}"
// declaration: 	}
// declaration: }

extension Utilities { // kotlin: ignore
	@discardableResult
	internal static func createFile(
		named fileName: String,
		inDirectory directory: String,
		containing contents: String) -> String
	{
		// Create directory (and intermediate directories if needed)
		let fileManager = FileManager.default
		try! fileManager.createDirectory(atPath: directory, withIntermediateDirectories: true)

		// Create file path
		let filePath = directory + "/" + fileName
		let fileURL = URL(fileURLWithPath: filePath)

		// Delete file if it exists, do nothing if it doesn't
		try? fileManager.removeItem(at: fileURL)

		// Create the file and write to it
		let success = fileManager.createFile(atPath: filePath, contents: Data(contents.utf8))
		assert(success)

		return filePath
	}
}

// declaration:
// declaration: fun Utilities.Companion.createFileAndDirectory(
// declaration: 		fileName: String,
// declaration: 		directory: String,
// declaration: 		contents: String): String
// declaration: {
// declaration: 	// Create directory (and intermediate directories if needed)
// declaration: 	val directoryFile = File(directory)
// declaration: 	directoryFile.mkdirs()
// declaration:
// declaration: 	// Create file path
// declaration: 	val filePath = directory + "/" + fileName
// declaration:
// declaration: 	// Delete file if it exists, do nothing if it doesn't
// declaration: 	val file = File(filePath)
// declaration: 	file.delete()
// declaration:
// declaration: 	// Create the file and write to it
// declaration: 	val success = file.createNewFile()
// declaration: 	assert(success)
// declaration: 	val writer = FileWriter(file)
// declaration: 	writer.write(contents)
// declaration: 	writer.close()
// declaration:
// declaration: 	return filePath
// declaration: }

extension Utilities { // kotlin: ignore
	/// - Returns: `true` if the file was created, `false` if it already existed.
	public static func createFileIfNeeded(at filePath: String) -> Bool
	{
		let fileManager = FileManager.default

		if !fileManager.fileExists(atPath: filePath) {
			let success = fileManager.createFile(atPath: filePath, contents: nil)
			assert(success)
			return true
		}
		else {
			return false
		}
	}
}

// declaration:
// declaration: fun Utilities.Companion.createFileIfNeeded(filePath: String): Boolean {
// declaration: 	val file = File(filePath)
// declaration: 	if (!file.exists()) {
// declaration: 		val success = file.createNewFile()
// declaration: 		assert(success)
// declaration: 		return true
// declaration: 	}
// declaration: 	else {
// declaration: 		return false
// declaration: 	}
// declaration: }

////////////////////////////////////////////////////////////////////////////////////////////////////

enum FileError: Error, CustomStringConvertible {
	case outdatedFile(inFolder: String)

	var description: String { // annotation: override
		switch self {
		case let .outdatedFile(inFolder: folder):
			return "One of the files in the \(folder) folder is outdated.\n" +
				"Try running the preBuildScript.sh and the test suite to update compilation " +
			"files."
		}
	}
}

private var libraryFilesHaveBeenUpdated = false
private var testFilesHaveBeenUpdated = false

extension Utilities {
	static public func updateLibraryFiles() throws { // kotlin: ignore
		guard !libraryFilesHaveBeenUpdated else {
			return
		}

		let libraryTemplatesFolder = "Library Templates"
		if needsToUpdateFiles(in: libraryTemplatesFolder, from: .swift, to: .swiftASTDump) {
			throw FileError.outdatedFile(inFolder: libraryTemplatesFolder)
		}

		print("\t* Updating library files...")

		let libraryFilesPath = Process().currentDirectoryPath + "/\(libraryTemplatesFolder)/"
		let currentURL = URL(fileURLWithPath: libraryFilesPath)
		let fileURLs = try! FileManager.default.contentsOfDirectory(
			at: currentURL,
			includingPropertiesForKeys: nil)
		let templateFiles = fileURLs.filter {
			$0.pathExtension == FileExtension.swiftASTDump.rawValue
			}.sorted { (url1: URL, url2: URL) -> Bool in
				url1.absoluteString < url2.absoluteString
		}

		let templateFilePaths = templateFiles.map { $0.path }
		let asts = try Compiler.generateGryphonAST(forFilesAt: templateFilePaths)

		for ast in asts {
			_ = RecordTemplatesTranspilationPass(ast: ast).run()
		}

		libraryFilesHaveBeenUpdated = true

		print("\t* Done!")
	}

	static public func updateTestFiles() throws { // kotlin: ignore
		guard !testFilesHaveBeenUpdated else {
			return
		}

		try updateLibraryFiles()

		print("\t* Updating unit test files...")

		let testFilesFolder = "Test Files"
		if needsToUpdateFiles(in: testFilesFolder, from: .swift, to: .swiftASTDump) {
			throw FileError.outdatedFile(inFolder: testFilesFolder)
		}

		testFilesHaveBeenUpdated = true

		print("\t* Done!")
	}

	static internal func needsToUpdateFiles( // kotlin: ignore
		_ files: [String]? = nil,
		in folder: String,
		from originExtension: FileExtension,
		to destinationExtension: FileExtension) -> Bool
	{
		var testFiles = getFilesInFolder(folder)
		testFiles = testFiles.filter { $0.pathExtension == originExtension.rawValue }

		if let files = files {
			testFiles = testFiles.filter {
					files.contains($0.deletingPathExtension().lastPathComponent)
				}
		}

		for originFile in testFiles {
			let originFilePath = originFile.path
			let destinationFilePath =
				Utilities.changeExtension(of: originFilePath, to: destinationExtension)

			let destinationFileWasJustCreated =
				Utilities.createFileIfNeeded(at: destinationFilePath)
			let destinationFileIsOutdated = destinationFileWasJustCreated ||
				Utilities.file(originFilePath, wasModifiedLaterThan: destinationFilePath)

			if destinationFileIsOutdated {
				return true
			}
		}

		return false
	}

	static public func getFilesInFolder(_ folder: String) -> [URL] { // kotlin: ignore
		let currentURL = URL(fileURLWithPath: Process().currentDirectoryPath + "/" + folder)
		let fileURLs = try! FileManager.default.contentsOfDirectory(
			at: currentURL,
			includingPropertiesForKeys: nil)
		return fileURLs.sorted { (url1: URL, url2: URL) -> Bool in
			url1.path < url2.path
		}
	}
}
