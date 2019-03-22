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

@testable import GryphonLib
import XCTest

class SwiftTranslatorTest: XCTestCase {
	func testTranslator() {
		let tests = TestUtils.testCasesForAllTests

		for testName in tests {
			print("- Testing \(testName)...")

			do {
				// Load a cached Gryphon AST from file
				let testFilePath = TestUtils.testFilesPath + testName
				let expectedGryphonRawAST = try GryphonAST(decodeFromFile: testFilePath + .gryRawAST)

				// Create a new Gryphon AST from the cached Swift AST using the SwiftTranslator
				let swiftAST = try SwiftAST(decodeFromFile: testFilePath + .grySwiftAST)
				let createdGryphonRawAST = try SwiftTranslator().translateAST(swiftAST)

				// Compare the two
				XCTAssert(
					createdGryphonRawAST == expectedGryphonRawAST,
					"Test \(testName): translator failed to produce expected result. Diff:" +
						TestUtils.diff(
							createdGryphonRawAST.description, expectedGryphonRawAST.description))

				print("\t- Done!")
			}
			catch let error {
				XCTFail("🚨 Test failed with error:\n\(error)")
			}
		}

		XCTAssertFalse(Compiler.hasErrorsOrWarnings())
		Compiler.printErrorsAndWarnings()
	}

	static var allTests = [
		("testTranslator", testTranslator),
	]

	override static func setUp() {
		do {
			try Utilities.updateTestFiles()
		}
		catch let error {
			print(error)
			fatalError("Failed to update test files.")
		}
	}

	override func setUp() {
		Compiler.clearErrorsAndWarnings()
	}
}
