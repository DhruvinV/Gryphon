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

// output: Test cases/Bootstrap Outputs/extensions.swiftAST
// output: Test cases/Bootstrap Outputs/extensions.gryphonASTRaw
// output: Test cases/Bootstrap Outputs/extensions.gryphonAST
// output: Test cases/Bootstrap Outputs/extensions.kt

extension String {
	var isString: Bool {
		return true
	}
	
	var world: String {
		return "World!"
	}
}

extension String {
	func appendWorld() -> String {
		return self + ", world!"
	}

	func functionWithVariable() {
		var string = ", world!!"
		print("Hello\(string)")
	}
}

print("\("Hello!".isString)")
print("\("Hello!".world)")
print("\("Hello".appendWorld())")
"bla".functionWithVariable()
