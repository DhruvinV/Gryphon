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
typealias PrintContents = Any?

internal fun printTest(contents: PrintContents, testName: String) {
	val contentsString: String = "${contents}"

	print(contentsString)

	for (_0 in contentsString.length until 20) {
		print(" ")
	}

	println("(${testName})")
}

fun f(a: Int) {
	println(a)
}

fun main(args: Array<String>) {
	val string: String = "abcde"
	val bIndex: Int = 1
	val cIndex: Int = 2
	val dIndex: Int = 3
	var variableIndex: Int = cIndex
	val substring: String = "abcd"
	val range: IntRange = IntRange(0, string.length)
	var variableString: String = "abcde"
	val character: Char = 'i'

	print(0)
	println("                   (Print)")

	printTest(Math.sqrt(9.0), "Sqrt")
	printTest(0.toString(), "String(_anyType)")
	printTest("bla".toString(), "String description")
	printTest("".isEmpty(), "String isEmpty")
	printTest("a".isEmpty(), "String isEmpty")
	printTest("".length, "String count")
	printTest("a".length, "String count")
	printTest("abc".firstOrNull()!!, "String first")
	printTest("".firstOrNull(), "String first")
	printTest("abc".lastOrNull()!!, "String last")
	printTest("".lastOrNull(), "String last")
	printTest("0".toDouble(), "String double")
	printTest("1".toDouble(), "String double")
	printTest("0".toFloat(), "String float")
	printTest("1".toFloat(), "String float")
	printTest("0".toULong(), "String uint64")
	printTest("1".toULong(), "String uint64")
	printTest("0".toLong(), "String int64")
	printTest("1".toLong(), "String int64")
	printTest("0".toIntOrNull(), "String int")
	printTest("1".toIntOrNull(), "String int")
	printTest("abcde".dropLast(1), "String dropLast()")
	printTest("abcde".dropLast(2), "String dorpLast(int)")
	printTest("abcde".drop(1), "String dropFirst")
	printTest("abcde".drop(2), "String dropFirst(int)")

	for (index in string.indices) {
		printTest(string[index], "String indices")
	}

	printTest("abcde".substring(0, 4), "String prefix")
	printTest("abcde".substring(0, cIndex), "String prefix(upTo:)")
	printTest("abcde".substring(cIndex), "String index...")
	printTest("abcde".substring(0, cIndex), "String ..<index")
	printTest("abcde".substring(0, cIndex + 1), "String ...index")
	printTest("abcde".substring(bIndex, dIndex), "String index..<index")
	printTest("abcde".substring(bIndex, dIndex + 1), "String index...index")
	printTest(substring, "String String(substring)")
	printTest(string.substring(0, string.length), "String endIndex")
	printTest(string[0], "String startIndex")

	variableIndex -= 1

	printTest(string[variableIndex], "String formIndex(brefore:)")
	printTest(string[cIndex + 1], "String index after")
	printTest(string[cIndex - 1], "String index before")
	printTest(string[cIndex + 2], "String index offset by")
	printTest(substring[bIndex + 1], "String substring index offset by")
	printTest("aaBaBAa".replace("a", "A"), "String replacing occurrences")
	printTest(string.takeWhile { it != 'c' }, "String prefix while")
	printTest(string.startsWith("abc"), "String hasPrefix")
	printTest(string.startsWith("d"), "String hasPrefix")
	printTest(string.endsWith("cde"), "String hasSuffix")
	printTest(string.endsWith("a"), "String hasSuffix")
	printTest(range.start == 0, "String range lowerBound")
	printTest(range.start == string.length, "String range lowerBound")
	printTest(range.endInclusive == 0, "String range upperBound")
	printTest(range.endInclusive == string.length, "String range upperBound")

	val newRange: IntRange = IntRange(0, string.length)

	printTest(newRange.start == 0, "String range uncheckedBounds")
	printTest(newRange.start == string.length, "String range uncheckedBounds")
	printTest(newRange.endInclusive == 0, "String range uncheckedBounds")
	printTest(newRange.endInclusive == string.length, "String range uncheckedBounds")

	variableString += "fgh"

	printTest(variableString, "String append")

	variableString += character

	printTest(variableString, "String append character")
	printTest(string.capitalize(), "String capitalized")
	printTest(string.toUpperCase(), "String uppercased")

	var array: MutableList<Int> = mutableListOf(1, 2, 3)

	println(array)
	array.add(4)
	println(array)

	val emptyArray: MutableList<Int> = mutableListOf()

	println(emptyArray.isEmpty())
	println(array.isEmpty())

	val stringArray: MutableList<String> = mutableListOf("1", "2", "3")

	println(stringArray.joinToString(separator = " => "))
	println(array.size)
	println(stringArray.size)
	println(array.lastOrNull())
	println(array.dropLast(1))
	println(Int.MAX_VALUE)
	println(Int.MIN_VALUE)
	println(Math.min(0, 1))
	println(Math.min(15, -30))
	println(0..3)
	println(-1 until 3)
	println((1.0).rangeTo(3.0))
	println(Int.MIN_VALUE until 0)
	f(a = 10)
}
