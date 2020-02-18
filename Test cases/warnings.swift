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

// gryphon output: Test cases/Bootstrap Outputs/warnings.swiftAST
// gryphon output: Test cases/Bootstrap Outputs/warnings.gryphonASTRaw
// gryphon output: Test cases/Bootstrap Outputs/warnings.gryphonAST
// gryphon output: Test cases/Bootstrap Outputs/warnings.kt

// Test warnings for mutable value types
struct UnsupportedStruct {
	let immutableVariable = 0
	var mutableVariable = 0

	func pureFunction() { }
	mutating func mutatingFunction() { }

	var computedVarIsOK: Int {
		return 0
	}
}

enum UnsupportedEnum {
	case a(int: Int)

	mutating func mutatingFunction() { }

	var computedVarIsOK: Int {
		return 0
	}
}

// Test warnings for native declarations
let nativeArray: [Int] = []
let nativeDictionary: [Int: Int] = [:]

// Test warnings for nested fileprivate members
class MyClass {
	fileprivate var filePrivateVariable: Int = 0
}

// Test muting warnings
let noWarnings: [Int] = [] // gryphon mute
