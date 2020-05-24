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

// gryphon output: Test cases/Bootstrap Outputs/closures.swiftAST
// gryphon output: Test cases/Bootstrap Outputs/closures.gryphonASTRaw
// gryphon output: Test cases/Bootstrap Outputs/closures.gryphonAST
// gryphon output: Test cases/Bootstrap Outputs/closures.kt

let printClosure: (String) -> () = { print($0) }
printClosure("Hello, world!")

let plusClosure: (Int, Int) -> Int = { a, b in return a + b }
print(plusClosure(2, 3))

func useClosure(closure: (String) -> ()) {
	closure("Calling from function!")
}
useClosure(closure: printClosure)

func defaultClosure(closure: (String) -> () = { print($0) }) {
	closure("Calling from default closure!")
}
defaultClosure()

let multiLineClosure: (Int) -> () = { a in
	if a == 10 {
		print("It's ten!")
	}
	else {
		print("It's not ten.")
	}
}
multiLineClosure(10)
multiLineClosure(20)

//
// Test autoclosures
func f(_ closure: @autoclosure () -> (Int), a: Int) { }
f(0, a: 0)

// autoclosures + tupleShuffleExpressions
func g(_ closure: @autoclosure () -> (Int), a: Int = 0, c: Int) { }
g(0, c: 0)

//
// Test trailing closures
func f1(_ closure: () -> (Int)) { }
f1 { 0 }

func f2(a: Int, _ closure: () -> (Int)) { }
f2(a: 0) { 0 }

// trailing closures + tupleShuffleExpressions
func g1(_ closure: () -> (Int), a: Int = 0) { }
g1({ 0 })

func g2(a: Int = 0, _ closure: () -> (Int)) { }
g2 { 0 }

// Test closures with `throws` in their types
func f3(_ closure: () throws -> ()) { }
f3 { }

//
// Test closures with labeled returns

// Functions that are declaration references
func bar(_ closure: () -> Int) { }

bar {
	if true {
		return 1
	}
	else {
		return 0
	}
}

// Functions that are dot expressions
class A {
	func bar(_ closure: () -> Int) { }
}

A().bar {
	if true {
		return 1
	}
	else {
		return 0
	}
}

// Functions that are type expressions
struct B {
	let closure: () -> Int
}

B {
	if true {
		return 1
	}
	else {
		return 0
	}
}

// Chained functions
extension Int {
	func bar(_ closure: (Int) -> Int) -> Int {
		return closure(self)
	}
	func foo(_ closure: (Int) -> Int) -> Int {
		return closure(self)
	}
}

0.bar { (a: Int) -> Int in
	if true {
		return a + 1
	}
	return a + 1
}.foo { (b: Int) -> Int in
	if true {
		return b + 1
	}
	return b + 1
}

// Test single-expression closures with converted switch statements
func foo(_ closure:(Int) -> (Int)) { }

foo {
	switch $0 {
	case 0: return 0
	default: return 1
	}
}
