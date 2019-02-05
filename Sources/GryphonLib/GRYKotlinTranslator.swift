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

public class GRYKotlinTranslator {
	enum GRYKotlinTranslatorError: Error, CustomStringConvertible {
		case unexpectedASTStructure(
			file: String,
			line: Int,
			function: String,
			message: String,
			AST: GRYTopLevelNode)

		var description: String {
			switch self {
			case let .unexpectedASTStructure(
				file: file, line: line, function: function, message: message, AST: ast):

				var nodeDescription = ""
				ast.prettyPrint(horizontalLimit: 100) {
					nodeDescription += $0
				}

				return "Error: failed to translate Gryphon AST into Kotlin.\n" +
						"On file \(file), line \(line), function \(function).\n" +
						message + ".\n" +
					"Thrown when translating the following AST node:\n\(nodeDescription)"

			}
		}
	}

	func unexpectedASTStructureError(
		file: String = #file, line: Int = #line, function: String = #function, _ message: String,
		AST ast: GRYTopLevelNode) -> GRYKotlinTranslatorError
	{
		return GRYKotlinTranslatorError.unexpectedASTStructure(
			file: file, line: line, function: function, message: message, AST: ast)
	}

	/// Used for the translation of Swift types into Kotlin types.
	static let typeMappings = ["Bool": "Boolean", "Error": "Exception"]

	private func translateType(_ type: String) -> String {
		let type = type.replacingOccurrences(of: "()", with: "Unit")

		if type.hasPrefix("[") {
			let innerType = String(type.dropLast().dropFirst())
			let translatedInnerType = translateType(innerType)
			return "MutableList<\(translatedInnerType)>"
		}
		else if type.hasPrefix("ArrayReference<") {
			let innerType = String(type.dropLast().dropFirst("ArrayReference<".count))
			let translatedInnerType = translateType(innerType)
			return "MutableList<\(translatedInnerType)>"
		}
		else {
			return GRYKotlinTranslator.typeMappings[type] ?? type
		}
	}

	/**
	This variable is used to store enum definitions in order to allow the translator
	to translate them as sealed classes (see the `translate(dotSyntaxCallExpression)` method).
	*/
	private static var enums = [String]()

	public static func addEnum(_ enumName: String) {
		enums.append(enumName)
	}

	// MARK: - Interface

	public func translateAST(_ sourceFile: GRYAST) throws -> String {
		let declarationsTranslation =
			try translate(subtrees: sourceFile.declarations, withIndentation: "")

		let indentation = increaseIndentation("")
		let statementsTranslation =
			try translate(subtrees: sourceFile.statements, withIndentation: indentation)

		var result = declarationsTranslation

		guard !statementsTranslation.isEmpty else {
			return result
		}

		// Add newline between declarations and the main function, if needed
		if !declarationsTranslation.isEmpty {
			result += "\n"
		}

		result += "fun main(args: Array<String>) {\n\(statementsTranslation)}\n"

		return result
	}

	// MARK: - Implementation

	private func translate(subtree: GRYTopLevelNode, withIndentation indentation: String) throws
		-> String
	{
		let result: String

		switch subtree {
		case .importDeclaration(name: _):
			result = ""
		case .extensionDeclaration(type: _, members: _):
			throw unexpectedASTStructureError(
				"Extension structure should have been removed in a transpilation pass",
				AST: subtree)
		case let .classDeclaration(name: name, inherits: inherits, members: members):
			result = try translateClassDeclaration(
				name: name, inherits: inherits, members: members, withIndentation: indentation)
		case let .companionObject(members: members):
			result = try translateCompanionObject(members: members, withIndentation: indentation)
		case let .enumDeclaration(
			access: access, name: name, inherits: inherits, elements: elements):

			result = translateEnumDeclaration(
				access: access, name: name, inherits: inherits, elements: elements,
				withIndentation: indentation)
		case let .forEachStatement(
			collection: collection, variable: variable, statements: statements):

			result = try translateForEachStatement(
				collection: collection, variable: variable, statements: statements,
				withIndentation: indentation)
		case let .functionDeclaration(
			prefix: prefix, parameterNames: parameterNames, parameterTypes: parameterTypes,
			defaultValues: defaultValues, returnType: returnType, isImplicit: isImplicit,
			isStatic: isStatic, extendsType: extendsType, statements: statements, access: access):

			result = try translateFunctionDeclaration(
				prefix: prefix, parameterNames: parameterNames, parameterTypes: parameterTypes,
				defaultValues: defaultValues, returnType: returnType, isImplicit: isImplicit,
				isStatic: isStatic, extendsType: extendsType, statements: statements,
				access: access, withIndentation: indentation)
		case let .protocolDeclaration(name: name, members: members):
			result = try translateProtocolDeclaration(
				name: name, members: members, withIndentation: indentation)
		case let .throwStatement(expression: expression):
			result = try translateThrowStatement(
				expression: expression, withIndentation: indentation)
		case .structDeclaration(name: _):
			return ""
		case let .variableDeclaration(
			identifier: identifier, typeName: typeName, expression: expression, getter: getter,
			setter: setter, isLet: isLet, extendsType: extendsType, annotations: annotations):

			result = try translateVariableDeclaration(
				identifier: identifier, typeName: typeName, expression: expression, getter: getter,
				setter: setter, isLet: isLet, extendsType: extendsType, annotations: annotations,
				withIndentation: indentation)
		case let .assignmentStatement(leftHand: leftHand, rightHand: rightHand):
			result = try translateAssignmentStatement(
				leftHand: leftHand, rightHand: rightHand, withIndentation: indentation)
		case let .ifStatement(
			conditions: conditions, declarations: declarations, statements: statements,
			elseStatement: elseStatement, isGuard: isGuard):

			result = try translateIfStatement(
				conditions: conditions, declarations: declarations, statements: statements,
				elseStatement: elseStatement, isGuard: isGuard, isElseIf: false,
				withIndentation: indentation)
		case let .returnStatement(expression: expression):
			result = try translateReturnStatement(
				expression: expression, withIndentation: indentation)
		case let .expression(expression: expression):
			let expressionTranslation = try translateExpression(expression)
			if !expressionTranslation.isEmpty {
				return indentation + expressionTranslation + "\n"
			}
			else {
				return ""
			}
		}

		return result
	}

	private func translate(subtrees: [GRYTopLevelNode], withIndentation indentation: String) throws
		-> String
	{
		return try subtrees.map
			{
				try translate(subtree: $0, withIndentation: indentation)
		}.reduce("", +)
	}

	private func translateEnumDeclaration(
		access: String?, name: String, inherits: [String], elements: [String],
		withIndentation indentation: String) -> String
	{
		var result: String

		if let access = access {
			result = "\(indentation)\(access) sealed class " + name
		}
		else {
			result = "\(indentation)sealed class " + name
		}

		if !inherits.isEmpty {
			var translatedInheritedTypes = inherits.map(translateType)
			translatedInheritedTypes[0] = translatedInheritedTypes[0] + "()"
			result += ": \(translatedInheritedTypes.joined(separator: ", "))"
		}

		result += " {\n"

		let increasedIndentation = increaseIndentation(indentation)

		for element in elements {
			let capitalizedElementName = element.capitalizedAsCamelCase

			result += "\(increasedIndentation)class \(capitalizedElementName): \(name)()\n"
		}

		result += "\(indentation)}\n"

		return result
	}

	private func translateProtocolDeclaration(
		name: String, members: [GRYTopLevelNode], withIndentation indentation: String) throws
		-> String
	{
		var result = "\(indentation)interface \(name) {\n"
		let contents = try translate(
			subtrees: members, withIndentation: increaseIndentation(indentation))
		result += contents
		result += "\(indentation)}\n"
		return result
	}

	private func translateClassDeclaration(
		name: String, inherits: [String], members: [GRYTopLevelNode],
		withIndentation indentation: String) throws -> String
	{
		var result = "\(indentation)class \(name)"

		if !inherits.isEmpty {
			let translatedInheritances = inherits.map(translateType)
			result += ": " + translatedInheritances.joined(separator: ", ")
		}

		result += " {\n"

		let increasedIndentation = increaseIndentation(indentation)

		let classContents = try translate(
			subtrees: members,
			withIndentation: increasedIndentation)

		result += classContents + "\(indentation)}\n"

		return result
	}

	private func translateCompanionObject(
		members: [GRYTopLevelNode], withIndentation indentation: String) throws -> String
	{
		var result = "\(indentation)companion object {\n"

		let increasedIndentation = increaseIndentation(indentation)

		let contents = try translate(
			subtrees: members,
			withIndentation: increasedIndentation)

		result += contents + "\(indentation)}\n"

		return result
	}

	private func translateFunctionDeclaration(
		prefix: String, parameterNames: [String], parameterTypes: [String],
		defaultValues: [GRYExpression?], returnType: String, isImplicit: Bool, isStatic: Bool,
		extendsType: String?, statements: [GRYTopLevelNode]?, access: String?,
		withIndentation indentation: String) throws -> String
	{
		guard !isImplicit else {
			return ""
		}

		var indentation = indentation
		var result = indentation

		let isInit = (prefix == "init")
		if isInit {
			result += "constructor("
		}
		else {
			if let access = access {
				result += access + " "
			}
			result += "fun "
			if let extensionType = extendsType {
				result += extensionType + "."
			}
			result += prefix + "("
		}

		let translatedParameterTypes = parameterTypes.map(translateType)
		let valueStrings = try defaultValues.map { (defaultValue: GRYExpression?) -> String in
			if let defaultValue = defaultValue {
				return try " = " + translateExpression(defaultValue)
			}
			else {
				return ""
			}
		}
		let parameters = zip(parameterNames, translatedParameterTypes).map { $0.0 + ": " + $0.1 }
		let parameterStrings = zip(parameters, valueStrings).map { $0.0 + $0.1 }

		result += parameterStrings.joined(separator: ", ")

		result += ")"

		if returnType != "()", !isInit {
			let translatedReturnType = translateType(returnType)
			result += ": \(translatedReturnType)"
		}

		guard let statements = statements else {
			return result + "\n"
		}

		result += " {\n"
		indentation = increaseIndentation(indentation)
		result += try translate(subtrees: statements, withIndentation: indentation)
		indentation = decreaseIndentation(indentation)
		result += indentation + "}\n"

		return result
	}

	private func translateForEachStatement(
		collection: GRYExpression, variable: GRYExpression, statements: [GRYTopLevelNode],
		withIndentation indentation: String) throws -> String
	{
		var result = "\(indentation)for ("

		let variableTranslation = try translateExpression(variable)

		result += variableTranslation + " in "

		let collectionTranslation = try translateExpression(collection)

		result += collectionTranslation + ") {\n"

		let increasedIndentation = increaseIndentation(indentation)
		let statementsTranslation = try translate(
			subtrees: statements, withIndentation: increasedIndentation)

		result += statementsTranslation

		result += indentation + "}\n"
		return result
	}

	private func translateIfStatement(
		conditions: [GRYExpression], declarations: [GRYTopLevelNode], statements: [GRYTopLevelNode],
		elseStatement: GRYTopLevelNode?, isGuard: Bool, isElseIf: Bool,
		withIndentation indentation: String) throws -> String
	{
		let keyword = (conditions.isEmpty && declarations.isEmpty) ?
			"else" :
			(isElseIf ? "else if" : "if")

		var result = indentation + keyword + " "

		let increasedIndentation = increaseIndentation(indentation)

		let conditionsTranslation =
			try conditions.map(translateExpression).joined(separator: " && ")

		if keyword != "else" {
			let parenthesizedCondition = isGuard ?
				("(!(" + conditionsTranslation + ")) ") :
				("(" + conditionsTranslation + ") ")

			result += parenthesizedCondition
		}

		result += "{\n"

		let statementsString =
			try translate(subtrees: statements, withIndentation: increasedIndentation)

		result += statementsString + indentation + "}\n"

		if let unwrappedElse = elseStatement {
			guard case let .ifStatement(
				conditions: conditions, declarations: declarations, statements: statements,
				elseStatement: elseStatement, isGuard: isGuard) = unwrappedElse else
			{
				preconditionFailure()
			}
			result += try translateIfStatement(
				conditions: conditions, declarations: declarations, statements: statements,
				elseStatement: elseStatement, isGuard: isGuard, isElseIf: true,
				withIndentation: indentation)
		}

		return result
	}

	private func translateThrowStatement(
		expression: GRYExpression, withIndentation indentation: String) throws -> String
	{
		let expressionString = try translateExpression(expression)
		return "\(indentation)throw \(expressionString)\n"
	}

	private func translateReturnStatement(
		expression: GRYExpression?, withIndentation indentation: String) throws -> String
	{
		if let expression = expression {
			let expressionString = try translateExpression(expression)
			return "\(indentation)return \(expressionString)\n"
		}
		else {
			return "\(indentation)return\n"
		}
	}

	private func translateVariableDeclaration(
		identifier: String, typeName: String, expression: GRYExpression?, getter: GRYTopLevelNode?,
		setter: GRYTopLevelNode?, isLet: Bool, extendsType: String?, annotations: String?,
		withIndentation indentation: String) throws -> String
	{
		var result = indentation

		if let annotations = annotations {
			result += "\(annotations) "
		}

		var keyword: String
		if getter != nil && setter != nil {
			keyword = "var"
		}
		else if getter != nil && setter == nil {
			keyword = "val"
		}
		else {
			if isLet {
				keyword = "val"
			}
			else {
				keyword = "var"
			}
		}

		result += "\(keyword) "

		let extensionPrefix: String
		if let extendsType = extendsType {
			let translatedExtendedType = translateType(extendsType)
			extensionPrefix = "\(translatedExtendedType)."
		}
		else {
			extensionPrefix = ""
		}

		result += "\(extensionPrefix)\(identifier): "

		let translatedType = translateType(typeName)
		result += translatedType

		if let expression = expression {
			let expressionTranslation = try translateExpression(expression)
			result += " = " + expressionTranslation
		}

		result += "\n"

		let indentation1 = increaseIndentation(indentation)
		let indentation2 = increaseIndentation(indentation1)
		if let getter = getter {
			guard case let .functionDeclaration(
				prefix: _, parameterNames: _, parameterTypes: _, defaultValues: _, returnType: _,
				isImplicit: _, isStatic: _, extendsType: _, statements: statements,
				access: _) = getter else
			{
				preconditionFailure()
			}

			if let statements = statements {
				result += indentation1 + "get() {\n"
				result += try translate(subtrees: statements, withIndentation: indentation2)
				result += indentation1 + "}\n"
			}
		}

		if let setter = setter {
			guard case let .functionDeclaration(
				prefix: _, parameterNames: _, parameterTypes: _, defaultValues: _, returnType: _,
				isImplicit: _, isStatic: _, extendsType: _, statements: statements,
				access: _) = setter else
			{
				preconditionFailure()
			}

			if let statements = statements {
				result += indentation1 + "set(newValue) {\n"
				result += try translate(subtrees: statements, withIndentation: indentation2)
				result += indentation1 + "}\n"
			}
		}

		return result
	}

	private func translateAssignmentStatement(
		leftHand: GRYExpression, rightHand: GRYExpression, withIndentation indentation: String)
		throws -> String
	{
		let leftTranslation = try translateExpression(leftHand)
		let rightTranslation = try translateExpression(rightHand)
		return "\(indentation)\(leftTranslation) = \(rightTranslation)\n"
	}

	private func translateExpression(_ expression: GRYExpression) throws -> String {
		switch expression {
		case let .templateExpression(pattern: pattern, matches: matches):
			return try translateTemplateExpression(pattern: pattern, matches: matches)
		case let .literalCodeExpression(string: string):
			return translateLiteralCodeExpression(string: string)
		case let .arrayExpression(elements: elements, type: type):
			return try translateArrayExpression(elements: elements, type: type)
		case let .binaryOperatorExpression(
			leftExpression: leftExpression,
			rightExpression: rightExpression,
			operatorSymbol: operatorSymbol,
			type: type):

			return try translateBinaryOperatorExpression(
				leftExpression: leftExpression,
				rightExpression: rightExpression,
				operatorSymbol: operatorSymbol,
				type: type)
		case let .callExpression(function: function, parameters: parameters, type: type):
			return try translateCallExpression(
				function: function, parameters: parameters, type: type)
		case let .closureExpression(
			parameterNames: parameterNames, parameterTypes: parameterTypes, statements: statements,
			type: type):

			return try translateClosureExpression(
				parameterNames: parameterNames, parameterTypes: parameterTypes,
				statements: statements, type: type)
		case let .declarationReferenceExpression(
			identifier: identifier, type: type, isStandardLibrary: isStandardLibrary,
			isImplicit: isImplicit):

			return translateDeclarationReferenceExpression(
				identifier: identifier, type: type, isStandardLibrary: isStandardLibrary,
				isImplicit: isImplicit)
		case let .dotExpression(leftExpression: leftExpression, rightExpression: rightExpression):
			return try translateDotSyntaxCallExpression(
				leftExpression: leftExpression, rightExpression: rightExpression)
		case let .literalStringExpression(value: value):
			return translateStringLiteral(value: value)
		case let .interpolatedStringLiteralExpression(expressions: expressions):
			return try translateInterpolatedStringLiteralExpression(expressions: expressions)
		case let .unaryOperatorExpression(
			expression: expression, operatorSymbol: operatorSymbol, type: type):

			return try translatePrefixUnaryExpression(
				expression: expression, operatorSymbol: operatorSymbol, type: type)
		case let .typeExpression(type: type):
			return translateType(type)
		case let .subscriptExpression(
			subscriptedExpression: subscriptedExpression, indexExpression: indexExpression,
			type: type):

			return try translateSubscriptExpression(
				subscriptedExpression: subscriptedExpression, indexExpression: indexExpression,
				type: type)
		case let .parenthesesExpression(expression: expression):
			return try "(" + translateExpression(expression) + ")"
		case let .forceValueExpression(expression: expression):
			return try translateExpression(expression) + "!!"
		case let .optionalExpression(expression: expression):
			return try translateExpression(expression) + "?"
		case let .literalIntExpression(value: value):
			return String(value)
		case let .literalDoubleExpression(value: value):
			return String(value)
		case let .literalBoolExpression(value: value):
			return String(value)
		case .nilLiteralExpression:
			return "null"
		case let .tupleExpression(pairs: pairs):
			return try translateTupleExpression(pairs: pairs)
		}
	}

	private func translateSubscriptExpression(
		subscriptedExpression: GRYExpression, indexExpression: GRYExpression, type: String)
		throws -> String
	{
		return try translateExpression(subscriptedExpression) +
			"[\(try translateExpression(indexExpression))]"
	}

	private func translateArrayExpression(elements: [GRYExpression], type: String) throws
		-> String
	{
		let expressionsString = try elements.map(translateExpression).joined(separator: ", ")

		return "mutableListOf(\(expressionsString))"
	}

	private func translateDotSyntaxCallExpression(
		leftExpression: GRYExpression, rightExpression: GRYExpression) throws -> String
	{
		let leftHandString = try translateExpression(leftExpression)
		let rightHandString = try translateExpression(rightExpression)

		if GRYKotlinTranslator.enums.contains(leftHandString) {
			let capitalizedEnumCase = rightHandString.capitalizedAsCamelCase
			return "\(leftHandString).\(capitalizedEnumCase)()"
		}
		else {
			return "\(leftHandString).\(rightHandString)"
		}
	}

	private func translateBinaryOperatorExpression(
		leftExpression: GRYExpression, rightExpression: GRYExpression, operatorSymbol: String,
		type: String) throws -> String
	{
		let leftTranslation = try translateExpression(leftExpression)
		let rightTranslation = try translateExpression(rightExpression)
		return "\(leftTranslation) \(operatorSymbol) \(rightTranslation)"
	}

	private func translatePrefixUnaryExpression(
		expression: GRYExpression, operatorSymbol: String, type: String) throws -> String
	{
		let expressionTranslation = try translateExpression(expression)
		return operatorSymbol + expressionTranslation
	}

	private func translateCallExpression(
		function: GRYExpression, parameters: GRYExpression, type: String) throws -> String
	{
		guard case let .tupleExpression(pairs: pairs) = parameters else {
			preconditionFailure()
		}

		let functionTranslation = try translateExpression(function)
		let parametersTranslation = try translateTupleExpression(pairs: pairs)

		return functionTranslation + parametersTranslation
	}

	private func translateClosureExpression(
		parameterNames: [String], parameterTypes: [String], statements: [GRYTopLevelNode],
		type: String) throws -> String
	{
		var result = "{ "

		let parametersString = zip(parameterNames, parameterTypes)
			.map { "\($0): \($1)" }.joined(separator: ", ")

		if !parametersString.isEmpty {
			result += parametersString + " -> "
		}

		guard let firstStatement = statements.first,
			case let GRYTopLevelNode.expression(expression: expression) = firstStatement else
		{
			throw unexpectedASTStructureError(
				"Only single-expression closures are supported.",
				AST: .expression(expression: .closureExpression(
					parameterNames: parameterNames, parameterTypes: parameterTypes,
					statements: statements, type: type)))
		}

		result += try translateExpression(expression) + " }"
		return result
	}

	private func translateLiteralCodeExpression(string: String) -> String {
		return removeBackslashEscapes(string)
	}

	private func translateTemplateExpression(pattern: String, matches: [String: GRYExpression])
		throws -> String
	{
		var result = pattern
		for (string, expression) in matches {
			while let range = result.range(of: string) {
				result.replaceSubrange(range, with: try translateExpression(expression))
			}
		}
		return result
	}

	private func translateAsKotlinLiteral(
		functionTranslation: String,
		parameters: GRYExpression) -> String
	{
		let string: String
		if case let .tupleExpression(pairs: pairs) = parameters,
			let lastPair = pairs.last
		{
			if case let .literalStringExpression(value: value) = lastPair.expression {
				string = value
			}
			else {
				preconditionFailure()
			}

			let unescapedString = removeBackslashEscapes(string)
			return unescapedString
		}

		preconditionFailure()
	}

	private func translateDeclarationReferenceExpression(
		identifier: String, type: String, isStandardLibrary: Bool, isImplicit: Bool) -> String
	{
		return String(identifier.prefix { $0 != "(" })
	}

	private func translateTupleExpression(pairs: [GRYExpression.TuplePair]) throws -> String {
		guard !pairs.isEmpty else {
			return "()"
		}

		let contents = try pairs.map { (pair: GRYExpression.TuplePair) -> String in
			let expression = try translateExpression(pair.expression)

			if let name = pair.name {
				return "\(name) = \(expression)"
			}
			else {
				return expression
			}
		}.joined(separator: ", ")

		return "(\(contents))"
	}

	private func translateStringLiteral(value: String) -> String {
		return "\"\(value)\""
	}

	private func translateInterpolatedStringLiteralExpression(expressions: [GRYExpression])
		throws -> String
	{
		var result = "\""

		for expression in expressions {
			if case let .literalStringExpression(value: string) = expression {
				// Empty strings, as a special case, are represented by the swift ast dump
				// as two double quotes with nothing between them, instead of an actual empty string
				guard string != "\"\"" else {
					continue
				}

				result += string
			}
			else {
				result += try "${" + translateExpression(expression) + "}"
			}
		}

		result += "\""

		return result
	}

	// MARK: - Supporting methods
	private func removeBackslashEscapes(_ string: String) -> String {
		var result = ""

		var isEscaping = false
		for character in string {
			switch character {
			case "\\":
				if isEscaping {
					result.append(character)
					isEscaping = false
				}
				else {
					isEscaping = true
				}
			default:
				result.append(character)
				isEscaping = false
			}
		}

		return result
	}

	func increaseIndentation(_ indentation: String) -> String {
		return indentation + "\t"
	}

	func decreaseIndentation(_ indentation: String) -> String {
		return String(indentation.dropLast())
	}
}

extension String {
	var capitalizedAsCamelCase: String {
		let firstCharacter = self.first!
		let capitalizedFirstCharacter = String(firstCharacter).uppercased()
		return String(capitalizedFirstCharacter + self.dropFirst())
	}
}
