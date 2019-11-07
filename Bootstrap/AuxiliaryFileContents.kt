//
// Copyright 2018 Vinícius Jorge Vendramini
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
// TODO: Test `gryphon -init`
// TODO: Test multiline strings
val kotlinStringInterpolation: String = "{_string}"
val standardLibraryTemplateFileContents: String = "\t// WARNING: Any changes to this file should be reflected in the literal string in Driver.swift\n\n\timport Foundation\n\n\t// MARK: - Define special types as stand-ins for some protocols and other types\n\n\t// Replacement for Hashable\n\tstruct Hash: Hashable { }\n\n\t// Replacement for Comparable\n\tstruct Compare: Comparable {\n\t\tstatic func < (lhs: Compare, rhs: Compare) -> Bool {\n\t\t\treturn false\n\t\t}\n\t}\n\n\t// Replacement for Optional\n\tstruct MyOptional { }\n\n\t// Replacement for Any\n\tstruct AnyType: CustomStringConvertible, LosslessStringConvertible {\n\t\tinit() { }\n\n\t\tvar description: String = \"\"\n\n\t\tinit?(_ description: String) {\n\t\t\treturn nil\n\t\t}\n\t}\n\n\t// MARK: - Define the templates\n\tfunc gryphonTemplates() {\n\n\t\t// MARK: Declare placeholder variables to use in the templates\n\t\tvar _strArray: [String] = []\n\t\tvar _array: [Any] = []\n\t\tvar _array1: [Any] = []\n\t\tvar _array2: [Any] = []\n\t\tvar _arrayOfOptionals: [Any?] = []\n\t\tvar _comparableArray : [Compare] = []\n\t\tlet _compare = Compare()\n\t\tvar _index: String.Index = \"abc\".endIndex\n\t\tlet _index1: String.Index = \"abc\".startIndex\n\t\tlet _index2: String.Index = \"abc\".startIndex\n\t\tvar _string: String = \"abc\"\n\t\tvar _string1: String = \"abc\"\n\t\tlet _string2: String = \"abc\"\n\t\tlet _string3: String = \"abc\"\n\t\tlet _character: Character = \"a\"\n\t\tlet _substring: Substring = \"abc\".dropLast()\n\t\tlet _range: Range<String.Index> = _string.startIndex..<_string.endIndex\n\t\tlet _any: Any = \"abc\"\n\t\tlet _anyType: AnyType = AnyType()\n\t\tlet _optional: MyOptional? = MyOptional()\n\t\tlet _double: Double = 0\n\t\tlet _double1: Double = 0\n\t\tlet _double2: Double = 0\n\t\tlet _int: Int = 0\n\t\tlet _int1: Int = 0\n\t\tlet _int2: Int = 0\n\t\tlet _dictionary: [Hash: Any] = [:]\n\t\tlet _closure: (Any, Any) -> Any = { a, b in a }\n\t\tlet _closure2: (Any) -> Any = { a in a }\n\t\tlet _closure3: (Any) -> Bool = { _ in true }\n\t\tlet _closure4: (MyOptional) -> Any = { _ in true }\n\t\tlet _closure5: (Character) -> Bool = { _ in true }\n\t\tlet _closure6: (Any) -> Any? = { a in a }\n\t\tlet _closure7: (Compare, Compare) -> Bool = { _, _ in true }\n\n\t\t// MARK: Declare the templates\n\n\t\t// System\n\t\t_ = print(_any)\n\t\t_ = \"println(_any)\"\n\n\t\t_ = print(_any, terminator: \"\")\n\t\t_ = \"print(_any)\"\n\n\t\t_ = fatalError(_string)\n\t\t_ = \"println(\\\"Fatal error: $${kotlinStringInterpolation}\\\"); exitProcess(-1)\"\n\n\t\t// Darwin\n\t\t_ = sqrt(_double)\n\t\t_ = \"Math.sqrt(_double)\"\n\n\t\t// String\n\t\t_ = String(_anyType)\n\t\t_ = \"_anyType.toString()\"\n\n\t\t_ = _anyType.description\n\t\t_ = \"_anyType.toString()\"\n\n\t\t_ = _string.isEmpty\n\t\t_ = \"_string.isEmpty()\"\n\n\t\t_ = _string.count\n\t\t_ = \"_string.length\"\n\n\t\t_ = _string.first\n\t\t_ = \"_string.firstOrNull()\"\n\n\t\t_ = _string.last\n\t\t_ = \"_string.lastOrNull()\"\n\n\t\t_ = Double(_string)\n\t\t_ = \"_string.toDouble()\"\n\n\t\t_ = Float(_string)\n\t\t_ = \"_string.toFloat()\"\n\n\t\t_ = UInt64(_string)\n\t\t_ = \"_string.toULong()\"\n\n\t\t_ = Int64(_string)\n\t\t_ = \"_string.toLong()\"\n\n\t\t_ = Int(_string)\n\t\t_ = \"_string.toIntOrNull()\"\n\n\t\t_ = _string.dropLast()\n\t\t_ = \"_string.dropLast(1)\"\n\n\t\t_ = _string.dropLast(_int)\n\t\t_ = \"_string.dropLast(_int)\"\n\n\t\t_ = _string.dropFirst()\n\t\t_ = \"_string.drop(1)\"\n\n\t\t_ = _string.dropFirst(_int)\n\t\t_ = \"_string.drop(_int)\"\n\n\t\t_ = _string.indices\n\t\t_ = \"_string.indices\"\n\n\t\t_ = _string.firstIndex(of: _character)!\n\t\t_ = \"_string.indexOf(_character)\"\n\n\t\t_ = _string.contains(where: _closure5)\n\t\t_ = \"(_string.find _closure5 != null)\"\n\n\t\t_ = _string.index(of: _character)\n\t\t_ = \"_string.indexOrNull(_character)\"\n\n\t\t_ = _string.prefix(_int)\n\t\t_ = \"_string.substring(0, _int)\"\n\n\t\t_ = _string.prefix(upTo: _index)\n\t\t_ = \"_string.substring(0, _index)\"\n\n\t\t_ = _string[_index...]\n\t\t_ = \"_string.substring(_index)\"\n\n\t\t_ = _string[..._index]\n\t\t_ = \"_string.substring(0, _index)\"\n\n\t\t_ = _string[_index1..<_index2]\n\t\t_ = \"_string.substring(_index1, _index2)\"\n\n\t\t_ = _string[_index1..._index2]\n\t\t_ = \"_string.substring(_index1, _index2 + 1)\"\n\n\t\t_ = String(_substring)\n\t\t_ = \"_substring\"\n\n\t\t_ = _string.endIndex\n\t\t_ = \"_string.length\"\n\n\t\t_ = _string.startIndex\n\t\t_ = \"0\"\n\n\t\t_ = _string.formIndex(before: &_index)\n\t\t_ = \"_index -= 1\"\n\n\t\t_ = _string.index(after: _index)\n\t\t_ = \"_index + 1\"\n\n\t\t_ = _string.index(before: _index)\n\t\t_ = \"_index - 1\"\n\n\t\t_ = _string.index(_index, offsetBy: _int)\n\t\t_ = \"_index + _int\"\n\n\t\t_ = _substring.index(_index, offsetBy: _int)\n\t\t_ = \"_index + _int\"\n\n\t\t_ = _string1.replacingOccurrences(of: _string2, with: _string3)\n\t\t_ = \"_string1.replace(_string2, _string3)\"\n\n\t\t_ = _string1.prefix(while: _closure5)\n\t\t_ = \"_string1.takeWhile _closure5\"\n\n\t\t_ = _string1.hasPrefix(_string2)\n\t\t_ = \"_string1.startsWith(_string2)\"\n\n\t\t_ = _string1.hasSuffix(_string2)\n\t\t_ = \"_string1.endsWith(_string2)\"\n\n\t\t_ = _range.lowerBound\n\t\t_ = \"_range.start\"\n\n\t\t_ = _range.upperBound\n\t\t_ = \"_range.endInclusive\"\n\n\t\t_ = Range<String.Index>(uncheckedBounds: (lower: _index1, upper: _index2))\n\t\t_ = \"IntRange(_index1, _index2)\"\n\n\t\t_ = _string1.append(_string2)\n\t\t_ = \"_string1 += _string2\"\n\n\t\t_ = _string.append(_character)\n\t\t_ = \"_string += _character\"\n\n\t\t_ = _string.capitalized\n\t\t_ = \"_string.capitalize()\"\n\n\t\t_ = _string.uppercased()\n\t\t_ = \"_string.toUpperCase()\"\n\n\t\t// Character\n\t\t_ = _character.uppercased()\n\t\t_ = \"_character.toUpperCase()\"\n\n\t\t// Array\n\t\t_ = _array.append(_any)\n\t\t_ = \"_array.add(_any)\"\n\n\t\t_ = _array.insert(_any, at: _int)\n\t\t_ = \"_array.add(_int, _any)\"\n\n\t\t_ = _arrayOfOptionals.append(nil)\n\t\t_ = \"_arrayOfOptionals.add(null)\"\n\n\t\t_ = _array1.append(contentsOf: _array2)\n\t\t_ = \"_array1.addAll(_array2)\"\n\n\t\t_ = _array.isEmpty\n\t\t_ = \"_array.isEmpty()\"\n\n\t\t_ = _strArray.joined(separator: _string)\n\t\t_ = \"_strArray.joinToString(separator = _string)\"\n\n\t\t_ = _strArray.joined()\n\t\t_ = \"_strArray.joinToString(separator = \\\"\\\")\"\n\n\t\t_ = _array.count\n\t\t_ = \"_array.size\"\n\n\t\t_ = _array.indices\n\t\t_ = \"_array.indices\"\n\n\t\t_ = _array.first\n\t\t_ = \"_array.firstOrNull()\"\n\n\t\t_ = _array.first(where: _closure3)\n\t\t_ = \"_array.find _closure3\"\n\n\t\t_ = _array.last(where: _closure3)\n\t\t_ = \"_array.findLast _closure3\"\n\n\t\t_ = _array.last\n\t\t_ = \"_array.lastOrNull()\"\n\n\t\t_ = _array.removeFirst()\n\t\t_ = \"_array.removeAt(0)\"\n\n\t\t_ = _array.removeLast()\n\t\t_ = \"_array.removeLast()\"\n\n\t\t_ = _array.dropFirst()\n\t\t_ = \"_array.drop(1)\"\n\n\t\t_ = _array.dropLast()\n\t\t_ = \"_array.dropLast(1)\"\n\n\t\t_ = _array.map(_closure2)\n\t\t_ = \"_array.map _closure2.toMutableList()\"\n\n\t\t_ = _array.flatMap(_closure6)\n\t\t_ = \"_array.flatMap _closure6.toMutableList()\"\n\n\t\t_ = _array.compactMap(_closure2)\n\t\t_ = \"_array.map _closure2.filterNotNull().toMutableList()\"\n\n\t\t_ = _array.filter(_closure3)\n\t\t_ = \"_array.filter _closure3.toMutableList()\"\n\n\t\t_ = _array.reduce(_any, _closure)\n\t\t_ = \"_array.fold(_any) _closure\"\n\n\t\t_ = zip(_array1, _array2)\n\t\t_ = \"_array1.zip(_array2)\"\n\n\t\t_ = _array.indices\n\t\t_ = \"_array.indices\"\n\n\t\t_ = _array.index(where: _closure3)\n\t\t_ = \"_array.indexOfFirst _closure3\"\n\n\t\t_ = _array.contains(where: _closure3)\n\t\t_ = \"(_array.find _closure3 != null)\"\n\n\t\t_ = _comparableArray.sorted()\n\t\t_ = \"_comparableArray.sorted()\"\n\n\t\t_ = _comparableArray.sorted(by: _closure7)\n\t\t_ = \"_comparableArray.sorted(isAscending = _closure7)\"\n\n\t\t_ = _comparableArray.contains(_compare)\n\t\t_ = \"_comparableArray.contains(_compare)\"\n\n\t\t_ = _comparableArray.index(of: _compare)\n\t\t_ = \"_comparableArray.indexOf(_compare)\"\n\n\t\t_ = _comparableArray.firstIndex(of: _compare)\n\t\t_ = \"_comparableArray.indexOf(_compare)\"\n\n\t\t// Dictionary\n\t\t_ = _dictionary.reduce(_any, _closure)\n\t\t_ = \"_dictionary.entries.fold(initial = _any, operation = _closure)\"\n\n\t\t_ = _dictionary.map(_closure2)\n\t\t_ = \"_dictionary.map _closure2.toMutableList()\"\n\n\t\t// TODO: Translate mapValues (Kotlin's takes (Key, Value) as an argument)\n\n\t\t// Int\n\t\t_ = Int.max\n\t\t_ = \"Int.MAX_VALUE\"\n\n\t\t_ = Int.min\n\t\t_ = \"Int.MIN_VALUE\"\n\n\t\t_ = min(_int1, _int2)\n\t\t_ = \"Math.min(_int1, _int2)\"\n\n\t\t_ = _int1..._int2\n\t\t_ = \"_int1.._int2\"\n\n\t\t_ = _int1..<_int2\n\t\t_ = \"_int1 until _int2\"\n\n\t\t// Double\n\t\t_ = _double1..._double2\n\t\t_ = \"(_double1).rangeTo(_double2)\"\n\n\t\t// Optional\n\t\t_ = _optional.map(_closure4)\n\t\t_ = \"_optional?.let _closure4\"\n\t}\n"

// WARNING: Any changes to this file should be reflected in the literal string in Driver.swift
// MARK: - Define special types as stand-ins for some protocols and other types
// Replacement for Hashable
// Replacement for Comparable
// Replacement for Optional
// Replacement for Any
// MARK: - Define the templates
// MARK: Declare placeholder variables to use in the templates
// MARK: Declare the templates
// System
// Darwin
// String
// Character
// Array
// Dictionary
// TODO: Translate mapValues (Kotlin's takes (Key, Value) as an argument)
// Int
// Double
// Optional
val errorMapScriptFileContents: String = """
import Foundation

func getAbsoultePath(forFile file: String) -> String {
	return \"/\" + URL(fileURLWithPath: file).pathComponents.dropFirst().joined(separator: \"/\")
}

struct ErrorInformation {
	let filePath: String
	let lineNumber: Int
	let columnNumber: Int
	let errorMessage: String
}

func getInformation(fromString string: String) -> ErrorInformation {
	let components = string.split(separator: \":\")
	return ErrorInformation(
		filePath: String(components[0]),
		lineNumber: Int(components[1])!,
		columnNumber: Int(components[2])!,
		errorMessage: String(components[3...].joined(separator: \":\")))
}

struct SourceFileRange {
	let lineStart: Int
	let columnStart: Int
	let lineEnd: Int
	let columnEnd: Int
}

struct Mapping {
	let kotlinRange: SourceFileRange
	let swiftRange: SourceFileRange
}

struct ErrorMap {
	let kotlinFilePath: String
	let swiftFilePath: String
	let mappings: [Mapping]

	init(kotlinFilePath: String, contents: String) {
		self.kotlinFilePath = kotlinFilePath

		let components = contents.split(separator: \"
\")
		self.swiftFilePath = String(components[0])

		self.mappings = components.dropFirst().map { string in
			let mappingComponents = string.split(separator: \":\")
			let kotlinRange = SourceFileRange(
				lineStart: Int(mappingComponents[0])!,
				columnStart: Int(mappingComponents[1])!,
				lineEnd: Int(mappingComponents[2])!,
				columnEnd: Int(mappingComponents[3])!)
			let swiftRange = SourceFileRange(
				lineStart: Int(mappingComponents[4])!,
				columnStart: Int(mappingComponents[5])!,
				lineEnd: Int(mappingComponents[6])!,
				columnEnd: Int(mappingComponents[7])!)
			return Mapping(kotlinRange: kotlinRange, swiftRange: swiftRange)
		}
	}

	func getSwiftRange(forKotlinLine line: Int, column: Int) -> SourceFileRange? {
		for mapping in mappings {
			if mapping.kotlinRange.lineStart <= line,
				mapping.kotlinRange.lineEnd >= line,
				mapping.kotlinRange.columnStart <= column,
				mapping.kotlinRange.columnEnd <= column
			{
				return mapping.swiftRange
			}
		}

		return nil
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////
var input: [String] = []

// Read all the input, separated into lines
while let nextLine = readLine(strippingNewline: false) {
	input.append(nextLine)
}

// Join the lines into errors/warnings
var errors: [String] = []
var currentError = \"\"
for line in input {
	if line.contains(\": error: \") || line.contains(\": warning: \") {
		if !currentError.isEmpty {
			errors.append(currentError)
		}
		currentError = line
	}
	else {
		currentError += line
	}
}
if !currentError.isEmpty {
	errors.append(currentError)
}

// Handle the errors
var errorMaps: [String: ErrorMap] = [:]
for error in errors {
	let errorInformation = getInformation(fromString: error)
	let errorMapPath =
		\".gryphon/KotlinErrorMaps/\" + errorInformation.filePath.dropLast(2) + \"kotlinErrorMap\"

	if errorMaps[errorMapPath] == nil {
		if let fileContents = try? String(contentsOfFile: errorMapPath) {
			errorMaps[errorMapPath] = ErrorMap(
				kotlinFilePath: errorInformation.filePath,
				contents: fileContents)
		}
		else {
			print(error)
			continue
		}
	}

	let errorMap = errorMaps[errorMapPath]!

	if let swiftRange = errorMap.getSwiftRange(
		forKotlinLine: errorInformation.lineNumber,
		column: errorInformation.columnNumber)
	{
		print(\"\\(getAbsoultePath(forFile: errorMap.swiftFilePath)):\\(swiftRange.lineStart):\" +
			\"\\(swiftRange.columnStart):\\(errorInformation.errorMessage)\")
	}
	else {
		print(error)
	}
}

//main.kt:2:5: error: conflicting declarations: var result: String, var result: String
//var result: String = \"\"
//    ^
//main.kt:3:5: error: conflicting declarations: var result: String, var result: String
//var result = result
//    ^"""

////////////////////////////////////////////////////////////////////////////////////////////////////
// Read all the input, separated into lines
// Join the lines into errors/warnings
// Handle the errors
//main.kt:2:5: error: conflicting declarations: var result: String, var result: String
//var result: String = ""
//    ^
//main.kt:3:5: error: conflicting declarations: var result: String, var result: String
//var result = result
//    ^
