#if os(Linux) || os(FreeBSD)
import Glibc
#else
import Darwin
#endif

public enum GRYCompiler {
    public static func compile(fileAt filePath: String) -> String {
        let ast = generateAST(forFileAt: filePath)
		
		// Translate the AST to Kotlin
        print("-- Kotlin --")
        let kotlin = GRYKotlinTranslator().translateAST(ast)
        print(kotlin)
        
        return kotlin
    }

	public static func generateAST(forFileAt filePath: String) -> GRYAst {
		let astDump = getSwiftASTDump(forFileAt: filePath)
		
		// Parse the AST into Gryphon data structures
		print("-- Gryphon AST --")
		let ast = GRYAst(fileContents: astDump)
		ast.prettyPrint()
		
		return ast
	}
	
	public static func getSwiftASTDump(forFileAt filePath: String) -> String {
		// Call the swift compiler
		let command = ["swiftc", "-dump-ast", filePath]
		let commandResult = GRYShell.runShellCommand(command)
		
		// Ensure the compiler terminated successfully
		guard commandResult.status == 0 else {
			print("Error parsing and typechecking input files. Swift compiler says:\n\(commandResult.standardError)")
			exit(commandResult.status)
		}
		
		// The compiler has dumped the ast to stderr
		var astDump = commandResult.standardError

		// Trim any warnings swift may have printed before the actual AST dump
		astDump =~ "^((.*)\n)*\\(source\\_file\n" => "\\(source\\_file\n"
		
		return astDump
	}
}
