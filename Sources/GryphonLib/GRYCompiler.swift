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
	
	public static func compileAndRun(fileAt filePath: String) -> KotlinCompilationResult {
		let compilationResult = compile(fileAt: filePath)
		guard case .success(_) = compilationResult else { return compilationResult }
		
		log?("Running Kotlin...")
		let arguments = ["java", "-jar", "kotlin.jar"]
		let commandResult = GRYShell.runShellCommand(arguments, fromFolder: GRYUtils.buildFolder)
		
		guard let result = commandResult else {
			return .failure(errorMessage: "Java running timed out.")
		}
		
		return .success(commandOutput: result)
	}
	
	public static func compile(fileAt filePath: String) -> KotlinCompilationResult {
		let kotlinCode = generateKotlinCode(forFileAt: filePath)
		
		log?("Compiling Kotlin...")
		let fileName = URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent
		let kotlinFilePath = GRYUtils.createFile(named: fileName + ".kt",
											  inDirectory: GRYUtils.buildFolder,
											  containing: kotlinCode)
		
		// Call the kotlin compiler
		let arguments = ["-include-runtime",  "-d", GRYUtils.buildFolder + "/kotlin.jar", kotlinFilePath]
		let commandResult = GRYShell.runShellCommand(kotlinCompilerPath, arguments: arguments)
		
		// Ensure the compiler terminated successfully
		guard let result = commandResult else {
			return .failure(errorMessage: "Kotlin compiler timed out.")
		}
		guard result.status == 0 else {
			return .failure(errorMessage: "Error compiling kotlin files. Kotlin compiler says:\n\(result.standardError)")
		}

		return .success(commandOutput: result)
	}
	
	public static func generateKotlinCode(forFileAt filePath: String) -> String {
		let jsonFile = GRYUtils.changeExtension(of: filePath, to: "json")
		let ast = GRYAst.initialize(fromJsonInFile: jsonFile)
		
		log?("Translating AST to Kotlin...")
		let kotlin = GRYKotlinTranslator().translateAST(ast)
		return kotlin
	}
	
	public static func generateAST(forFileAt filePath: String) -> GRYAst {
		let astDumpFilePath = GRYUtils.changeExtension(of: filePath, to: "ast")
		
		log?("Building GRYAst...")
		let ast = GRYAst(astFile: astDumpFilePath)
		return ast
	}
	
	public static func getSwiftASTDump(forFileAt filePath: String) -> String {
		log?("Getting swift AST dump...")
		let astDumpFilePath = GRYUtils.changeExtension(of: filePath, to: "ast")
		return try! String(contentsOfFile: astDumpFilePath)
	}
}
