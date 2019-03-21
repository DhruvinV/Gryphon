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

public final class GRYAST: GRYPrintableAsTree, GRYCodable, Equatable, CustomStringConvertible {
	let declarations: [GRYStatement]
	let statements: [GRYStatement]

	init(declarations: [GRYStatement], statements: [GRYStatement]) {
		self.declarations = declarations
		self.statements = statements
	}

	//
	internal static func decode(from decoder: GRYDecoder) throws -> GRYAST {
		try decoder.readOpeningParenthesis()
		_ = decoder.readIdentifier()
		let declarations = try [GRYStatement].decode(from: decoder)
		let statements = try [GRYStatement].decode(from: decoder)
		try decoder.readClosingParenthesis()
		return GRYAST(declarations: declarations, statements: statements)
	}

	func encode(into encoder: GRYEncoder) throws {
		encoder.startNewObject(named: "GRYAST")
		try declarations.encode(into: encoder)
		try statements.encode(into: encoder)
		encoder.endObject()
	}

	//
	public static func == (lhs: GRYAST, rhs: GRYAST) -> Bool {
		return lhs.declarations == rhs.declarations &&
			lhs.statements == rhs.statements
	}

	//
	public var treeDescription: String { return "Source File" }

	public var printableSubtrees: ArrayReference<GRYPrintableAsTree?> {
		return [GRYPrintableTree("Declarations", declarations),
				GRYPrintableTree("Statements", statements), ]
	}

	//
	public var description: String {
		var result = ""
		prettyPrint { result += $0 }
		return result
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////

extension GRYStatement {
	public var name: String {
		if let name = Mirror(reflecting: self).children.first?.label {
			return name
		}
		else {
			return String(describing: self)
		}
	}

	//
	public var treeDescription: String {
		return name.capitalizedAsCamelCase
	}

	public var printableSubtrees: ArrayReference<GRYPrintableAsTree?> {
		switch self {
		case let .expression(expression: expression):
			return [expression]
		case let .extensionDeclaration(type: type, members: members):
			return [GRYPrintableTree(type), GRYPrintableTree.initOrNil("members", members), ]
		case let .importDeclaration(name: name):
			return [GRYPrintableTree(name)]
		case let .typealiasDeclaration(identifier: identifier, type: type, isImplicit: isImplicit):
			return [
				isImplicit ? GRYPrintableTree("implicit") : nil,
				GRYPrintableTree("identifier: \(identifier)"),
				GRYPrintableTree("type: \(type)"), ]
		case let .classDeclaration(name: name, inherits: inherits, members: members):
			return  [
				GRYPrintableTree(name),
				GRYPrintableTree("inherits", inherits),
				GRYPrintableTree("members", members), ]
		case let .companionObject(members: members):
			return ArrayReference<GRYPrintableAsTree?>(array: members)
		case let .enumDeclaration(
			access: access,
			name: name,
			inherits: inherits,
			elements: elements,
			members: members,
			isImplicit: isImplicit):

			let elementTrees = elements.map { (element: GRYASTEnumElement) -> GRYPrintableTree in
				let associatedValues = element.associatedValues
					.map { "\($0.label): \($0.type)" }
					.joined(separator: ", ")
				let associatedValuesString = (associatedValues.isEmpty) ? nil :
					"values: \(associatedValues)"
				return GRYPrintableTree(".\(element.name)", [
					GRYPrintableTree.initOrNil(associatedValuesString),
					GRYPrintableTree.initOrNil(element.annotations), ])
			}

			return [
				isImplicit ? GRYPrintableTree("implicit") : nil,
				GRYPrintableTree.initOrNil(access),
				GRYPrintableTree(name),
				GRYPrintableTree("inherits", inherits),
				GRYPrintableTree("elements", elementTrees),
				GRYPrintableTree("members", members), ]
		case let .protocolDeclaration(name: name, members: members):
			return [
				GRYPrintableTree(name),
				GRYPrintableTree.initOrNil("members", members), ]
		case let .structDeclaration(name: name, inherits: inherits, members: members):
			return [
				GRYPrintableTree(name),
				GRYPrintableTree("inherits", inherits),
				GRYPrintableTree("members", members), ]
		case let .functionDeclaration(value: functionDeclaration):
			return [
				functionDeclaration.extendsType.map { GRYPrintableTree("extends type \($0)") },
				functionDeclaration.isImplicit ? GRYPrintableTree("implicit") : nil,
				functionDeclaration.isStatic ? GRYPrintableTree("static") : nil,
				functionDeclaration.isMutating ? GRYPrintableTree("mutating") : nil,
				GRYPrintableTree.initOrNil(functionDeclaration.access),
				GRYPrintableTree("type: \(functionDeclaration.functionType)"),
				GRYPrintableTree("prefix: \(functionDeclaration.prefix)"),
				GRYPrintableTree("parameters", functionDeclaration.parameters),
				GRYPrintableTree("return type: \(functionDeclaration.returnType)"),
				GRYPrintableTree("statements", functionDeclaration.statements ?? []), ]
		case let .variableDeclaration(value: variableDeclaration):
			return [
				GRYPrintableTree.initOrNil(
					"extendsType", [GRYPrintableTree.initOrNil(variableDeclaration.extendsType)]),
				variableDeclaration.isImplicit ? GRYPrintableTree("implicit") : nil,
				variableDeclaration.isStatic ? GRYPrintableTree("static") : nil,
				variableDeclaration.isLet ? GRYPrintableTree("let") : GRYPrintableTree("var"),
				GRYPrintableTree(variableDeclaration.identifier),
				GRYPrintableTree(variableDeclaration.typeName),
				variableDeclaration.expression,
				GRYPrintableTree.initOrNil("getter", [variableDeclaration.getter]),
				GRYPrintableTree.initOrNil("setter", [variableDeclaration.setter]),
				GRYPrintableTree.initOrNil(
					"annotations", [GRYPrintableTree.initOrNil(variableDeclaration.annotations)]), ]
		case let .forEachStatement(
			collection: collection,
			variable: variable,
			statements: statements):
			return [
				GRYPrintableTree("variable", [variable]),
				GRYPrintableTree("collection", [collection]),
				GRYPrintableTree.initOrNil("statements", statements), ]
		case let .ifStatement(value: ifStatement):
			let declarationTrees =
				ifStatement.declarations.map { GRYStatement.variableDeclaration(value: $0) }
			let elseStatementTrees = ifStatement.elseStatement
				.map({ GRYStatement.ifStatement(value: $0) })?.printableSubtrees ?? []
			return [
				ifStatement.isGuard ? GRYPrintableTree("guard") : nil,
				GRYPrintableTree.initOrNil("declarations", declarationTrees),
				GRYPrintableTree.initOrNil("conditions", ifStatement.conditions),
				GRYPrintableTree.initOrNil("statements", ifStatement.statements),
				GRYPrintableTree.initOrNil("else", elseStatementTrees), ]
		case let .switchStatement(
			convertsToExpression: convertsToExpression, expression: expression,
			cases: cases):

			let caseItems = cases.map {
				GRYPrintableTree("case item", [
					GRYPrintableTree("expression", [$0.expression]),
					GRYPrintableTree("statements", $0.statements),
					])
			}

			return [
				GRYPrintableTree.initOrNil("converts to expression", [convertsToExpression]),
				GRYPrintableTree("expression", [expression]),
				GRYPrintableTree("case items", caseItems), ]
		case let .throwStatement(expression: expression):
			return [expression]
		case let .returnStatement(expression: expression):
			return [expression]
		case let .assignmentStatement(leftHand: leftHand, rightHand: rightHand):
			return [leftHand, rightHand]
		case .error:
			return []
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////

extension GRYExpression {
	public var type: String? {
		switch self {
		case .templateExpression:
			return nil
		case .literalCodeExpression, .literalDeclarationExpression:
			return nil
		case let .parenthesesExpression(expression: expression):
			return expression.type
		case let .forceValueExpression(expression: expression):
			let subtype = expression.type
			if let subtype = subtype, subtype.hasSuffix("?") {
				return String(subtype.dropLast())
			}
			else {
				return expression.type
			}
		case let .optionalExpression(expression: expression):
			return expression.type
		case let .declarationReferenceExpression(
			identifier: _, type: type, isStandardLibrary: _, isImplicit: _):

			return type
		case .typeExpression:
			return nil
		case let .subscriptExpression(subscriptedExpression: _, indexExpression: _, type: type):
			return type
		case let .arrayExpression(elements: _, type: type):
			return type
		case let .dictionaryExpression(keys: _, values: _, type: type):
			return type
		case let .dotExpression(leftExpression: _, rightExpression: rightExpression):
			return rightExpression.type
		case let .binaryOperatorExpression(
			leftExpression: _, rightExpression: _, operatorSymbol: _, type: type):

			return type
		case let .prefixUnaryExpression(expression: _, operatorSymbol: _, type: type):
			return type
		case let .postfixUnaryExpression(expression: _, operatorSymbol: _, type: type):
			return type
		case let .callExpression(function: _, parameters: _, type: type):
			return type
		case let .closureExpression(parameters: _, statements: _, type: type):
			return type
		case .literalIntExpression:
			return "Int"
		case .literalUIntExpression:
			return "UInt"
		case .literalDoubleExpression:
			return "Double"
		case .literalFloatExpression:
			return "Float"
		case .literalBoolExpression:
			return "Bool"
		case .literalStringExpression:
			return "String"
		case .nilLiteralExpression:
			return nil
		case .interpolatedStringLiteralExpression:
			return "String"
		case .tupleExpression:
			return nil
		case .tupleShuffleExpression:
			return nil
		case .error:
			return "<<Error>>"
		}
	}

	public var name: String {
		if let name = Mirror(reflecting: self).children.first?.label {
			return name
		}
		else {
			return String(describing: self)
		}
	}

	//
	public var treeDescription: String {
		return name
	}

	public var printableSubtrees: ArrayReference<GRYPrintableAsTree?> {
		switch self {
		case let .templateExpression(pattern: pattern, matches: matches):
			return [
				GRYPrintableTree("pattern \"\(pattern)\""),
				GRYPrintableTree("matches", [matches]), ]
		case .literalCodeExpression(string: let string),
			.literalDeclarationExpression(string: let string):

			return [GRYPrintableTree(string)]
		case let .parenthesesExpression(expression: expression):
			return [expression]
		case let .forceValueExpression(expression: expression):
			return [expression]
		case let .optionalExpression(expression: expression):
			return [expression]
		case let .declarationReferenceExpression(
			identifier: identifier, type: type, isStandardLibrary: isStandardLibrary,
			isImplicit: isImplicit):

			return [
				GRYPrintableTree(type),
				GRYPrintableTree(identifier),
				isStandardLibrary ? GRYPrintableTree("isStandardLibrary") : nil,
				isImplicit ? GRYPrintableTree("implicit") : nil, ]
		case let .typeExpression(type: type):
			return [GRYPrintableTree(type)]
		case let .subscriptExpression(
			subscriptedExpression: subscriptedExpression, indexExpression: indexExpression,
			type: type):

			return [
				GRYPrintableTree("type \(type)"),
				GRYPrintableTree("subscriptedExpression", [subscriptedExpression]),
				GRYPrintableTree("indexExpression", [indexExpression]), ]
		case let .arrayExpression(elements: elements, type: type):
			return [GRYPrintableTree("type \(type)"), GRYPrintableTree(elements)]
		case let .dictionaryExpression(keys: keys, values: values, type: type):
			let keyValueStrings = zip(keys, values).map { "\($0): \($1)" }
			return [
				GRYPrintableTree("type \(type)"),
				GRYPrintableTree("key value pairs", keyValueStrings), ]
		case let .dotExpression(leftExpression: leftExpression, rightExpression: rightExpression):
			return [
				GRYPrintableTree("left", [leftExpression]),
				GRYPrintableTree("right", [rightExpression]), ]
		case let .binaryOperatorExpression(
			leftExpression: leftExpression,
			rightExpression: rightExpression,
			operatorSymbol: operatorSymbol,
			type: type):

			return [
				GRYPrintableTree("type \(type)"),
				GRYPrintableTree("left", [leftExpression]),
				GRYPrintableTree("operator \(operatorSymbol)"),
				GRYPrintableTree("right", [rightExpression]), ]
		case let .prefixUnaryExpression(
			expression: expression, operatorSymbol: operatorSymbol, type: type):

			return [
				GRYPrintableTree("type \(type)"),
				GRYPrintableTree("operator \(operatorSymbol)"),
				GRYPrintableTree("expression", [expression]), ]
		case let .postfixUnaryExpression(
			expression: expression, operatorSymbol: operatorSymbol, type: type):

			return [
				GRYPrintableTree("type \(type)"),
				GRYPrintableTree("operator \(operatorSymbol)"),
				GRYPrintableTree("expression", [expression]), ]
		case let .callExpression(function: function, parameters: parameters, type: type):
			return [
				GRYPrintableTree("type \(type)"),
				GRYPrintableTree("function", [function]),
				GRYPrintableTree("parameters", [parameters]), ]
		case let .closureExpression(parameters: parameters, statements: statements, type: type):
			let parameters = "(" + parameters.map { $0.label + ":" }.joined(separator: ", ") + ")"
			return [
				GRYPrintableTree(type),
				GRYPrintableTree(parameters),
				GRYPrintableTree("statements", statements), ]
		case let .literalIntExpression(value: value):
			return [GRYPrintableTree(String(value))]
		case let .literalUIntExpression(value: value):
			return [GRYPrintableTree(String(value))]
		case let .literalDoubleExpression(value: value):
			return [GRYPrintableTree(String(value))]
		case let .literalFloatExpression(value: value):
			return [GRYPrintableTree(String(value))]
		case let .literalBoolExpression(value: value):
			return [GRYPrintableTree(String(value))]
		case let .literalStringExpression(value: value):
			return [GRYPrintableTree("\"\(value)\"")]
		case .nilLiteralExpression:
			return []
		case let .interpolatedStringLiteralExpression(expressions: expressions):
			return [GRYPrintableTree(expressions)]
		case let .tupleExpression(pairs: pairs):
			return ArrayReference<GRYPrintableAsTree?>(array: pairs.map {
				GRYPrintableTree(($0.label ?? "_") + ":", [$0.expression])
			})
		case let .tupleShuffleExpression(
			labels: labels, indices: indices, expressions: expressions):

			return [
				GRYPrintableTree("labels", labels),
				GRYPrintableTree("indices", indices.map { $0.description }),
				GRYPrintableTree("expressions", expressions), ]
		case .error:
			return []
		}
	}
}

public enum GRYTupleShuffleIndex: Equatable, CustomStringConvertible {
	case variadic(count: Int)
	case absent
	case present

	public var description: String {
		switch self {
		case let .variadic(count: count):
			return "variadics: \(count)"
		case .absent:
			return "absent"
		case .present:
			return "present"
		}
	}

	func encode(into encoder: GRYEncoder) throws {
		switch self {
		case let .variadic(count: count):
			try "variadic".encode(into: encoder)
			try count.encode(into: encoder)
		case .absent:
			try "absent".encode(into: encoder)
		case .present:
			try "present".encode(into: encoder)
		}
	}

	static func decode(from decoder: GRYDecoder) throws -> GRYTupleShuffleIndex {
		let caseName = try String.decode(from: decoder)
		switch caseName {
		case "variadic":
			let count = try Int.decode(from: decoder)
			return .variadic(count: count)
		case "absent":
			return .absent
		case "present":
			return .present
		default:
			throw GRYDecodingError.unexpectedContent(
				decoder: decoder, errorMessage: "Expected a GRYParameterIndex")
		}
	}
}

//
extension GRYASTFunctionParameter: GRYPrintableAsTree {
	public var treeDescription: String {
		return "parameter"
	}

	public var printableSubtrees: ArrayReference<GRYPrintableAsTree?> {
		return [
			self.apiLabel.map { GRYPrintableTree("api label: \($0)") },
			GRYPrintableTree("label: \(self.label)"),
			GRYPrintableTree("type: \(self.type)"),
			GRYPrintableTree.initOrNil("value", [self.value]),
		]
	}
}
