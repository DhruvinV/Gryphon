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

// gryphon output: Sources/GryphonLib/Compiler.swiftAST
// gryphon output: Sources/GryphonLib/Compiler.gryphonASTRaw
// gryphon output: Sources/GryphonLib/Compiler.gryphonAST
// gryphon output: Bootstrap/Compiler.kt

import Foundation

public class Compiler {
	static let kotlinCompilerPath = (OS.osName == "Linux") ?
		"/opt/kotlinc/bin/kotlinc" :
		"/usr/local/bin/kotlinc"

	//
	public private(set) static var log: ((String) -> ()) = { print($0) }

	public static func shouldLogProgress(if value: Bool) {
		if value {
			log = { print($0) }
		}
		else {
			log = { _ in }
		}
	}

	//
	public static var shouldStopAtFirstError = false
	public static var shouldAvoidUnicodeCharacters = false

	public private(set) static var errors: MutableList<Error> = []
	public private(set) static var warnings: MutableList<String> = []

	internal static func handleError(_ error: Error) throws {
		if Compiler.shouldStopAtFirstError {
			throw error
		}
		else {
			Compiler.errors.append(error)
		}
	}

	internal static func handleWarning(
		message: String,
		details: String = "",
		sourceFile: SourceFile?,
		sourceFileRange: SourceFileRange?)
	{
		Compiler.warnings.append(
			Compiler.createErrorOrWarningMessage(
				message: message,
				details: details,
				sourceFile: sourceFile,
				sourceFileRange: sourceFileRange,
				isError: false))
	}

	public static func clearErrorsAndWarnings() {
		errors = []
		warnings = []
	}

	//
	public static func generateSwiftAST(fromASTDump astDump: String) throws -> SwiftAST {
		log("\t- Building SwiftAST...")
		let ast = try ASTDumpDecoder(encodedString: astDump).decode()
		return ast
	}

	public static func transpileSwiftAST(fromASTDumpFile inputFile: String) throws -> SwiftAST {
		let astDump = try Utilities.readFile(inputFile)
		return try generateSwiftAST(fromASTDump: astDump)
	}

	//
	public static func generateGryphonRawAST(
		fromSwiftAST swiftAST: SwiftAST,
		asMainFile: Bool)
		throws -> GryphonAST
	{
		log("\t- Translating Swift ASTs to Gryphon ASTs...")
		return try SwiftTranslator().translateAST(swiftAST, asMainFile: asMainFile)
	}

	public static func transpileGryphonRawASTs(
		fromASTDumpFiles inputFiles: MutableList<String>)
		throws -> MutableList<GryphonAST>
	{
		let asts = try inputFiles.map { try transpileSwiftAST(fromASTDumpFile: $0) }
		let translateAsMainFile = (inputFiles.count == 1)
		return try asts.map {
			try generateGryphonRawAST(fromSwiftAST: $0, asMainFile: translateAsMainFile)
		}.toMutableList()
	}

	//
	public static func generateGryphonASTAfterFirstPasses(
		fromGryphonRawAST ast: GryphonAST,
		withContext context: TranspilationContext)
		throws -> GryphonAST
	{
		log("\t- Running first round of passes...")
		try Utilities.updateLibraryFiles()
		return TranspilationPass.runFirstRoundOfPasses(on: ast, withContext: context)
	}

	public static func generateGryphonASTAfterSecondPasses(
		fromGryphonRawAST ast: GryphonAST,
		withContext context: TranspilationContext)
		throws -> GryphonAST
	{
		log("\t- Running second round of passes...")
		try Utilities.updateLibraryFiles()
		return TranspilationPass.runSecondRoundOfPasses(on: ast, withContext: context)
	}

	public static func generateGryphonAST(
		fromGryphonRawAST ast: GryphonAST,
		withContext context: TranspilationContext)
		throws -> GryphonAST
	{
		var ast = ast
		log("\t- Running passes on Gryphon ASTs...")
		try Utilities.updateLibraryFiles()
		ast = TranspilationPass.runFirstRoundOfPasses(on: ast, withContext: context)
		ast = TranspilationPass.runSecondRoundOfPasses(on: ast, withContext: context)
		return ast
	}

	public static func transpileGryphonASTs(
		fromASTDumpFiles inputFiles: MutableList<String>,
		withContext context: TranspilationContext)
		throws -> MutableList<GryphonAST>
	{
		let rawASTs = try transpileGryphonRawASTs(fromASTDumpFiles: inputFiles)
		return try rawASTs.map {
			try generateGryphonAST(fromGryphonRawAST: $0, withContext: context)
		}.toMutableList()
	}

	//
	public static func generateKotlinCode(
		fromGryphonAST ast: GryphonAST,
		withContext context: TranspilationContext)
		throws -> String
	{
		log("\t- Translating AST to Kotlin...")
		let translation = try KotlinTranslator(context: context).translateAST(ast)
		let translationResult = translation.resolveTranslation()

		if let swiftFilePath = ast.sourceFile?.path, let kotlinFilePath = ast.outputFileMap[.kt] {
			let errorMap = translationResult.errorMap
			let errorMapFilePath = Utilities.pathOfKotlinErrorMapFile(forKotlinFile: kotlinFilePath)
			let errorMapFolder =
				errorMapFilePath.split(withStringSeparator: "/").dropLast().joined(separator: "/")
			let errorMapFileContents = swiftFilePath + "\n" + errorMap
			Utilities.createFolderIfNeeded(at: errorMapFolder)
			Utilities.createFile(atPath: errorMapFilePath, containing: errorMapFileContents)
		}

		return translationResult.translation
	}

	public static func transpileKotlinCode(
		fromASTDumpFiles inputFiles: MutableList<String>,
		withContext context: TranspilationContext)
		throws -> MutableList<String>
	{
		let asts = try transpileGryphonASTs(fromASTDumpFiles: inputFiles, withContext: context)
		return try asts.map {
			try generateKotlinCode(fromGryphonAST: $0, withContext: context)
		}.toMutableList()
	}

	//
	public static func compile(kotlinFiles filePaths: MutableList<String>, outputFolder: String)
		throws -> Shell.CommandOutput?
	{
		log("\t- Compiling Kotlin...")

		// Call the kotlin compiler
		let arguments: MutableList = ["-include-runtime", "-d", outputFolder + "/kotlin.jar"]
		arguments.append(contentsOf: filePaths)
		let commandResult = Shell.runShellCommand(kotlinCompilerPath, arguments: arguments)

		return commandResult
	}

	public static func transpileThenCompile(
		ASTDumpFiles inputFiles: MutableList<String>,
		withContext context: TranspilationContext,
		outputFolder: String = OS.buildFolder)
		throws -> Shell.CommandOutput?
	{
		let kotlinCodes = try transpileKotlinCode(
			fromASTDumpFiles: inputFiles,
			withContext: context)
		// Write kotlin files to the output folder
		let kotlinFilePaths: MutableList<String> = []
		for (inputFile, kotlinCode) in zipToClass(inputFiles, kotlinCodes) {
			let inputFileName = inputFile.split(withStringSeparator: "/").last!
			let kotlinFileName = Utilities.changeExtension(of: inputFileName, to: .kt)
			let folderWithSlash = outputFolder.hasSuffix("/") ? outputFolder : (outputFolder + "/")
			let kotlinFilePath = folderWithSlash + kotlinFileName
			Utilities.createFile(atPath: kotlinFilePath, containing: kotlinCode)
			kotlinFilePaths.append(kotlinFilePath)
		}

		return try compile(kotlinFiles: kotlinFilePaths, outputFolder: outputFolder)
	}

	//
	public static func runCompiledProgram(
		inFolder buildFolder: String,
		withArguments arguments: MutableList<String> = [])
		throws -> Shell.CommandOutput?
	{
		log("\t- Running Kotlin...")

		let processedBuildFolder = buildFolder.hasSuffix("/") ? buildFolder : (buildFolder + "/")

		// Run the compiled program
		let commandArguments: MutableList = ["java", "-jar", processedBuildFolder + "kotlin.jar"]
		commandArguments.append(contentsOf: arguments)
		let commandResult = Shell.runShellCommand(commandArguments)

		return commandResult
	}

	public static func transpileCompileAndRun(
		ASTDumpFiles inputFiles: MutableList<String>,
		withContext context: TranspilationContext,
		fromFolder outputFolder: String = OS.buildFolder)
		throws -> Shell.CommandOutput?
	{
		let compilationResult = try transpileThenCompile(
			ASTDumpFiles: inputFiles,
			withContext: context,
			outputFolder: outputFolder)
		guard compilationResult != nil, compilationResult!.status == 0 else {
			return compilationResult
		}
		return try runCompiledProgram(inFolder: outputFolder)
	}

	public static func printErrorsAndWarnings() {
		if !errors.isEmpty {
			print("Errors:")
			for error in errors {
				print(error)
			}
		}

		if !warnings.isEmpty {
			print("Warnings:")
			for warning in warnings {
				print(warning)
			}
		}

		if hasErrorsOrWarnings() {
			print("Total: \(errors.count) errors and \(warnings.count) warnings.")
		}
	}

	public static func hasErrorsOrWarnings() -> Bool {
		return !errors.isEmpty || !warnings.isEmpty
	}

	public static func printErrorStatistics() {
		print("Errors: \(Compiler.errors.count). Warnings: \(Compiler.warnings.count).")

		let swiftASTDumpErrors = errors.compactMap { $0 as? SwiftTranslatorError }
		if !swiftASTDumpErrors.isEmpty {
			print("Swift AST translator failed to translate:")

			let swiftASTDumpHistogram = swiftASTDumpErrors.group { $0.ast.name }

			let sortedHistogram = swiftASTDumpHistogram.toList().sorted(by: { a, b in
					a.1.count > b.1.count
				})

			for tuple in sortedHistogram {
				let astName = tuple.0
				let errorArray = tuple.1
				print("- \(errorArray.count) \(astName)s")
			}
		}

		let kotlinTranslatorErrors = errors.compactMap { $0 as? KotlinTranslatorError }
		if !kotlinTranslatorErrors.isEmpty {
			print("Kotlin translator failed to translate:")

			let kotlinTranslatorHistogram = kotlinTranslatorErrors.group { $0.ast.name }

			let sortedHistogram = kotlinTranslatorHistogram.sorted(by: { a, b in // kotlin: ignore
				a.value.count > b.value.count
			})

			// insert: val sortedHistogram = kotlinTranslatorHistogram.entries.toMutableList()
			// insert:     .sorted(isAscending = { a, b ->
			// insert:         a.value.size > b.value.size
			// insert:     })

			for tuple in sortedHistogram {
				let astName = tuple.key
				let errorArray = tuple.value
				print("- \(errorArray.count) \(astName)s")
			}
		}
	}
}

extension Compiler {
	static func createErrorOrWarningMessage(
		message: String,
		details: String,
		sourceFile: SourceFile?,
		sourceFileRange: SourceFileRange?,
		isError: Bool = true) -> String
	{
		let errorOrWarning = isError ? "error" : "warning"

		if let sourceFile = sourceFile {
			let sourceFilePath = sourceFile.path
			let absolutePath = Utilities.getAbsoultePath(forFile: sourceFilePath)

			if let sourceFileRange = sourceFileRange {
				let sourceFileString = sourceFile.getLine(sourceFileRange.lineStart) ??
					"<<Unable to get line \(sourceFileRange.lineStart) in file \(absolutePath)>>"

				var underlineString = ""
				if sourceFileRange.columnEnd < sourceFileString.count {
					for i in 1..<sourceFileRange.columnStart {
						let sourceFileCharacter = sourceFileString[
							sourceFileString.index(sourceFileString.startIndex, offsetBy: i - 1)]
						if sourceFileCharacter == "\t" {
							underlineString += "\t"
						}
						else {
							underlineString += " "
						}
					}
					underlineString += "^"
					if sourceFileRange.columnStart < sourceFileRange.columnEnd {
						for _ in (sourceFileRange.columnStart + 1)..<sourceFileRange.columnEnd {
							underlineString += "~"
						}
					}
				}

				return "\(absolutePath):\(sourceFileRange.lineStart):" +
					"\(sourceFileRange.columnStart): \(errorOrWarning): \(message)\n" +
					"\(sourceFileString)\n" +
					"\(underlineString)\n" +
					details
			}
			else {
				return "\(absolutePath): \(errorOrWarning): \(message)\n" +
					details
			}
		}
		else {
			return "\(errorOrWarning): \(message)\n" +
				details
		}
	}
}
