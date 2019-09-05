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

// declaration: import kotlin.system.*

public indirect enum GryphonType: CustomStringConvertible, CustomDebugStringConvertible, Equatable {
	case namedType(typeName: String)
	case optional(subType: GryphonType)
	case array(subType: GryphonType)
	case dictionary(key: GryphonType, value: GryphonType)
	case tuple(subTypes: ArrayClass<GryphonType>)
	case function(parameters: ArrayClass<GryphonType>, returnType: GryphonType)
	case generic(typeName: String, genericArguments: ArrayClass<GryphonType>)
	case dottedType(leftType: GryphonType, rightType: GryphonType)

	public var debugDescription: String { // kotlin: ignore
		return description
	}

	public var description: String { // annotation: override
		switch self {
		case let .namedType(typeName: typeName):
			return typeName
		case let .optional(subType: subType):
			switch subType {
			case .function:
				return "(\(subType))?"
			default:
				return "\(subType)?"
			}
		case let .array(subType: subType):
			return "[\(subType)]"
		case let .dictionary(key: key, value: value):
			return "[\(key): \(value)]"
		case let .tuple(subTypes: subTypes):
			let innerTypes = subTypes.map { $0.description }.joined(separator: ", ")
			return "(\(innerTypes))"
		case let .function(parameters: parameters, returnType: returnType):
			let parameterStrings = parameters.map { $0.description }.joined(separator: ", ")
			return "(\(parameterStrings)) -> \(returnType)"
		case let .generic(typeName: typeName, genericArguments: genericArguments):
			let genericStrings = genericArguments.map { $0.description }.joined(separator: ", ")
			return "\(typeName)<\(genericStrings)>"
		case let .dottedType(leftType: leftType, rightType: rightType):
			return "\(leftType).\(rightType)"
		}
	}

	static func create(fromString string: String) -> GryphonType {
		if let result = Parser(string: string).parse() {
			return result
		}
		else {
			let errorMessage = "Failed to parse type: \(string)"
			fatalError(errorMessage)
		}
	}

	private class Parser {
		let string: String
		var index: String.Index

		init(string: String) {
			self.string = string
			self.index = string.startIndex
		}

		func parse() -> GryphonType? {
			guard !string.isEmpty else {
				return nil
			}

			let result = parseType()
			cleanLeadingWhitespace()

			// If there's still something left to parse, then something went wrong.
			guard index == string.endIndex else {
				return nil
			}

			return result
		}

		func cleanLeadingWhitespace() {
			while index != string.endIndex, string[index] == " " {
				index = string.index(after: index)
			}
		}

		/// Parses the next type, starting at `index`. Leaves `index` in the position after the end
		/// of the parsed type if successful; returns `nil` otherwise.
		private func parseType() -> GryphonType? {
			guard let halfType = parseTypeAndPrefixes() else {
				return nil
			}

			var result = halfType

			// Check for suffixes of the type

			// Check for "?"s
			cleanLeadingWhitespace()
			while index != string.endIndex, string[index] == "?" {
				index = string.index(after: index)
				result = .optional(subType: result)
			}

			// Check for variadic types (i.e. the `Int...` in `(Int...) -> ()`)
			cleanLeadingWhitespace()
			if index != string.endIndex, string[index...].hasPrefix("...") {
				index = string.index(index, offsetBy: "...".count)
				result = .array(subType: result)
			}

			// Check for dotted types (i.e. `String.Index`)
			cleanLeadingWhitespace()
			if index != string.endIndex, string[index] == "." {
				index = string.index(after: index)

				guard let rightType = parseType() else {
					return nil
				}

				result = .dottedType(leftType: result, rightType: rightType)
			}

			return result
		}

		/// Parses a type ignoring possible "?"s at its end
		private func parseTypeAndPrefixes() -> GryphonType? {
			cleanLeadingWhitespace()

			// Two special cases: types with `inout` and `__owned` prefixes
			if string[index...].hasPrefix("inout ") {
				index = string.index(index, offsetBy: "inout ".count)
				return parseTypeAndPrefixes()
			}

			if string[index...].hasPrefix("__owned ") {
				index = string.index(index, offsetBy: "__owned ".count)
				return parseTypeAndPrefixes()
			}

			if string[index...].hasPrefix("@lvalue ") {
				index = string.index(index, offsetBy: "@lvalue ".count)
				return parseTypeAndPrefixes()
			}

			if string[index...].hasPrefix("@autoclosure ") {
				index = string.index(index, offsetBy: "@autoclosure ".count)
				return parseTypeAndPrefixes()
			}

			// Arrays, dictionarys and tuples/functions can start with brackets and parentheses, so
			// we can detect them earlier. Generics and optionals can only be detected later since
			// the "<...>" and "?" are postfix.

			// If it's an array or a dictionary
			if string[index] == "[" {
				index = string.index(after: index)

				guard let subType1 = parseType() else {
					return nil
				}

				// If it's an array
				if string[index] != ":" {
					guard string[index] == "]" else {
						return nil
					}

					index = string.index(after: index)
					return .array(subType: subType1)
				}
				else {
					// if it's a dictionary

					index = string.index(after: index)

					guard let subType2 = parseType() else {
						return nil
					}

					guard string[index] == "]" else {
						return nil
					}

					index = string.index(after: index)
					return .dictionary(key: subType1, value: subType2)
				}
			}

			// If it's a tuple
			if string[index] == "(" {
				index = string.index(after: index)

				// Check for labels before the tuple type, i.e. `(bla: Int, foo: String)` should be
				// parsed as `(Int, String)`

				let tupleElements: ArrayClass<GryphonType> = []

				while string[index] != ")" {
					// Skip the comma if necessary
					if string[index] == "," {
						index = string.index(after: index)
					}

					// Check for labels just as before
					let newSubType: GryphonType
					guard let firstAttempt = parseType() else {
						return nil
					}
					if string[index] == ":" {
						index = string.index(after: index)
						cleanLeadingWhitespace()
						guard let secondAttempt = parseType() else {
							return nil
						}
						newSubType = secondAttempt
					}
					else {
						newSubType = firstAttempt
					}

					tupleElements.append(newSubType)
				}

				guard string[index] == ")" else {
					return nil
				}
				index = string.index(after: index)
				cleanLeadingWhitespace()

				// Check if it's a standard tuple or if it's part of a function type.
				// Function types will have the "->" arrow after the tuple, possibly with a "throws"
				// annotation before the arrow (i.e. in `(String) throws -> ()`).
				if string[index...].hasPrefix("throws") {
					index = string.index(index, offsetBy: "throws".count)
					cleanLeadingWhitespace()
				}

				if string[index...].hasPrefix("->") {
					// If it's a function type, skip the "->" and any possible whitespace after it
					index = string.index(index, offsetBy: 2)
					cleanLeadingWhitespace()

					guard let returnType = parseType() else {
						return nil
					}

					return .function(parameters: tupleElements, returnType: returnType)
				}
				else {
					// If it's not a function, it either can be `Void` (a.k.a. `()`), or a simple
					// wrapping parameter (i.e. `((String) -> String)?`), or a normal tuple
					if tupleElements.isEmpty {
						return .namedType(typeName: "Void")
					}
					if tupleElements.count == 1 {
						return tupleElements[0]
					}
					else {
						return .tuple(subTypes: tupleElements)
					}
				}
			}

			// If it doesn't start with a special character, try to read it as a normal type
			var normalTypeEndIndex = index
			while normalTypeEndIndex != string.endIndex,
				(string[normalTypeEndIndex].isLetter ||
					string[normalTypeEndIndex].isNumber ||
					string[normalTypeEndIndex] == "_")
			{
				normalTypeEndIndex = string.index(after: normalTypeEndIndex)
			}

			// If it's empty, something went wrong
			guard normalTypeEndIndex != index else {
				return nil
			}

			let normalType = String(string[index..<normalTypeEndIndex])
			index = normalTypeEndIndex
			cleanLeadingWhitespace()

			// Check if it's a generic
			if index != string.endIndex, string[index] == "<" {
				// If it's a generic type

				index = string.index(after: index)

				guard let subType1 = parseType() else {
					return nil
				}

				let genericElements: ArrayClass<GryphonType> = [subType1]

				while string[index] == "," {
					index = string.index(after: index)

					guard let newSubType = parseType() else {
						return nil
					}

					genericElements.append(newSubType)
				}

				guard string[index] == ">" else {
					return nil
				}
				index = string.index(after: index)

				// Sometimes other types (arrays, dictionaries and optionals) can be written as
				// generics, i.e. `Array<Int>` or `Optional<String>`.
				if normalType == "Array", genericElements.count == 1 {
					return .array(subType: genericElements[0])
				}
				else if normalType == "Dictionary", genericElements.count == 2 {
					return .dictionary(key: genericElements[0], value: genericElements[1])
				}
				else if normalType == "Optional", genericElements.count == 1 {
					return .optional(subType: genericElements[0])
				}

				// Otherwise, it's just a normal generic type
				return .generic(typeName: normalType, genericArguments: genericElements)
			}

			// Otherwise, consider it a normal type
			return .namedType(typeName: normalType)
		}
	}

	func isSubtype(of superType: GryphonType) -> Bool {
		// Trivial case
		if self == superType {
			return true
		}

		// Special cases that are considered superTypes of anything (for simplicity in the standard
		// library translations)
		if case let .namedType(typeName: namedSuperType) = superType {
			if namedSuperType == "Any" ||
				namedSuperType == "AnyType" ||
				namedSuperType == "Hash" ||
				namedSuperType == "Compare" ||
				namedSuperType == "MyOptional"
			{
				return true
			}
		}
		if case let .optional(subType: optionalSuperType) = superType {
			if case let .namedType(typeName: namedSuperType) = optionalSuperType {
				if namedSuperType == "MyOptional" {
					if case .optional = self {
						return true
					}
					else {
						return false
					}
				}
			}
		}

		// Tuples are subtypes if their components are subtypes
		if case let .tuple(subTypes: selfSubTypes) = self,
			case let .tuple(subTypes: superSubTypes) = superType
		{
			guard selfSubTypes.count == superSubTypes.count else {
				return false
			}

			for (selfSubType, superSubType) in zipToClass(selfSubTypes, selfSubTypes) {
				guard selfSubType.isSubtype(of: superSubType) else {
					return false
				}
			}
		}

		// Try to simplify the types, if possible
		if let simpleSelf = simplifyType(self) {
			return simpleSelf.isSubtype(of: superType)
		}
		else if let simpleSuperType = simplifyType(superType) {
			return self.isSubtype(of: simpleSuperType)
		}

		// Handle optionals:
		// X? < Y? <=> X < Y
		// X < Y? <=> X < Y
		if case let .optional(subType: optionalSuperType) = superType {
			if case let .optional(subType: optionalSelf) = self {
				return optionalSelf.isSubtype(of: optionalSuperType)
			}
			else {
				return self.isSubtype(of: optionalSuperType)
			}
		}

		// Handle functions:
		// Functions are always considered a subType of one another. They have edge cases that are
		// difficult to handle correctly, and it's rare for them to appear so false positives should
		// also be rare.
		if case .function = superType {
			if case .function = self {
				return true
			}
			else {
				return false
			}
		}

		// Handle arrays
		if case let .array(subType: superElementType) = superType {
			if case let .array(subType: selfElementType) = self {
				return selfElementType.isSubtype(of: superElementType)
			}
			else {
				return false
			}
		}

		// Handle dictionaries
		if case let .dictionary(key: superKey, value: superValue) = superType {
			if case let .dictionary(key: selfKey, value: selfValue) = self {
				return selfKey.isSubtype(of: superKey) && selfValue.isSubtype(of: superValue)
			}
			else {
				return false
			}
		}

		// Handle generics
		if case let .generic(
			typeName: superTypeName,
			genericArguments: superTypeArguments) = superType
		{
			if case let .generic(
				typeName: selfTypeName,
				genericArguments: selfTypeArguments) = self
			{
				// Check if the named parts are the same
				let namedSuperType = GryphonType.namedType(typeName: superTypeName)
				let namedSelfType = GryphonType.namedType(typeName: selfTypeName)
				guard namedSelfType.isSubtype(of: namedSuperType) else {
					return false
				}

				// Check if the arguments are the same
				guard superTypeArguments.count == selfTypeArguments.count else {
					return false
				}

				for (selfTypeArgument, superTypeArgument) in
					zipToClass(selfTypeArguments, superTypeArguments)
				{
					guard selfTypeArgument.isSubtype(of: superTypeArgument) else {
						return false
					}
				}
			}
			else {
				return false
			}
		}

		return false
	}

	private func simplifyType(_ gryphonType: GryphonType) -> GryphonType? { // gryphon: pure
		// Deal with standard library types that can be handled as other types
		if case let .namedType(typeName: typeName) = gryphonType {
			if let result = Utilities.getTypeMapping(for: typeName)?.description {
				return .namedType(typeName: result)
			}
		}

		if case let .generic(typeName: typeName, genericArguments: genericArguments) = gryphonType {
			// Treat ArrayClass and ArraySlice as Array
			if typeName == "ArrayClass" || typeName == "ArraySlice" {
				// ArrayClass should have exactly one generic argument, which is its element
				return .array(subType: genericArguments[0])
			}

			// Treat Slice as Array
			if typeName == "Slice",
				genericArguments.count == 1,
				let genericArgument = genericArguments.first,
				case let .generic(
					typeName: innerTypeName,
					genericArguments: innerGenericArguments) = genericArgument
			{
				if innerTypeName == "ArrayClass" {
					// ArrayClass should have exactly one generic argument, which is its element
					return .array(subType: innerGenericArguments[0])
				}
			}

			// Treat DictionaryClass as Dictionary
			if typeName == "DictionaryClass" {
				// DictionaryClass should have exactly two generic argument: a key and a value
				return .dictionary(key: genericArguments[0], value: genericArguments[1])
			}
		}

		return nil
	}

}

extension GryphonType {
	func isNamedType(_ otherTypeName: String) -> Bool {
		switch self {
		case let .namedType(typeName: selftypeName):
			return selftypeName == otherTypeName
		default:
			return false
		}
	}

	func getTypeName() -> String? {
		switch self {
		case let .namedType(typeName: typeName):
			return typeName
		default:
			return nil
		}
	}

	func getOptionalSubType() -> GryphonType? {
		switch self {
		case let .optional(subType: subType):
			return subType
		default:
			return nil
		}
	}

	func getArrayElementType() -> GryphonType? {
		switch self {
		case let .array(subType: subType):
			return subType
		default:
			return nil
		}
	}

	func getDictionaryKeyType() -> GryphonType? {
		switch self {
		case let .dictionary(key: key, value: _):
			return key
		default:
			return nil
		}
	}

	func getDictionaryValueType() -> GryphonType? {
		switch self {
		case let .dictionary(key: _, value: value):
			return value
		default:
			return nil
		}
	}

	func getTupleSubTypes() -> ArrayClass<GryphonType>? {
		switch self {
		case let .tuple(subTypes: subTypes):
			return subTypes
		default:
			return nil
		}
	}

	func getFunctionParameterTypes() -> ArrayClass<GryphonType>? {
		switch self {
		case let .function(parameters: parameters, returnType: _):
			return parameters
		default:
			return nil
		}
	}

	func getFunctionReturnType() -> GryphonType? {
		switch self {
		case let .function(parameters: _, returnType: returnType):
			return returnType
		default:
			return nil
		}
	}

	func getGenericTypeName() -> String? {
		switch self {
		case let .generic(typeName: typeName, genericArguments: _):
			return typeName
		default:
			return nil
		}
	}

	func getGenericArguments() -> ArrayClass<GryphonType>? {
		switch self {
		case let .generic(typeName: _, genericArguments: genericArguments):
			return genericArguments
		default:
			return nil
		}
	}
}
