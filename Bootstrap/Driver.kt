class Driver {
	companion object {
		public fun run(arguments: MutableList<String>): Any? {
			Compiler.clearErrorsAndWarnings()

			val shouldEmitSwiftAST: Boolean = arguments.contains("-emit-swiftAST")
			val shouldEmitRawAST: Boolean = arguments.contains("-emit-rawAST")
			val shouldEmitAST: Boolean = arguments.contains("-emit-AST")
			val shouldRun: Boolean = arguments.contains("run")
			val shouldBuild: Boolean = shouldRun || arguments.contains("build")
			val hasChosenTask: Boolean = shouldEmitSwiftAST || shouldEmitRawAST || shouldEmitAST || shouldRun || shouldBuild
			val shouldEmitKotlin: Boolean = !hasChosenTask || arguments.contains("-emit-kotlin")
			val shouldGenerateKotlin: Boolean = shouldBuild || shouldEmitKotlin
			val shouldGenerateAST: Boolean = shouldGenerateKotlin || shouldEmitAST
			val shouldGenerateRawAST: Boolean = shouldGenerateAST || shouldEmitRawAST
			val shouldGenerateSwiftAST: Boolean = shouldGenerateRawAST || shouldEmitSwiftAST

			Compiler.shouldLogProgress(value = arguments.contains("-verbose"))

			Compiler.shouldStopAtFirstError = !arguments.contains("-continue-on-error")

			val horizontalLimit: Int?
			val lineLimitArgument: String? = arguments.find { it.startsWith("-line-limit=") }

			if (lineLimitArgument != null) {
				val lineLimitString: String = lineLimitArgument.drop("-line-limit=".length)
				horizontalLimit = lineLimitString.toIntOrNull()
			}
			else {
				horizontalLimit = null
			}

			val outputFileMap: OutputFileMap?
			val outputFileMapArgument: String? = arguments.find { it.startsWith("-output-file-map=") }

			if (outputFileMapArgument != null) {
				val outputFileMapPath: String = outputFileMapArgument.drop("-output-file-map=".length)
				outputFileMap = OutputFileMap(outputFileMapPath)
			}
			else {
				outputFileMap = null
			}

			val outputFolder: String
			val outputFolderIndex: Int? = arguments.indexOf("-o")

			if (outputFolderIndex != null) {
				val maybeOutputFolder: String? = arguments.getSafe(outputFolderIndex + 1)
				if (maybeOutputFolder != null) {
					outputFolder = maybeOutputFolder
				}
				else {
					outputFolder = OS.buildFolder
				}
			}
			else {
				outputFolder = OS.buildFolder
			}

			return null
		}
	}
}
