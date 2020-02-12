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

// gryphon output: Test cases/Bootstrap Outputs/standardLibrary.swiftAST
// gryphon output: Test cases/Bootstrap Outputs/standardLibrary.gryphonASTRaw
// gryphon output: Test cases/Bootstrap Outputs/standardLibrary.gryphonAST
// gryphon output: Test cases/Bootstrap Outputs/standardLibrary.kt

import Foundation

typealias PrintContents = Any // kotlin: ignore
// declaration: typealias PrintContents = Any?

func printTest(_ contents: PrintContents, _ testName: String) {
	let firstColumnSize = 40

	let contentsString = "\(contents)"
	print(contentsString, terminator: "")
	if contentsString.count < firstColumnSize {
		for _ in contentsString.count..<firstColumnSize {
			print(" ", terminator: "")
		}
	}
	print("(\(testName))")
}

// Print
print("Hello, world!")
print(42)

let message = "A message in a variable."
print(message)

let number = 13
print(number)

print("Here's a bool literal: \(true).\nAnd here's a number: \(17).")
print("The stored message is: \(message)\nAnd the stored number is: \(number).")

print(0, terminator: "")
print(" (Print)")

// Darwin
printTest(sqrt(9), "Sqrt")

// String
let string = "abcde"
let bIndex = string.index(string.startIndex, offsetBy: 1) // value: 1
let cIndex = string.index(string.startIndex, offsetBy: 2) // value: 2
let dIndex = string.index(string.startIndex, offsetBy: 3) // value: 3
var variableIndex = cIndex
let substring = "abcde".dropLast() // value: "abcd"
let range = string.startIndex..<string.endIndex // value: IntRange(0, string.length)
var variableString = "abcde"
let character: Character = "i"

printTest(String(0), "String(_anyType)")

printTest("bla".description, "String description")

printTest("".isEmpty, "String isEmpty")
printTest("a".isEmpty, "String isEmpty")

printTest("".count, "String count")
printTest("a".count, "String count")

printTest("abc".first!, "String first")
printTest("".first, "String first")

printTest("abc".last!, "String last")
printTest("".last, "String last")

printTest(Double("0"), "String double")
printTest(Double("1"), "String double")

printTest(Float("0"), "String float")
printTest(Float("1"), "String float")

printTest(UInt64("0"), "String uint64")
printTest(UInt64("1"), "String uint64")

printTest(Int64("0"), "String int64")
printTest(Int64("1"), "String int64")

printTest(Int("0"), "String int")
printTest(Int("1"), "String int")

printTest("abcde".dropLast(), "String dropLast()")

printTest("abcde".dropLast(2), "String dorpLast(int)")

printTest("abcde".dropFirst(), "String dropFirst")

printTest("abcde".dropFirst(2), "String dropFirst(int)")

for index in string.indices {
	printTest(string[index], "String indices")
}

printTest("abcde".prefix(4), "String prefix")

printTest("abcde".prefix(upTo: cIndex), "String prefix(upTo:)")

printTest("abcde"[cIndex...], "String index...")

printTest("abcde"[..<cIndex], "String ..<index")

printTest("abcde"[...cIndex], "String ...index")

printTest("abcde"[bIndex..<dIndex], "String index..<index")

printTest("abcde"[bIndex...dIndex], "String index...index")

printTest(String(substring), "String String(substring)")

printTest(string.prefix(upTo: string.endIndex), "String endIndex")

printTest(string[string.startIndex], "String startIndex")

string.formIndex(before: &variableIndex)
printTest(string[variableIndex], "String formIndex(brefore:)")

printTest(string[string.index(after: cIndex)], "String index after")

printTest(string[string.index(before: cIndex)], "String index before")

printTest(string[string.index(cIndex, offsetBy: 2)], "String index offset by")

printTest(substring[substring.index(bIndex, offsetBy: 1)], "String substring index offset by")

printTest("aaBaBAa".replacingOccurrences(of: "a", with: "A"), "String replacing occurrences")

printTest(string.prefix(while: { $0 != "c" }), "String prefix while")

printTest(string.hasPrefix("abc"), "String hasPrefix")
printTest(string.hasPrefix("d"), "String hasPrefix")

printTest(string.hasSuffix("cde"), "String hasSuffix")
printTest(string.hasSuffix("a"), "String hasSuffix")

printTest(range.lowerBound == string.startIndex, "String range lowerBound")
printTest(range.lowerBound == string.endIndex, "String range lowerBound")

printTest(range.upperBound == string.startIndex, "String range upperBound")
printTest(range.upperBound == string.endIndex, "String range upperBound")

let newRange =
	Range<String.Index>(uncheckedBounds:
		(lower: string.startIndex,
		 upper: string.endIndex))
printTest(newRange.lowerBound == string.startIndex, "String range uncheckedBounds")
printTest(newRange.lowerBound == string.endIndex, "String range uncheckedBounds")
printTest(newRange.upperBound == string.startIndex, "String range uncheckedBounds")
printTest(newRange.upperBound == string.endIndex, "String range uncheckedBounds")

variableString.append("fgh")
printTest(variableString, "String append")

variableString.append(character)
printTest(variableString, "String append character")

printTest(string.capitalized, "String capitalized")

printTest(string.uppercased(), "String uppercased")

// Character
printTest(character.uppercased(), "Character uppercased")

// Array
var array = [1, 2, 3] // kotlin: ignore
let array2 = [2, 1]
var array3 = [1] // kotlin: ignore
let array4 = [2, 1]
var arrayOfOptionals: [Int?] = [1] // kotlin: ignore
let emptyArray: [Int] = []
let stringArray = ["1", "2", "3"]
// insert: val array: MutableList<Int> = mutableListOf(1, 2, 3)
// insert: val array3: MutableList<Int> = mutableListOf(1)
// insert: val arrayOfOptionals: MutableList<Int?> = mutableListOf(1)

printTest(array, "Array append")
array.append(4)
printTest(array, "Array append")

array.insert(0, at: 0)
printTest(array, "Array insert")
array.insert(5, at: 5)
printTest(array, "Array insert")
array.insert(10, at: 3)
printTest(array, "Array insert")

arrayOfOptionals.append(nil)
printTest(arrayOfOptionals, "Array append nil")

array3.append(contentsOf: array2)
printTest(array3, "Array append(contentsOf:) constant")

array3.append(contentsOf: array4)
printTest(array3, "Array append(contentsOf:) variable")

printTest(emptyArray.isEmpty, "Array isEmpty")
printTest(array.isEmpty, "Array isEmpty")

printTest(stringArray.joined(separator: " => "), "Array joined separator")

printTest(stringArray.joined(), "Array joined")

printTest(array.count, "Array count")
printTest(stringArray.count, "Array count")

for index in array.indices {
	printTest(array[index], "Array indices")
}

printTest(array[array.startIndex], "Array startIndex")

printTest(array.endIndex == array.count, "Array endIndex")

printTest(array.index(after: 2), "Array index after")

printTest(array.index(before: 2), "Array index before")

printTest(array.first, "Array first")
printTest(emptyArray.first, "Array first")

printTest(array.first(where: { $0 > 3 }), "Array first where")

printTest(array.last(where: { $0 > 3 }), "Array last where")

printTest(array.last, "Array last")

array.removeFirst()
printTest(array, "Array remove first")

printTest(array.dropFirst(), "Array drop first")

printTest(array.dropLast(), "Array drop last")

printTest(array.map { $0 + 1 }, "Array map")

printTest(array.flatMap { [$0 + 1, $0 + 2] }, "Array flat map")

printTest(array.compactMap { $0 == 10 ? $0 : nil }, "Array compact map")

printTest(array.filter { $0 < 10 }, "Array filter")

printTest(array.reduce(1) { acc, el in acc * el }, "Array reduce")

for (element1, element2) in zip(array, array2) {
	printTest(element1, "Array zip")
	printTest(element2, "Array zip")
}

printTest(array.firstIndex(where: { $0 > 2 }), "Array firstIndex")

printTest(array.contains(where: { $0 > 2 }), "Array contains where")
printTest(array.contains(where: { $0 > 2000 }), "Array contains where")

printTest(array.sorted(), "Array sorted")

printTest(array.contains(10), "Array contains")
printTest(array.contains(10000), "Array contains")

printTest(array.firstIndex(of: 10), "Array firstIndex of")

// Dictionaries
let dictionary = [1: 1, 2: 2]
let emptyDictionary: [Int: Int] = [:]

printTest(dictionary.count, "Dictionary count")

printTest(dictionary.isEmpty, "Dictionary isEmpty")
printTest(emptyDictionary.isEmpty, "Dictionary isEmpty")

let mappedDictionary = dictionary.map { $0.value + $0.key }
printTest(mappedDictionary[0], "Dictionary map")
printTest(mappedDictionary[1], "Dictionary map")

// Int
printTest(Int.max, "Int max")

printTest(Int.min, "Int min")

printTest(min(0, 1), "Int min(a, b)")
printTest(min(15, -30), "Int min(a, b)")

printTest(0...3, "Int ...")

printTest(-1..<3, "Int ..<")

// Double
printTest(1.0...3.0, "Double ...")

//
// Recursive matches
printTest(Int.min..<0, "Recursive matches")

//
// User-defined templates
func f(of a: Int) { // kotlin: ignore
	printTest(a, "User template")
}

// declaration: fun g(a: Int) {
// declaration: 	printTest(a, "User template")
// declaration: }

f(of: 10)

func gryphonTemplates() {
	var _int = 0

	f(of: _int)
	"g(a = _int)"
}
