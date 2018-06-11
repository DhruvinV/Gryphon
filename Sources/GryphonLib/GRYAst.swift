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

import Foundation

public class GRYAst: GRYPrintableAsTree, Equatable, Codable, CustomStringConvertible {
	let name: String
	let standaloneAttributes: [String]
	let keyValueAttributes: [String: String]
	let subTrees: [GRYAst]

	static public var horizontalLimitWhenPrinting = Int.max

	public convenience init(astFile astFilePath: String) {
		do {
			let rawAstDump = try String(contentsOfFile: astFilePath)

			// Information in stored files has placeholders for file paths that must be replaced
			let swiftFilePath = GRYUtils.changeExtension(of: astFilePath, to: "swift")
			let processedAstDump = rawAstDump.replacingOccurrences(of: "<<testFilePath>>", with: swiftFilePath)

			let parser = GRYSExpressionParser(sExpression: processedAstDump)
			self.init(parser: parser)
		}
		catch {
			fatalError("Error opening \(astFilePath). If the file doesn't exist, please use dump-ast.pl to generate it.")
		}
	}

	public static func initialize(fromJsonInFile jsonFilePath: String) -> GRYAst {
		do {
			let rawJSON = try String(contentsOfFile: jsonFilePath)

			// Information in stored files has placeholders for file paths that must be replaced
			let swiftFilePath = GRYUtils.changeExtension(of: jsonFilePath, to: "swift")
			let escapedFilePath = swiftFilePath.replacingOccurrences(of: "/", with: "\\/")
			let processedJSON = rawJSON.replacingOccurrences(of: "<<testFilePath>>", with: escapedFilePath)

			let astData = Data(processedJSON.utf8)
			return try JSONDecoder().decode(GRYAst.self, from: astData)
		}
		catch {
			fatalError("Error decoding \(jsonFilePath). If the file doesn't exist, please run `updateJsonTestFiles()` to generate it.")
		}
	}

	internal init(parser: GRYSExpressionParser, extraKeyValues: [String: String] = [:]) {
		var standaloneAttributes = [String]()
		var keyValueAttributes = [String: String]()
		var subTrees = [GRYAst]()

		parser.readOpenParentheses()
		let name = parser.readIdentifier()
		self.name = GRYUtils.expandSwiftAbbreviation(name)

		// The loop stops: all branches tell the parser to read, and the input string must end eventually.
		while true {
			// Add subtree
			if parser.canReadOpenParentheses() {

				// Check if there's info to pass on to subtrees
				let extraKeyValuesForSubTrees: [String: String]
				if self.name == "Extension Declaration" {
					extraKeyValuesForSubTrees = ["extends_type": standaloneAttributes.first!]
				}
				else {
					extraKeyValuesForSubTrees = [:]
				}

				// Parse subtrees
				let subTree = GRYAst(parser: parser, extraKeyValues: extraKeyValuesForSubTrees)
				subTrees.append(subTree)
			}
			// Finish this branch
			else if parser.canReadCloseParentheses() {
				parser.readCloseParentheses()
				break
			}
			// Add key-value attributes
			else if let key = parser.readKey() {
				if key == "location" && parser.canReadLocation() {
					keyValueAttributes[key] = parser.readLocation()
				}
				else if (key == "decl" || key == "bind"),
					let string = parser.readDeclarationLocation()
				{
					keyValueAttributes[key] = string
				}
				else if key == "inherits" {
					let string = parser.readIdentifierList()
					keyValueAttributes[key] = string
				}
				else {
					keyValueAttributes[key] = parser.readStandaloneAttribute()
				}
			}
			// Add standalone attributes
			else {
				let attribute = parser.readStandaloneAttribute()
				standaloneAttributes.append(attribute)
			}
		}

		self.standaloneAttributes = standaloneAttributes
		self.keyValueAttributes = keyValueAttributes.merging(extraKeyValues, uniquingKeysWith: { a, _ in a })
		self.subTrees = subTrees
	}

	internal init(_ name: String, _ subTrees: [GRYAst] = []) {
		self.name = name
		self.standaloneAttributes = []
		self.keyValueAttributes = [:]
		self.subTrees = subTrees
	}

	internal init(
		_ name: String,
		_ standaloneAttributes: [String],
		_ keyValueAttributes: [String: String],
		_ subTrees: [GRYAst] = [])
	{
		self.name = name
		self.standaloneAttributes = standaloneAttributes
		self.keyValueAttributes = keyValueAttributes
		self.subTrees = subTrees
	}

	//
	subscript (key: String) -> String? {
		return keyValueAttributes[key]
	}

	func subTree(named name: String) -> GRYAst? {
		return subTrees.first { $0.name == name }
	}

	func subTree(at index: Int) -> GRYAst? {
		return subTrees[safe: index]
	}

	func subTree(at index: Int, named name: String) -> GRYAst? {
		guard let subTree = subTrees[safe: index],
			subTree.name == name else
		{
			return nil
		}
		return subTree
	}

	//
	public func writeAsJSON(toFile filePath: String) {
		log?("Building AST JSON...")
		let jsonData = try! JSONEncoder().encode(self)
		let rawJsonString = String(data: jsonData, encoding: .utf8)!

		// Absolute file paths must be replaced with placeholders before writing to file.
		let swiftFilePath = GRYUtils.changeExtension(of: filePath, to: "swift")
		let escapedFilePath = swiftFilePath.replacingOccurrences(of: "/", with: "\\/")
		let processedJsonString = rawJsonString.replacingOccurrences(of: escapedFilePath, with: "<<testFilePath>>")

		try! processedJsonString.write(toFile: filePath, atomically: true, encoding: .utf8)
	}

	//
	public var treeDescription: String {
		return name
	}

	public var printableSubTrees: [GRYPrintableAsTree] {
		let keyValueStrings = keyValueAttributes.map {
			return "\($0.key) → \($0.value)"
			}.sorted() as [GRYPrintableAsTree]

		let standaloneStrings = standaloneAttributes as [GRYPrintableAsTree]

		let result: [GRYPrintableAsTree] = standaloneStrings + keyValueStrings + subTrees
		return result
	}

	//
	public var description: String {
		var result = ""
		self.prettyPrint { result += $0 }
		return result
	}

	public func description(withHorizontalLimit horizontalLimit: Int) -> String {
		var result = ""
		self.prettyPrint(horizontalLimit: horizontalLimit) { result += $0 }
		return result
	}

	public static func == (lhs: GRYAst, rhs: GRYAst) -> Bool {
		return lhs.name == rhs.name &&
			lhs.standaloneAttributes == rhs.standaloneAttributes &&
			lhs.keyValueAttributes == rhs.keyValueAttributes &&
			lhs.subTrees == rhs.subTrees
	}
}
