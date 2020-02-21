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
import java.util.*

fun myFunction(): String {
	return "Calling myFunction()" // \n \t \
}

internal fun f(a: Int = 0, b: Int = 1) {
	println(a + b)
}

internal interface A {
	val x: Int
	val y: Int
}

internal open class B: A {
	override open var x: Int = 1
	override open var y: Int = 3
	open var z: Int = 0
}

open internal interface C {
}

final internal enum class D {
	A;
}

final internal data class E(
	val a: Int = 0
)

internal fun insertFunction() {
	println("func 1")

	println("func 2")

	println("func 3")

	println("func 4")

	println("func 5")
}

internal open class InsertClass {
	open var a: String = "class a"

	open var b: String = "class b"

	open var c: String = "class c"

	open var d: String = "class d"

	open var e: String = "class e"

	open fun insertMethod() {
		println("method 1")

		println("method 2")

		println("method 3")

		println("method 4")

		println("method 5")
	}
}

fun myOtherFunction(): String {
	return "Calling myOtherFunction()" // \n \t \
}

fun main(args: Array<String>) {
	println("Inserting at the beginning of the file")

	val languageName: String = "kotlin"

	println("Hello from ${languageName}!")

	val magicNumber: Int = 40 + 5-3

	println(magicNumber)

	f(a = 0, b = 1)

	println("This will be ignored by swift, but not by kotlin.")

	println(myFunction())
	println(myOtherFunction())

	val squareRoot: Double = Math.sqrt(9.0)

	println(squareRoot)
	println(B().x)
	println(B().y)

	if (true) {
		println("if 1")

		println("if 2")

		println("if 3")

		println("if 4")

		println("if 5")
	}

	for (i in listOf(1)) {
		println("for 1")

		println("for 2")

		println("for 3")

		println("for 4")

		println("for 5")
	}

	insertFunction()

	val insertClass: InsertClass = InsertClass()

	println(insertClass.a)
	println(insertClass.b)
	println(insertClass.c)
	println(insertClass.d)
	println(insertClass.e)

	insertClass.insertMethod()

	println("Code at the end of file.")
}
