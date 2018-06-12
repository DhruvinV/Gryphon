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

class GRYPrintableAsTreeTest: XCTestCase {
	func testPrinting() {
		let root = GRYPrintableTree(description: "root")
		let a = GRYPrintableTree(description: "a")
		let b = GRYPrintableTree(description: "b")
		let c = GRYPrintableTree(description: "c")
		let d = GRYPrintableTree(description: "d")

		root.addChild(a)
		a.addChild(b)
		b.addChild(c)
		root.addChild(d)

		var result = ""
		root.prettyPrint {
			result += $0
		}
		XCTAssertEqual(result, """
			 root
			 ├─ a
			 │  └─ b
			 │     └─ c
			 └─ d\n
			""")
	}

	func testStrings() {
		let root = GRYPrintableTree(description: "root")
		let a = GRYPrintableTree(description: "a")
		let b = GRYPrintableTree(description: "b")

		root.addChild(a)
		a.addChild(b)
		b.addChild("c")
		root.addChild("d")

		var result = ""
		root.prettyPrint {
			result += $0
		}
		XCTAssertEqual(result, """
			 root
			 ├─ a
			 │  └─ b
			 │     └─ c
			 └─ d\n
			""")
	}

	func testArrays() {
		let root = GRYPrintableTree(description: "root")
		let a = GRYPrintableTree(description: "a")

		root.addChild(a)
		root.addChild("d")
		a.addChild(["b", "c"])

		var result = ""
		root.prettyPrint {
			result += $0
		}
		XCTAssertEqual(result, """
			 root
			 ├─ a
			 │  └─ Array
			 │     ├─ b
			 │     └─ c
			 └─ d\n
			""")
	}

	func testHorizontalLimit() {
		let root = GRYPrintableTree(description: "root")
		let a = GRYPrintableTree(description: "aaaaaaaaaaaaaaaaaa")
		let b = GRYPrintableTree(description: "bbbbbbbbbbbbbbbbbb")
		let c = GRYPrintableTree(description: "cccccccccccccccccc")
		let d = GRYPrintableTree(description: "dddddddddddddddddd")

		root.addChild(a)
		a.addChild(b)
		b.addChild(c)
		root.addChild(d)

		var result = ""
		root.prettyPrint(horizontalLimit: 15) {
			result += $0
		}
		XCTAssertEqual(result, """
			 root
			 ├─ aaaaaaaaaa…
			 │  └─ bbbbbbb…
			 │     └─ cccc…
			 └─ dddddddddd…\n
			""")
	}

	static var allTests = [
		("testPrinting", testPrinting),
		("testStrings", testStrings),
		("testArrays", testArrays),
		("testHorizontalLimit", testHorizontalLimit),
	]
}
