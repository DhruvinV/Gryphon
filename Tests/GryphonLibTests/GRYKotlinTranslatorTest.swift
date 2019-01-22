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

class GRYKotlinTranslatorTest: XCTestCase {
	func testTranslator() {
		let tests = TestUtils.allTestCases

		for testName in tests {

			do {
				print("- Testing \(testName)...")

				// Create the new Kotlin code from the cached Gryphon AST using the GRYKotlinTranslator
				let testFilePath = TestUtils.testFilesPath + testName
				let ast = GRYAst.initialize(fromSExpressionInFile: testFilePath + .gryAst)
				_ = GRYRecordEnumsTranspilationPass().run(on: ast)
				let createdKotlinCode = try GRYKotlinTranslator().translateAST(ast)

				// Load the cached Kotlin code from file
				let expectedKotlinCode = try! String(contentsOfFile: testFilePath + .kt)

				// Compare the two
				XCTAssert(
					createdKotlinCode == expectedKotlinCode,
					"Test \(testName): translator failed to produce expected result. Diff:" +
						TestUtils.diff(createdKotlinCode, expectedKotlinCode))

				print("\t- Done!")
			}
			catch let error {
				if let error = error as? GRYPrintableError {
					error.print()
					XCTFail()
					continue
				}
				else {
					print("Unexpected error: \(error)")
					fatalError()
				}
			}
		}
	}

	static var allTests = [
		("testTranslator", testTranslator),
	]

	static override func setUp() {
		try! GRYUtils.updateTestFiles()
	}
}
