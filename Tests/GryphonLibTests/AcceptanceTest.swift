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

class AcceptanceTest: XCTestCase {
	func test() {
		let tests = TestUtils.testCasesForAcceptanceTest

		for testName in tests {
			print("- Testing \(testName)...")

			do {
				// Translate the swift code to kotlin, compile the resulting kotlin code, run it,
				// and get its output
				let testFilePath = TestUtils.testFilesPath + testName
				guard let compilationResult = try Compiler.transpileCompileAndRun(
					ASTDumpFiles: [testFilePath.withExtension(.swiftASTDump)]) else
				{
					XCTFail("Test \(testName) - compilation error. " +
						"It's possible a command timed out.")
					continue
				}

				// Load the previously stored kotlin code from file
				let expectedOutput =
					try! String(contentsOfFile: testFilePath.withExtension(.output))

				XCTAssert(
					compilationResult.standardError == "",
					"Test \(testName): the compiler encountered an error: " +
					"\(compilationResult.standardError).")
				XCTAssert(
					compilationResult.status == 0,
					"Test \(testName): the compiler exited with value " +
					"\(compilationResult.status).")
				XCTAssert(
					compilationResult.standardOutput == expectedOutput,
					"Test \(testName): program failed to produce expected result. Diff:" +
						TestUtils.diff(compilationResult.standardOutput, expectedOutput))

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
		("test", test),
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
