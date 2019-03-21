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

public enum GRYCompiler {

	#if os(Linux) || os(FreeBSD)
	static let kotlinCompilerPath = "/opt/kotlinc/bin/kotlinc"
	#else
	static let kotlinCompilerPath = "/usr/local/bin/kotlinc"
	#endif

	public enum KotlinCompilationResult {
		case success(commandOutput: GRYShell.CommandOutput)
		case failure(errorMessage: String)
	}

	public static func compileAndRun(fileAt filePath: String) throws -> KotlinCompilationResult {
		let compilationResult = try compile(fileAt: filePath)
		guard case .success(_) = compilationResult else {
			return compilationResult
		}

		log?("\t- Running Kotlin...")
		let arguments = ["java", "-jar", "kotlin.jar"]
		let commandResult = GRYShell.runShellCommand(arguments, fromFolder: GRYUtils.buildFolder)

		guard let result = commandResult else {
			return .failure(errorMessage: "\t\t- Java running timed out.")
		}

		return .success(commandOutput: result)
	}

	public static func compile(fileAt filePath: String) throws -> KotlinCompilationResult {
		let kotlinCode = try generateKotlinCode(forFileAt: filePath)

		log?("\t- Compiling Kotlin...")
		let fileName = URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent
		let kotlinFilePath = GRYUtils.createFile(
			named: fileName + .kt,
			inDirectory: GRYUtils.buildFolder,
			containing: kotlinCode)

		// Call the kotlin compiler
		let arguments =
			["-include-runtime", "-d", GRYUtils.buildFolder + "/kotlin.jar", kotlinFilePath]
		let commandResult = GRYShell.runShellCommand(kotlinCompilerPath, arguments: arguments)

		// Ensure the compiler terminated successfully
		guard let result = commandResult else {
			return .failure(errorMessage: "\t\t- Kotlin compiler timed out.")
		}
		guard result.status == 0 else {
			return .failure(errorMessage:
				"\t\t- Error compiling kotlin files. Kotlin compiler says:\n" +
				"\(result.standardError)")
		}

		return .success(commandOutput: result)
	}

	public static func generateKotlinCode(forFileAt filePath: String) throws -> String {
		let ast = try generateGryphonASTAndRunPasses(forFileAt: filePath)

		log?("\t- Translating AST to Kotlin...")
		return try GRYKotlinTranslator().translateAST(ast)
	}

	public static func generateGryphonASTAndRunPasses(forFileAt filePath: String) throws -> GRYAST {
		let swiftAST = try generateSwiftAST(forFileAt: filePath)
		log?("\t- Translating Swift AST to Gryphon AST...")
		let ast = try GRYSwiftTranslator().translateAST(swiftAST)
		let astAfterPasses = GRYTranspilationPass.runAllPasses(on: ast)
		return astAfterPasses
	}

	public static func generateGryphonAST(forFileAt filePath: String) throws -> GRYAST {
		let swiftAST = try generateSwiftAST(forFileAt: filePath)
		log?("\t- Translating Swift AST to Gryphon AST...")
		let ast = try GRYSwiftTranslator().translateAST(swiftAST)
		return ast
	}

	public static func processExternalSwiftAST(_ filePath: String) throws -> GRYSwiftAST {
		let astFilePath = GRYUtils.changeExtension(of: filePath, to: .swiftASTDump)

		log?("\t- Building GRYSwiftAST from external AST...")
		let ast = try GRYSwiftAST(decodeFromSwiftASTDumpInFile: astFilePath)

		let cacheFilePath = GRYUtils.changeExtension(of: filePath, to: .grySwiftAST)
		let cacheFileWasJustCreated = GRYUtils.createFileIfNeeded(at: cacheFilePath, containing: "")
		let cacheIsOutdated =
			cacheFileWasJustCreated ||
				GRYUtils.file(astFilePath, wasModifiedLaterThan: cacheFilePath)
		if cacheIsOutdated {
			log?("\t\t- Updating \(cacheFilePath)...")
			try ast.encode(intoFile: cacheFilePath)
		}

		return ast
	}

	public static func generateSwiftAST(forFileAt filePath: String) throws -> GRYSwiftAST {
		let astDumpFilePath = GRYUtils.changeExtension(of: filePath, to: .swiftASTDump)

		log?("\t- Building GRYSwiftAST...")
		let ast = try GRYSwiftAST(decodeFromSwiftASTDumpInFile: astDumpFilePath)
		return ast
	}

	public static func getSwiftASTDump(forFileAt filePath: String) throws -> String {
		log?("\t- Getting swift AST dump...")
		let astDumpFilePath = GRYUtils.changeExtension(of: filePath, to: .swiftASTDump)
		return try String(contentsOfFile: astDumpFilePath)
	}

	//
	public static var shouldStopAtFirstError = false

	public private(set) static var errors = [Error]()
	public private(set) static var warnings = [String]()

	public static func handleError(_ error: Error) throws {
		if GRYCompiler.shouldStopAtFirstError {
			throw error
		}
		else {
			GRYCompiler.errors.append(error)
		}
	}

	public static func handleWarning(_ warning: String) {
		GRYCompiler.warnings.append(warning)
	}

	public static func printErrorsAndWarnings() {
		if !errors.isEmpty {
			print("Errors:")
			for error in errors {
				print("🚨 \(error)")
			}
		}

		if !warnings.isEmpty {
			print("Warnings:")
			for warning in warnings {
				print("⚠️ \(warning)")
			}
		}

		if hasErrorsOrWarnings() {
			print("Total: \(errors.count) errors and \(warnings.count) warnings.")
		}
	}

	public static func hasErrorsOrWarnings() -> Bool {
		return !errors.isEmpty || !warnings.isEmpty
	}

	public static func clearErrorsAndWarnings() {
		errors = []
		warnings = []
	}

	public static func printErrorStatistics() {
		let swiftASTDumpErrors = errors.compactMap { $0 as? GRYSwiftTranslatorError }
		if !swiftASTDumpErrors.isEmpty {
			print("Swift AST translator failed to translate:")

			let swiftASTDumpHistogram = swiftASTDumpErrors.group { $0.astName }
			for (astName, errorArray) in
				swiftASTDumpHistogram.sorted(by: { $0.value.count > $1.value.count })
			{
				print("- \(errorArray.count) \(astName)s")
			}
		}

		let kotlinTranslatorErrors = errors.compactMap { $0 as? GRYKotlinTranslatorError }
		if !kotlinTranslatorErrors.isEmpty {
			print("Kotlin translator failed to translate:")

			let kotlinTranslatorHistogram = kotlinTranslatorErrors.group { $0.astName }
			for (astName, errorArray) in
				kotlinTranslatorHistogram.sorted(by: { $0.value.count > $1.value.count })
			{
				print("- \(errorArray.count) \(astName)s")
			}
		}
	}

	//
	private static var log: ((String) -> ())? = { print($0) }

	public static var shouldLogProgress = false {
		didSet {
			if shouldLogProgress {
				log = { print($0) }
			}
			else {
				log = nil
			}
		}
	}
}
