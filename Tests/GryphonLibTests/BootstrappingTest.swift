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

@testable import GryphonLib
import XCTest

class BootstrappingTest: XCTestCase {
	func testUnitTests() {
		guard !BootstrappingTest.hasError else {
			XCTFail("Error during setup")
			return
		}

		let commandResult = Shell.runShellCommand([
				"java", "-jar", "Bootstrap/kotlin.jar",
				"-test", "-avoid-unicode",
			])

		print(commandResult.standardOutput)
		print(commandResult.standardError)
		print("----- Status: \(commandResult.status) -----")

		let testsFailed = (commandResult.status != 0) ||
			commandResult.standardOutput.contains("Test failed!")
		XCTAssertFalse(testsFailed, "Kotlin unit tests failed. Printing stack trace:\n")

		if testsFailed {
			print(commandResult.standardError)
			print(commandResult.standardOutput)
		}
	}

	func testASTDumpDecoderOutput() {
		guard !BootstrappingTest.hasError else {
			XCTFail("Error during setup")
			return
		}

		let tests = TestUtilities.testCases

		for testName in tests {
			print("- Testing \(testName)...")

			do {
				let testCasePath = TestUtilities.testCasesPath + testName + ".swift"

				// Get Kotlin results
				let swiftASTFilePath = BootstrappingTest.getBootstrapOutputFilePath(
					forTest: testName,
					withExtension: .swiftAST)
				let transpiledSwiftAST = try Utilities.readFile(swiftASTFilePath)

				// Get Swift results
				let arguments: MutableList =
					["-skip-AST-dumps",
					 "-emit-swiftAST",
					 "--indentation=t",
					 "-avoid-unicode",
					 "--write-to-console",
					 testCasePath, ]
				if testName.hasSuffix("--default-final") {
					arguments.append("--default-final")
				}
				let driverResult = try Driver.run(withArguments: arguments)
				guard let resultArray = driverResult as? List<Any?>,
					let swiftASTs = resultArray.as(List<SwiftAST>.self),
					let originalSwiftAST = swiftASTs.first else
				{
					XCTFail("Error generating SwiftASTs.\n" +
						"Driver result: \(driverResult ?? "nil")")
					return
				}

				// Compare results
				XCTAssert(
					transpiledSwiftAST == originalSwiftAST.description,
					"Test \(testName): failed to produce expected result. " +
						"Printing diff ('<' means generated, '>' means expected):" +
						TestUtilities.diff(transpiledSwiftAST, originalSwiftAST.description))
			}
			catch let error {
				XCTFail("🚨 Test failed with error:\n\(error)")
			}
		}

		XCTAssertFalse(Compiler.hasIssues())
		Compiler.printErrorsAndWarnings()
	}

	func testSwiftTranslatorOutput() {
		guard !BootstrappingTest.hasError else {
			XCTFail("Error during setup")
			return
		}

		let tests = TestUtilities.testCases

		for testName in tests {
			print("- Testing \(testName)...")

			do {
				let testCasePath = TestUtilities.testCasesPath + testName + ".swift"

				// Get Kotlin results
				let rawASTFilePath = BootstrappingTest.getBootstrapOutputFilePath(
					forTest: testName,
					withExtension: .gryphonASTRaw)
				let transpiledRawAST = try Utilities.readFile(rawASTFilePath)

				// Get Swift results
				let arguments: MutableList =
					["-skip-AST-dumps",
					 "-emit-rawAST",
					 "--indentation=t",
					 "-avoid-unicode",
					 "--write-to-console",
					 testCasePath, ]
				if testName.hasSuffix("-default-final") {
					arguments.append("--default-final")
				}
				let driverResult = try Driver.run(withArguments: arguments)
				guard let resultArray = driverResult as? List<Any?>,
					let rawASTs = resultArray.as(List<GryphonAST>.self),
					let originalRawAST = rawASTs.first else
				{
					XCTFail("Error generating raw ASTs.\n" +
						"Driver result: \(driverResult ?? "nil")")
					return
				}

				// Compare results
				XCTAssert(
					transpiledRawAST == originalRawAST.description,
					"Test \(testName): failed to produce expected result. " +
						"Printing diff ('<' means generated, '>' means expected):" +
						TestUtilities.diff(transpiledRawAST, originalRawAST.description))
			}
			catch let error {
				XCTFail("🚨 Test failed with error:\n\(error)")
			}
		}

		XCTAssertFalse(Compiler.hasIssues())
		Compiler.printErrorsAndWarnings()
	}

	func testTranspilationPassOutput() {
		guard !BootstrappingTest.hasError else {
			XCTFail("Error during setup")
			return
		}

		let tests = TestUtilities.testCases

		for testName in tests {
			print("- Testing \(testName)...")

			do {
				let testCasePath = TestUtilities.testCasesPath + testName + ".swift"

				// Get Kotlin results
				let astFilePath = BootstrappingTest.getBootstrapOutputFilePath(
					forTest: testName,
					withExtension: .gryphonAST)
				let transpiledAST = try Utilities.readFile(astFilePath)

				// Get Swift results
				let arguments: MutableList =
					["-skip-AST-dumps",
					 "-emit-AST",
					 "--indentation=t",
					 "-avoid-unicode",
					 "--write-to-console",
					 testCasePath, ]
				if testName.hasSuffix("-default-final") {
					arguments.append("--default-final")
				}
				let driverResult = try Driver.run(withArguments: arguments)
				guard let resultArray = driverResult as? List<Any?>,
					let asts = resultArray.as(List<GryphonAST>.self),
					let originalAST = asts.first else
				{
					XCTFail("Error generating passed ASTs.\n" +
						"Driver result: \(driverResult ?? "nil")")
					return
				}

				// Compare results
				XCTAssert(
					transpiledAST == originalAST.description,
					"Test \(testName): failed to produce expected result. " +
						"Printing diff ('<' means generated, '>' means expected):" +
						TestUtilities.diff(transpiledAST, originalAST.description))
			}
			catch let error {
				XCTFail("🚨 Test failed with error:\n\(error)")
			}
		}

		XCTAssertFalse(Compiler.hasIssues())
		Compiler.printErrorsAndWarnings()
	}

	func testKotlinTranslatorOutput() {
		guard !BootstrappingTest.hasError else {
			XCTFail("Error during setup")
			return
		}

		let tests = TestUtilities.testCases

		for testName in tests {
			print("- Testing \(testName)...")

			do {
				let testCasePath = TestUtilities.testCasesPath + testName + ".swift"

				// Get Kotlin results
				let testOutputFilePath = BootstrappingTest.getBootstrapOutputFilePath(
					forTest: testName,
					withExtension: .kt)
				let transpiledKotlinCode = try Utilities.readFile(testOutputFilePath)

				// Get Swift results
				let arguments: MutableList =
					["-skip-AST-dumps",
					 "-emit-kotlin",
					 "--indentation=t",
					 "-avoid-unicode",
					 "--write-to-console",
					 testCasePath, ]
				if testName.hasSuffix("-default-final") {
					arguments.append("--default-final")
				}
				let driverResult = try Driver.run(withArguments: arguments)
				guard let resultArray = driverResult as? List<Any?>,
					let kotlinCodes = resultArray
						.as(List<Driver.KotlinTranslation>.self)?
						.map({ $0.kotlinCode }),
					let originalKotlinCode = kotlinCodes.first else
				{
					XCTFail("Error generating passed ASTs.\n" +
						"Driver result: \(driverResult ?? "nil")")
					return
				}

				// Compare results
				XCTAssert(
					transpiledKotlinCode == originalKotlinCode.description,
					"Test \(testName): failed to produce expected result. " +
						"Printing diff ('<' means generated, '>' means expected):" +
						TestUtilities.diff(transpiledKotlinCode, originalKotlinCode.description))
			}
			catch let error {
				XCTFail("🚨 Test failed with error:\n\(error)")
			}
		}

		XCTAssertFalse(Compiler.hasIssues())
		Compiler.printErrorsAndWarnings()
	}

	func testTestCasesWithOtherSwiftVersions() {
		guard !BootstrappingTest.hasError else {
			XCTFail("Error during setup")
			return
		}

		let tests = TestUtilities.testCases

		do {
			let defaultSwiftVersion = try TranspilationContext.getVersionOfToolchain(nil)

			for swiftVersion in TranspilationContext.supportedSwiftVersions {
				// The bootstrap test outputs were generated using the default Swift version, so we
				// test other versions against that.
				guard swiftVersion != defaultSwiftVersion else {
					continue
				}
				let toolchain = try TranspilationContext.getToolchain(forSwiftVersion: swiftVersion)

				print("⛓ Testing Swift \(swiftVersion) against Swift \(defaultSwiftVersion)")

				for testName in tests {
					print("- Testing \(testName)...")

					let testCasePath = TestUtilities.testCasesPath + testName + ".swift"

					// Get Kotlin results
					let testOutputFilePath = BootstrappingTest.getBootstrapOutputFilePath(
						forTest: testName,
						withExtension: .kt)
					let defaultSwiftVersionCode = try Utilities.readFile(testOutputFilePath)

					// Get Swift results
					let arguments: MutableList = [
						"java",
						"-jar",
						"Bootstrap/kotlin.jar",
						"--indentation=t",
						"-avoid-unicode",
						"-skip-AST-dumps",
						"-emit-kotlin",
						"--write-to-console",
						testCasePath,
					]
					if testName.hasSuffix("-default-final") {
						arguments.append("--default-final")
					}
					if let chosenToolchain = toolchain {
						arguments.append("--toolchain=\(chosenToolchain)")
					}
					let commandResult = Shell.runShellCommand(arguments)

					guard commandResult.status == 0 else {
						XCTFail("Failed to run bootstrapped transpiler for Swift \(swiftVersion)" +
							"in test \(testName).")
						continue
					}

					let testedSwiftVersionCode = commandResult.standardOutput

					// Compare results
					XCTAssert(
						(defaultSwiftVersionCode + "\n") == testedSwiftVersionCode,
						"Test \(testName): failed to produce expected result. " +
							"Printing diff ('<' means default Swift, '>' means test Swift):" +
							TestUtilities.diff(defaultSwiftVersionCode, testedSwiftVersionCode))
				}

				XCTAssertFalse(Compiler.hasIssues())
				Compiler.printErrorsAndWarnings()
			}
		}
		catch let error {
			XCTFail("🚨 Test failed with error:\n\(error)")
		}
	}

	static func getBootstrapOutputFilePath(
		forTest testName: String,
		withExtension fileExtension: FileExtension)
		-> String
	{
		return bootstrapOutputsFolder + "/" + testName + "." + fileExtension.rawValue
	}

	override static func setUp() {
		let swiftFiles = Utilities.getFiles(
			inDirectory: "Sources/GryphonLib", withExtension: .swift)

		let swiftASTFiles = Utilities.getFiles(
			inDirectory: bootstrapOutputsFolder, withExtension: .swiftAST)
		let rawASTFiles = Utilities.getFiles(
			inDirectory: bootstrapOutputsFolder, withExtension: .gryphonASTRaw)
		let astFiles = Utilities.getFiles(
			inDirectory: bootstrapOutputsFolder, withExtension: .gryphonAST)
		let kotlinFiles = Utilities.getFiles(
			inDirectory: bootstrapOutputsFolder, withExtension: .kt)

		if Utilities.files(swiftFiles, wereModifiedLaterThan: swiftASTFiles) ||
			Utilities.files(swiftFiles, wereModifiedLaterThan: rawASTFiles) ||
			Utilities.files(swiftFiles, wereModifiedLaterThan: astFiles) ||
			Utilities.files(swiftFiles, wereModifiedLaterThan: kotlinFiles)
		{
			print("🚨 Bootstrap test files are out of date. " +
				"Please run `prepareForBootstrapTests.sh`.")
			hasError = true
		}
	}

	static let bootstrapOutputsFolder = "Test cases/Bootstrap Outputs"

	static var hasError = false

	static var allTests = [
		("testUnitTests", testUnitTests),
		("testASTDumpDecoderOutput", testASTDumpDecoderOutput),
		("testSwiftTranslatorOutput", testSwiftTranslatorOutput),
		("testTranspilationPassOutput", testTranspilationPassOutput),
		("testKotlinTranslatorOutput", testKotlinTranslatorOutput),
		// testTestCasesWithOtherSwiftVersions omitted for linux
	]
}
