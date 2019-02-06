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

public func GRYAnnotations<T>(_: String, _ t: T) -> T { return t }

public func GRYInsert(_: String) { }

private func GRYDeclarations() {
	// TODO: Whitespaces here aren't being processed correctly in the kotlin translation
	GRYInsert("""
fun <T> MutableList<T>.copy(): MutableList<T> {
	return this.toMutableList()
}
""")
}

public class GRYPrintableTree: GRYPrintableAsTree {
	public var treeDescription: String = GRYAnnotations("override", "")
	public var printableSubtrees: ArrayReference<GRYPrintableAsTree?> =
		GRYAnnotations("override", [])

	init(description: String) {
		self.treeDescription = description
	}

	init(description: String, subtrees: ArrayReference<GRYPrintableAsTree?>) {
		self.treeDescription = description
		self.printableSubtrees = subtrees
	}

	static func initialize(description: String, subtreesOrNil: ArrayReference<GRYPrintableAsTree?>)
		-> GRYPrintableTree?
	{
		let subtrees: ArrayReference<GRYPrintableAsTree?> = []
		for subtree in subtreesOrNil {
			if let unwrapped = subtree {
				subtrees.append(unwrapped)
			}
		}

		guard !subtrees.isEmpty else {
			return nil
		}

		return GRYPrintableTree(description: description, subtrees: subtrees)
	}

	func addChild(_ child: GRYPrintableAsTree?) {
		printableSubtrees.append(child)
	}
}

public protocol GRYPrintableAsTree {
	var treeDescription: String { get }
	var printableSubtrees: ArrayReference<GRYPrintableAsTree?> { get }
}

public extension GRYPrintableAsTree {
	func prettyPrint(
		indentation: ArrayReference<String> = [],
		isLast: Bool = true,
		horizontalLimit: Int = Int.max,
		printFunction: (String) -> () = { print($0, terminator: "") })
	{
		// Print the indentation
		let indentationString = indentation.joined(separator: "")

		let rawLine = "\(indentationString) \(treeDescription)"
		let line: String
		if rawLine.count > horizontalLimit {
			line = rawLine.prefix(horizontalLimit - 1) + "…"
		}
		else {
			line = rawLine
		}

		printFunction(line + "\n")

		// Correct the indentation for this level
		if !indentation.isEmpty {
			// If I'm the last branch, don't print a line in my level anymore.
			if isLast {
				indentation[indentation.count - 1] = "   "
			}
			// If there are more branches after me, keep printing the line
			// so my siblings can be correctly printed later.
			else {
				indentation[indentation.count - 1] = " │ "
			}
		}

		let subtrees: ArrayReference<GRYPrintableAsTree> = []
		for element in printableSubtrees {
			if let unwrapped = element {
				subtrees.append(unwrapped)
			}
		}

		for subtree in subtrees.dropLast() {
			let newIndentation = indentation.copy()
			newIndentation.append(" ├─")
			subtree.prettyPrint(
				indentation: newIndentation,
				isLast: false,
				horizontalLimit: horizontalLimit,
				printFunction: printFunction)
		}
		let newIndentation = indentation.copy()
		newIndentation.append(" └─")
		subtrees.last?.prettyPrint(
			indentation: newIndentation,
			isLast: true,
			horizontalLimit: horizontalLimit,
			printFunction: printFunction)
	}
}
