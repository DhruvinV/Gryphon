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

public final class SwiftAST: PrintableAsTree, Equatable, CustomStringConvertible {
	let name: String
	let standaloneAttributes: ArrayReference<String>
	let keyValueAttributes: [String: String]
	let subtrees: ArrayReference<SwiftAST>

	//
	static public var horizontalLimitWhenPrinting = Int.max

	//
	internal init(_ name: String, _ subtrees: ArrayReference<SwiftAST> = []) {
		self.name = name
		self.standaloneAttributes = []
		self.keyValueAttributes = [:]
		self.subtrees = subtrees
	}

	internal init( // kotlin: ignore
		_ name: String,
		_ standaloneAttributes: ArrayReference<String>,
		_ keyValueAttributes: [String: String],
		_ subtrees: ArrayReference<SwiftAST> = [])
	{
		self.name = name
		self.standaloneAttributes = standaloneAttributes
		self.keyValueAttributes = keyValueAttributes
		self.subtrees = subtrees
	}

	// MARK: - Convenience accessors
	subscript (key: String) -> String? { // kotlin: ignore
		return keyValueAttributes[key]
	}

	func subtree(named name: String) -> SwiftAST? { // kotlin: ignore
		return subtrees.first { $0.name == name }
	}

	func subtree(at index: Int) -> SwiftAST? { // kotlin: ignore
		guard index >= 0, index < subtrees.count else {
			return nil
		}
		return subtrees[index]
	}

	func subtree(at index: Int, named name: String) -> SwiftAST? { // kotlin: ignore
		guard index >= 0, index < subtrees.count else {
			return nil
		}

		let subtree = subtrees[index]
		guard subtree.name == name else {
			return nil
		}

		return subtree
	}

	// MARK: - PrintableAsTree
	public var treeDescription: String { // annotation: override
		return name
	}

	public var printableSubtrees: ArrayReference<PrintableAsTree?> { // annotation: override
		let keyValueStrings = keyValueAttributes
			.map { "\($0.key) → \($0.value)" }.sorted().map { PrintableTree($0) }
		let keyValueArray = ArrayReference<PrintableAsTree?>(array: keyValueStrings)
		let standaloneAttributesArray =
			ArrayReference<PrintableAsTree?>(standaloneAttributes.map { PrintableTree($0) })
		let subtreesArray = ArrayReference<PrintableAsTree?>(subtrees)

		let result = standaloneAttributesArray + keyValueArray + subtreesArray // kotlin: ignore
		// insert: val result = (standaloneAttributesArray + keyValueArray + subtreesArray)
		// insert: 	.toMutableList()

		return result
	}

	// MARK: - Descriptions
	public var description: String { // kotlin: ignore
		var result = ""
		self.prettyPrint { result += $0 }
		return result
	}

	public func description(withHorizontalLimit horizontalLimit: Int) -> String { // kotlin: ignore
		var result = ""
		self.prettyPrint(horizontalLimit: horizontalLimit) { result += $0 }
		return result
	}

	// MARK: - Equatable
	public static func == (lhs: SwiftAST, rhs: SwiftAST) -> Bool { // kotlin: ignore
		return lhs.name == rhs.name &&
			lhs.standaloneAttributes == rhs.standaloneAttributes &&
			lhs.keyValueAttributes == rhs.keyValueAttributes &&
			lhs.subtrees == rhs.subtrees
	}
}
