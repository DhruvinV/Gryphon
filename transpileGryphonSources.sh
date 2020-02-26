./.build/debug/Gryphon \
	-emit-kotlin \
	--indentation=4 \
	-skipASTDumps \
	\
	Sources/GryphonLib/ASTDumpDecoder.swift \
	Sources/GryphonLib/AuxiliaryFileContents.swift \
	Sources/GryphonLib/Compiler.swift \
	Sources/GryphonLib/Driver.swift \
	Sources/GryphonLib/Extensions.swift \
	Sources/GryphonLib/GryphonAST.swift \
	Sources/GryphonLib/GryphonSwiftLibrary.swift \
	Sources/GryphonLib/KotlinTranslator.swift \
	Sources/GryphonLib/LibraryTranspilationPass.swift \
	Sources/GryphonLib/PrintableAsTree.swift \
	Sources/GryphonLib/SharedUtilities.swift \
	Sources/GryphonLib/SourceFile.swift \
	Sources/GryphonLib/SwiftAST.swift \
	Sources/GryphonLib/SwiftTranslator.swift \
	Sources/GryphonLib/TranslationResult.swift \
	Sources/GryphonLib/TranspilationContext.swift \
	Sources/GryphonLib/TranspilationPass.swift \
	\
	Tests/GryphonLibTests/AcceptanceTest.swift \
	Tests/GryphonLibTests/ASTDumpDecoderTest.swift \
	Tests/GryphonLibTests/CompilerTest.swift \
	Tests/GryphonLibTests/DriverTest.swift \
	Tests/GryphonLibTests/ExtensionsTest.swift \
	Tests/GryphonLibTests/InitializationTest.swift \
	Tests/GryphonLibTests/IntegrationTest.swift \
	Tests/GryphonLibTests/LibraryTranspilationTest.swift \
	Tests/GryphonLibTests/ListTest.swift \
	Tests/GryphonLibTests/MutableListTest.swift \
	Tests/GryphonLibTests/MapTest.swift \
	Tests/GryphonLibTests/MutableMapTest.swift \
	Tests/GryphonLibTests/PrintableAsTreeTest.swift \
	Tests/GryphonLibTests/ShellTest.swift \
	Tests/GryphonLibTests/SourceFileTest.swift \
	Tests/GryphonLibTests/TranslationResultTest.swift \
	Tests/GryphonLibTests/UtilitiesTest.swift \
	\
	Tests/GryphonLibTests/TestUtilities.swift
