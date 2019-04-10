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

class UtilitiesTest: XCTestCase {
	func testExpandSwiftAbbreviation() {
		XCTAssertEqual(
			Utilities.expandSwiftAbbreviation("source_file"), "Source File")
		XCTAssertEqual(
			Utilities.expandSwiftAbbreviation("import_decl"), "Import Declaration")
		XCTAssertEqual(
			Utilities.expandSwiftAbbreviation("declref_expr"), "Declaration Reference Expression")
	}

	func testFileExtension() {
		XCTAssertEqual(FileExtension.swiftASTDump.rawValue, "swiftASTDump")
		XCTAssertEqual("fileName".withExtension(.swiftASTDump), "fileName.swiftASTDump")
	}

	func testChangeExtension() {
		XCTAssertEqual(
			Utilities.changeExtension(of: "test.txt", to: .swift),
			"test.swift")
		XCTAssertEqual(
			Utilities.changeExtension(of: "/path/to/test.txt", to: .swift),
			"/path/to/test.swift")
		XCTAssertEqual(
			Utilities.changeExtension(of: "path/to/test.txt", to: .swift),
			"path/to/test.swift")
		XCTAssertEqual(
			Utilities.changeExtension(of: "/path/to/test", to: .swift),
			"/path/to/test.swift")
		XCTAssertEqual(
			Utilities.changeExtension(of: "path/to/test", to: .swift),
			"path/to/test.swift")
	}
}
