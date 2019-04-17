typealias OutputFileMapBuffer = MutableMap<String, MutableMap<OutputFileMap.OutputType, String>>

class OutputFileMap {
	public enum class OutputType {
		AST_DUMP,
		SWIFT_AST,
		GRYPHON_AST_RAW,
		GRYPHON_AST,
		KOTLIN;

		companion object {
			operator fun invoke(rawValue: String): OutputType? {
				return when (rawValue) {
					"ast-dump" -> OutputType.AST_DUMP
					"swiftAST" -> OutputType.SWIFT_AST
					"gryphonASTRaw" -> OutputType.GRYPHON_AST_RAW
					"gryphonAST" -> OutputType.GRYPHON_AST
					"kotlin" -> OutputType.KOTLIN
					else -> null
				}
			}
		}

		val rawValue: String
			get() {
				return when (this) {
					OutputType.AST_DUMP -> "ast-dump"
					OutputType.SWIFT_AST -> "swiftAST"
					OutputType.GRYPHON_AST_RAW -> "gryphonASTRaw"
					OutputType.GRYPHON_AST -> "gryphonAST"
					OutputType.KOTLIN -> "kotlin"
				}
			}
	}

	var buffer: OutputFileMapBuffer

	constructor(buffer: OutputFileMapBuffer) {
		this.buffer = buffer
	}

	public fun getFileMap(file: String): MutableMap<OutputFileMap.OutputType, String>? {
		return buffer[file]
	}

	public fun getOutputFile(file: String, outputType: OutputFileMap.OutputType): String? {
		val fileMap: MutableMap<OutputFileMap.OutputType, String>? = getFileMap(file = file)
		fileMap ?: return null
		return fileMap[outputType]
	}

	constructor(file: String) {
		val contents: String = Utilities.readFile(file)
		val result: MutableMap<String, MutableMap<OutputFileMap.OutputType, String>> = mutableMapOf()
		var currentFileResult: MutableMap<OutputFileMap.OutputType, String> = mutableMapOf()
		var currentFilePath: String? = null
		val lines: MutableList<String> = contents.split(separator = '\n')

		for (index in lines.indices) {
			val line: String = lines[index]
			val lineNumber: Int = index + 1
			val lineComponents: MutableList<String> = line.split(separator = '\"')
			val outputType: OutputType? = OutputType(rawValue = lineComponents[1])

			if (lineComponents.size == 1) {
				continue
			}
			else if (lineComponents.size < 4) {
				if (currentFilePath != null) {
					result[currentFilePath] = currentFileResult
				}
				currentFileResult = mutableMapOf()
				currentFilePath = lineComponents[1]
			}
			else if (outputType != null) {
				val outputFilePath: String = lineComponents[3]
				currentFileResult[outputType] = outputFilePath
			}
			else {
				val sourceFile: SourceFile = SourceFile(path = file, contents = contents)
				val sourceFileRange: SourceFileRange = SourceFileRange(
					lineStart = lineNumber,
					lineEnd = lineNumber,
					columnStart = 1,
					columnEnd = line.length)
			}
		}

		if (currentFilePath != null) {
			result[currentFilePath] = currentFileResult
		}

		this.buffer = result
	}
}
