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

public class GRYSwift4_1Translator {
	enum GRYSwiftTranslatorError: GRYPrintableError {
		case unexpectedAstStructure(
			file: String,
			line: Int,
			function: String,
			message: String,
			ast: GRYSwiftAst)

		func print() {
			switch self {
			case let .unexpectedAstStructure(
				file: file, line: line, function: function, message: message, ast: ast):

				Swift.print(
					"Error: failed to translate Swift Ast into Gryphon Ast.\n" +
					"On file \(file), line \(line), function \(function).\n" +
					message + ".\n" +
					"Thrown when translating the following ast node:\n")
				ast.prettyPrint(horizontalLimit: 100)
			}
		}
	}

	func unexpectedAstStructureError(
		file: String = #file, line: Int = #line, function: String = #function, _ message: String,
		ast: GRYSwiftAst) -> GRYSwiftTranslatorError
	{
		return GRYSwiftTranslatorError.unexpectedAstStructure(
			file: file, line: line, function: function, message: message, ast: ast)
	}

	func ensure(
		file: String = #file, line: Int = #line, function: String = #function,
		ast: GRYSwiftAst, isNamed expectedAstName: String) throws
	{
		if ast.name != expectedAstName {
			throw GRYSwiftTranslatorError.unexpectedAstStructure(
				file: file, line: line, function: function,
				message: "Trying to translate \(ast.name) as '\(expectedAstName)'", ast: ast)
		}
	}

	// MARK: - Properties
	var danglingPatternBinding: (identifier: String, type: String, expression: GRYExpression?)?

	var extendingType: String?

	var errors = [String]()

	// MARK: - Interface
	public init() { }

	public func translateAST(_ ast: GRYSwiftAst) throws -> GRYSourceFile {
		// First, translate declarations that shouldn't be inside the main function
		let declarationNames = [
			"Protocol",
			"Class Declaration",
			"Extension Declaration",
			"Function Declaration",
			"Enum Declaration",
		]
		let isDeclaration = { (ast: GRYSwiftAst) -> Bool in declarationNames.contains(ast.name) }

		let swiftDeclarations = ast.subtrees.filter(isDeclaration)
		let declarations = try translate(subtrees: swiftDeclarations)

		// Then, translate the remaining statements (if there are any) and wrap them in the main
		// function
		let swiftStatements = ast.subtrees.filter({ !isDeclaration($0) })
		let statements = try translate(subtrees: swiftStatements)

		return GRYSourceFile(declarations: declarations, statements: statements)
	}

	// MARK: - Top-level translations
	private func translate(subtrees: [GRYSwiftAst]) throws -> [GRYTopLevelNode] {
		return try subtrees.reduce([], { (result, subtree) -> [GRYTopLevelNode] in
			try result + translate(subtree: subtree).compactMap { $0 }
		})
	}

	private func translate(subtree: GRYSwiftAst) throws -> [GRYTopLevelNode?] {
		var result: GRYTopLevelNode?

		switch subtree.name {
		case "Top Level Code Declaration":
			result = try translate(topLevelCode: subtree)
		case "Import Declaration":
			result = .importDeclaration(name: subtree.standaloneAttributes[0])
		case "Class Declaration":
			result = try translate(classDeclaration: subtree)
		case "Enum Declaration":
			result = try translate(enumDeclaration: subtree)
		case "Extension Declaration":
			self.extendingType = subtree.standaloneAttributes[0]
			let result = try translate(subtrees: subtree.subtrees)
			self.extendingType = nil
			return result
		case "For Each Statement":
			result = try translate(forEachStatement: subtree)
		case "Function Declaration":
			result = try translate(functionDeclaration: subtree)
		case "Protocol":
			result = try translate(protocolDeclaration: subtree)
		case "Throw Statement":
			result = try translate(throwStatement: subtree)
		case "Variable Declaration":
			result = try translate(variableDeclaration: subtree)
		case "Assign Expression":
			result = try translate(assignExpression: subtree)
		case "If Statement", "Guard Statement":
			result = try translate(ifStatement: subtree)
		case "Pattern Binding Declaration":
			try process(patternBindingDeclaration: subtree)
			return []
		case "Return Statement":
			result = try translate(returnStatement: subtree)
		default:
			if subtree.name.hasSuffix("Expression") {
				let expression = try translate(expression: subtree)
				result = .expression(expression: expression)
			}
			else {
				result = nil
			}
		}

		return [result]
	}

	private func translate(expression: GRYSwiftAst) throws -> GRYExpression {

		switch expression.name {
		case "Array Expression":
			return try translate(arrayExpression: expression)
		case "Binary Expression":
			return try translate(binaryExpression: expression)
		case "Call Expression":
			return try translate(callExpression: expression)
		case "Declaration Reference Expression":
			return try translate(declarationReferenceExpression: expression)
		case "Dot Syntax Call Expression":
			return try translate(dotSyntaxCallExpression: expression)
		case "String Literal Expression":
			return try translate(stringLiteralExpression: expression)
		case "Interpolated String Literal Expression":
			return try translate(interpolatedStringLiteralExpression: expression)
		case "Erasure Expression":
			if let lastExpression = expression.subtrees.last {
				return try translate(expression: lastExpression)
			}
			else {
				throw unexpectedAstStructureError(
					"Unrecognized structure in automatic expression",
					ast: expression)
			}
		case "Prefix Unary Expression":
			return try translate(prefixUnaryExpression: expression)
		case "Type Expression":
			return try translate(typeExpression: expression)
		case "Member Reference Expression":
			return try translate(memberReferenceExpression: expression)
		case "Subscript Expression":
			return try translate(subscriptExpression: expression)
		case "Parentheses Expression":
			if let firstExpression = expression.subtree(at: 0) {
				return .parenthesesExpression(
					expression: try translate(expression: firstExpression))
			}
			else {
				throw unexpectedAstStructureError(
					"Unrecognized structure in automatic expression",
					ast: expression)
			}
		case "Force Value Expression":
			if let firstExpression = expression.subtree(at: 0) {
				let expression = try translate(expression: firstExpression)
				return .forceValueExpression(expression: expression)
			}
			else {
				throw unexpectedAstStructureError(
					"Unrecognized structure in automatic expression",
					ast: expression)
			}
		case "Autoclosure Expression",
			 "Inject Into Optional",
			 "Inout Expression",
			 "Load Expression":
			if let lastExpression = expression.subtrees.last {
				return try translate(expression: lastExpression)
			}
			else {
				throw unexpectedAstStructureError(
					"Unrecognized structure in automatic expression",
					ast: expression)
			}
		default:
			throw unexpectedAstStructureError(
				"Unrecognized subtree",
				ast: expression)
		}
	}

	// MARK: - Leaf translations
	private func translate(protocolDeclaration: GRYSwiftAst) throws -> GRYTopLevelNode {
		try ensure(ast: protocolDeclaration, isNamed: "Protocol")

		guard let protocolName = protocolDeclaration.standaloneAttributes.first else {
			throw unexpectedAstStructureError(
				"Unrecognized structure",
				ast: protocolDeclaration)
		}

		return .protocolDeclaration(name: protocolName)
	}

	private func translate(assignExpression: GRYSwiftAst) throws -> GRYTopLevelNode {
		try ensure(ast: assignExpression, isNamed: "Assign Expression")

		if let leftExpression = assignExpression.subtree(at: 0),
			let rightExpression = assignExpression.subtree(at: 1)
		{
			let leftTranslation = try translate(expression: leftExpression)
			let rightTranslation = try translate(expression: rightExpression)

			return .assignmentStatement(leftHand: leftTranslation, rightHand: rightTranslation)
		}
		else {
			throw unexpectedAstStructureError(
				"Unrecognized structure",
				ast: assignExpression)
		}
	}

	private func translate(classDeclaration: GRYSwiftAst) throws -> GRYTopLevelNode {
		try ensure(ast: classDeclaration, isNamed: "Class Declaration")

		// Get the class name
		let name = classDeclaration.standaloneAttributes.first!

		// Check for inheritance
		let inheritanceArray: [String]
		if let inheritanceList = classDeclaration.keyValueAttributes["inherits"] {
			inheritanceArray = inheritanceList.split(withStringSeparator: ", ")
		}
		else {
			inheritanceArray = []
		}

		guard !inheritanceArray.contains("GRYIgnore") else {
			return .classDeclaration(name: name, inherits: inheritanceArray, members: [])
		}

		// Translate the contents
		let classContents = try translate(subtrees: classDeclaration.subtrees)

		return .classDeclaration(name: name, inherits: inheritanceArray, members: classContents)
	}

	private func translate(throwStatement: GRYSwiftAst) throws -> GRYTopLevelNode {
		try ensure(ast: throwStatement, isNamed: "Throw Statement")

		if let expression = throwStatement.subtrees.last {
			let expressionTranslation = try translate(expression: expression)
			return .throwStatement(expression: expressionTranslation)
		}
		else {
			throw unexpectedAstStructureError(
				"Unrecognized structure",
				ast: throwStatement)
		}
	}

	private func translate(enumDeclaration: GRYSwiftAst) throws -> GRYTopLevelNode {
		try ensure(ast: enumDeclaration, isNamed: "Enum Declaration")

		let access = enumDeclaration.keyValueAttributes["access"]

		let name = enumDeclaration.standaloneAttributes.first!

		let inheritanceArray: [String]
		if let inheritanceList = enumDeclaration.keyValueAttributes["inherits"] {
			inheritanceArray = inheritanceList.split(withStringSeparator: ", ")
		}
		else {
			inheritanceArray = []
		}

		guard !inheritanceArray.contains("GRYIgnore") else {
			return .enumDeclaration(
				access: access,
				name: name,
				inherits: inheritanceArray,
				elements: [])
		}

		var elements = [String]()
		let enumElementDeclarations =
			enumDeclaration.subtrees.filter { $0.name == "Enum Element Declaration" }
		for enumElementDeclaration in enumElementDeclarations {
			guard let elementName = enumElementDeclaration.standaloneAttributes.first else {
				throw unexpectedAstStructureError(
					"Unrecognized enum element",
					ast: enumDeclaration)
			}

			elements.append(elementName)
		}

		return .enumDeclaration(
			access: access,
			name: name,
			inherits: inheritanceArray,
			elements: elements)
	}

	private func translate(memberReferenceExpression: GRYSwiftAst) throws -> GRYExpression {
		try ensure(ast: memberReferenceExpression, isNamed: "Member Reference Expression")

		if let declaration = memberReferenceExpression["decl"],
			let memberOwner = memberReferenceExpression.subtree(at: 0)
		{
			let leftHand = try translate(expression: memberOwner)
			let member = getIdentifierFromDeclaration(declaration)
			let rightHand = GRYExpression.declarationReferenceExpression(identifier: member)
			return .dotExpression(leftExpression: leftHand,
								  rightExpression: rightHand)
		}
		else {
			throw unexpectedAstStructureError(
				"Unrecognized structure",
				ast: memberReferenceExpression)
		}
	}

	private func translate(prefixUnaryExpression: GRYSwiftAst) throws -> GRYExpression {
		try ensure(ast: prefixUnaryExpression, isNamed: "Prefix Unary Expression")

		if let declaration = prefixUnaryExpression
			.subtree(named: "Dot Syntax Call Expression")?
			.subtree(named: "Declaration Reference Expression")?["decl"],
			let expression = prefixUnaryExpression.subtree(at: 1)
		{
			let expressionTranslation = try translate(expression: expression)
			let operatorIdentifier = getIdentifierFromDeclaration(declaration)

			return .unaryOperatorExpression(
				expression: expressionTranslation,
				operatorSymbol: operatorIdentifier)
		}
		else {
			throw unexpectedAstStructureError(
				"Unrecognized structure",
				ast: prefixUnaryExpression)
		}
	}

	private func translate(binaryExpression: GRYSwiftAst) throws -> GRYExpression {
		try ensure(ast: binaryExpression, isNamed: "Binary Expression")

		let operatorIdentifier: String

		if let declaration = binaryExpression
			.subtree(named: "Dot Syntax Call Expression")?
			.subtree(named: "Declaration Reference Expression")?["decl"],
			let tupleExpression = binaryExpression.subtree(named: "Tuple Expression"),
			let leftHandExpression = tupleExpression.subtree(at: 0),
			let rightHandExpression = tupleExpression.subtree(at: 1)
		{
			operatorIdentifier = getIdentifierFromDeclaration(declaration)
			let leftHandTranslation = try translate(expression: leftHandExpression)
			let rightHandTranslation = try translate(expression: rightHandExpression)

			return .binaryOperatorExpression(
				leftExpression: leftHandTranslation,
				rightExpression: rightHandTranslation,
				operatorSymbol: operatorIdentifier)
		}
		else {
			throw unexpectedAstStructureError(
				"Unrecognized structure",
				ast: binaryExpression)
		}
	}

	private func translate(typeExpression: GRYSwiftAst) throws -> GRYExpression {
		try ensure(ast: typeExpression, isNamed: "Type Expression")

		guard let type = typeExpression.keyValueAttributes["typerepr"] else {
			throw unexpectedAstStructureError(
				"Unrecognized structure",
				ast: typeExpression)
		}

		return .typeExpression(type: type)
	}

	private func translate(dotSyntaxCallExpression: GRYSwiftAst) throws -> GRYExpression {
		try ensure(ast: dotSyntaxCallExpression, isNamed: "Dot Syntax Call Expression")

		if let leftHandTree = dotSyntaxCallExpression.subtree(at: 1),
			let rightHandExpression = dotSyntaxCallExpression.subtree(at: 0)
		{
			let rightHand = try translate(expression: rightHandExpression)
			let leftHand = try translate(typeExpression: leftHandTree)

			return .dotExpression(leftExpression: leftHand, rightExpression: rightHand)
		}
		else {
			throw unexpectedAstStructureError(
				"Unrecognized structure",
				ast: dotSyntaxCallExpression)
		}
	}

	private func translate(returnStatement: GRYSwiftAst) throws -> GRYTopLevelNode {
		try ensure(ast: returnStatement, isNamed: "Return Statement")

		if let expression = returnStatement.subtrees.last {
			let expression = try translate(expression: expression)
			return .returnStatement(expression: expression)
		}
		else {
			return .returnStatement(expression: nil)
		}
	}

	private func translate(forEachStatement: GRYSwiftAst) throws -> GRYTopLevelNode {
		try ensure(ast: forEachStatement, isNamed: "For Each Statement")

		guard let variableName = forEachStatement
			.subtree(named: "Pattern Named")?
			.standaloneAttributes.first,
			let collectionExpression = forEachStatement.subtree(at: 2) else
		{
			throw unexpectedAstStructureError(
				"Unable to detect variable or collection",
				ast: forEachStatement)
		}

		guard let braceStatement = forEachStatement.subtrees.last,
			braceStatement.name == "Brace Statement" else
		{
			throw unexpectedAstStructureError(
				"Unable to detect body of statements",
				ast: forEachStatement)
		}

		let variable = GRYExpression.declarationReferenceExpression(identifier: variableName)
		let collectionTranslation = try translate(expression: collectionExpression)
		let statements = try translate(subtrees: braceStatement.subtrees)

		return .forEachStatement(
			collection: collectionTranslation,
			variable: variable,
			statements: statements)
	}

	private func translate(ifStatement: GRYSwiftAst) throws -> GRYTopLevelNode {
		guard ifStatement.name == "If Statement" || ifStatement.name == "Guard Statement" else {
			throw unexpectedAstStructureError(
				"Trying to translate \(ifStatement.name) as an if or guard statement",
				ast: ifStatement)
		}

		let isGuard = (ifStatement.name == "Guard Statement")

		let (letDeclarations, conditions) = try translateDeclarationsAndConditions(
			forIfStatement: ifStatement)

		let braceStatement: GRYSwiftAst
		let elseIfStatement: GRYTopLevelNode?
		let elseStatement: GRYTopLevelNode?

		if ifStatement.subtrees.count > 2,
			let unwrappedBraceStatement = ifStatement.subtrees.secondToLast,
			unwrappedBraceStatement.name == "Brace Statement",
			let elseIfAST = ifStatement.subtrees.last,
			elseIfAST.name == "If Statement"
		{
			braceStatement = unwrappedBraceStatement
			elseIfStatement = try translate(ifStatement: elseIfAST)
			elseStatement = nil
		}
		else if ifStatement.subtrees.count > 2,
			let unwrappedBraceStatement = ifStatement.subtrees.secondToLast,
			unwrappedBraceStatement.name == "Brace Statement",
			let elseAST = ifStatement.subtrees.last,
			elseAST.name == "Brace Statement"
		{
			braceStatement = unwrappedBraceStatement
			elseIfStatement = nil

			let statements = try translate(subtrees: elseAST.subtrees)
			elseStatement = .ifStatement(
				conditions: [], declarations: [],
				statements: statements,
				elseStatement: nil,
				isGuard: false)
		}
		else if let unwrappedBraceStatement = ifStatement.subtrees.last,
			unwrappedBraceStatement.name == "Brace Statement"
		{
			braceStatement = unwrappedBraceStatement
			elseIfStatement = nil
			elseStatement = nil
		}
		else {
			throw unexpectedAstStructureError(
				"Unable to detect body of statements",
				ast: ifStatement)
		}

		let statements = braceStatement.subtrees
		let statementsResult = try translate(subtrees: statements)

		return .ifStatement(
			conditions: conditions,
			declarations: letDeclarations,
			statements: statementsResult,
			elseStatement: elseIfStatement ?? elseStatement,
			isGuard: isGuard)
	}

	private func translateDeclarationsAndConditions(
		forIfStatement ifStatement: GRYSwiftAst) throws
		-> (declarations: [GRYTopLevelNode], conditions: [GRYExpression])
	{
		guard ifStatement.name == "If Statement" || ifStatement.name == "Guard Statement" else {
			throw unexpectedAstStructureError(
				"Trying to translate \(ifStatement.name) as an if or guard statement",
				ast: ifStatement)
		}

		var conditionsResult = [GRYExpression]()
		var declarationsResult = [GRYTopLevelNode]()

		let conditions = ifStatement.subtrees.filter {
			$0.name != "If Statement" && $0.name != "Brace Statement"
		}

		for condition in conditions {
			// If it's an if-let
			if condition.name == "Pattern",
				let optionalSomeElement = condition.subtree(named: "Optional Some Element")
			{
				let patternNamed: GRYSwiftAst
				let isLet: Bool
				if let patternLet = optionalSomeElement.subtree(named: "Pattern Let"),
					let unwrapped = patternLet.subtree(named: "Pattern Named")
				{
					patternNamed = unwrapped
					isLet = true
				}
				else if let unwrapped = optionalSomeElement
					.subtree(named: "Pattern Variable")?
					.subtree(named: "Pattern Named")
				{
					patternNamed = unwrapped
					isLet = false
				}
				else {
					throw unexpectedAstStructureError(
						"Unable to detect pattern in let declaration",
						ast: ifStatement)
				}

				guard let type = optionalSomeElement["type"] else {
					throw unexpectedAstStructureError(
						"Unable to detect type in let declaration",
						ast: ifStatement)
				}

				guard let name = patternNamed.standaloneAttributes.first,
					let lastCondition = condition.subtrees.last else
				{
					throw unexpectedAstStructureError(
						"Unable to get expression in let declaration",
						ast: ifStatement)
				}

				let expression = try translate(expression: lastCondition)

				declarationsResult.append(.variableDeclaration(
					identifier: name,
					typeName: type,
					expression: expression,
					getter: nil, setter: nil,
					isLet: isLet,
					extendsType: nil))
			}
			else {
				conditionsResult.append(try translate(expression: condition))
			}
		}

		return (declarations: declarationsResult, conditions: conditionsResult)
	}

	private func translate(functionDeclaration: GRYSwiftAst) throws -> GRYTopLevelNode? {
		try ensure(ast: functionDeclaration, isNamed: "Function Declaration")

		// Getters and setters will appear again in the Variable Declaration AST and get translated
		let isGetterOrSetter =
			(functionDeclaration["getter_for"] != nil) || (functionDeclaration["setter_for"] != nil)
		let isImplicit = functionDeclaration.standaloneAttributes.contains("implicit")
		guard !isImplicit && !isGetterOrSetter else {
			return nil
		}

		let functionName = functionDeclaration.standaloneAttributes.first ?? ""

		let access = functionDeclaration["access"]

		let functionNamePrefix = functionName.prefix { $0 != "(" }

		// Get the function parameters.
		let parameterList: GRYSwiftAst?

		// If it's a method, it includes an extra Parameter List with only `self`
		if let list = functionDeclaration.subtree(named: "Parameter List"),
			let name = list.subtree(at: 0, named: "Parameter")?.standaloneAttributes.first,
			name != "self"
		{
			parameterList = list
		}
		else if let unwrapped = functionDeclaration.subtree(at: 1, named: "Parameter List") {
			parameterList = unwrapped
		}
		else {
			parameterList = nil
		}

		var parameterNames = [String]()
		var parameterTypes = [String]()

		// Translate the parameters
		if let parameterList = parameterList {
			for parameter in parameterList.subtrees {
				if let name = parameter.standaloneAttributes.first,
					let type = parameter["interface type"]
				{
					guard name != "self" else {
						continue
					}

					parameterNames.append(name)
					parameterTypes.append(type)
				}
				else {
					throw unexpectedAstStructureError(
						"Unable to detect name or attribute for a parameter",
						ast: functionDeclaration)
				}
			}
		}

		// Translate the return type
		// TODO: Doesn't allow to return function types
		guard let returnType = functionDeclaration["interface type"]?
			.split(withStringSeparator: " -> ").last else
		{
			throw unexpectedAstStructureError(
				"Unable to get return type", ast: functionDeclaration)
		}

		let statements: [GRYTopLevelNode]
		// Translate the function body
		if let braceStatement = functionDeclaration.subtree(named: "Brace Statement") {
			statements = try translate(subtrees: braceStatement.subtrees)
		}
		else {
			throw unexpectedAstStructureError(
				"Unable to get function body", ast: functionDeclaration)
		}

		return .functionDeclaration(
			prefix: String(functionNamePrefix),
			parameterNames: parameterNames,
			parameterTypes: parameterTypes,
			returnType: returnType,
			isImplicit: isImplicit,
			statements: statements,
			access: access)
	}

	private func translate(topLevelCode topLevelCodeDeclaration: GRYSwiftAst) throws
		-> GRYTopLevelNode?
	{
		try ensure(ast: topLevelCodeDeclaration, isNamed: "Top Level Code Declaration")

		guard let braceStatement = topLevelCodeDeclaration.subtree(named: "Brace Statement") else {
			throw unexpectedAstStructureError(
				"Unrecognized structure", ast: topLevelCodeDeclaration)
		}

		let subtrees = try translate(subtrees: braceStatement.subtrees)

		return subtrees.first
	}

	private func translate(variableDeclaration: GRYSwiftAst) throws -> GRYTopLevelNode {
		try ensure(ast: variableDeclaration, isNamed: "Variable Declaration")

		if let identifier = variableDeclaration.standaloneAttributes.first,
			let type = variableDeclaration["interface type"]
		{
			let isLet = variableDeclaration.standaloneAttributes.contains("let")

			let expression: GRYExpression?
			if let patternBindingExpression = danglingPatternBinding,
				patternBindingExpression.identifier == identifier,
				patternBindingExpression.type == type
			{
				expression = patternBindingExpression.expression
				danglingPatternBinding = nil
			}
			else {
				expression = nil
			}

			var getter: GRYTopLevelNode?
			var setter: GRYTopLevelNode?
			for subtree in variableDeclaration.subtrees
				where !subtree.standaloneAttributes.contains("implicit")
			{
				guard let statements = subtree.subtree(named: "Brace Statement")?.subtrees else {
					throw unexpectedAstStructureError(
						"Unrecognized subtree", ast: variableDeclaration)
				}

				let access = subtree["access"]
				let statementsTranslation = try translate(subtrees: statements)

				if subtree["getter_for"] != nil {
					getter = .functionDeclaration(
						prefix: "get",
						parameterNames: [], parameterTypes: [],
						returnType: type,
						isImplicit: false,
						statements: statementsTranslation,
						access: access)
				}
				else {
					setter = .functionDeclaration(
						prefix: "set",
						parameterNames: ["newValue"],
						parameterTypes: [type],
						returnType: "()",
						isImplicit: false,
						statements: statementsTranslation,
						access: access)
				}
			}

			return .variableDeclaration(
				identifier: identifier,
				typeName: type,
				expression: expression,
				getter: getter,
				setter: setter,
				isLet: isLet,
				extendsType: self.extendingType)
		}
		else {
			throw unexpectedAstStructureError(
				"Failed to get identifier and type", ast: variableDeclaration)
		}
	}

	private func translate(callExpression: GRYSwiftAst) throws -> GRYExpression {
		try ensure(ast: callExpression, isNamed: "Call Expression")

		// If the call expression corresponds to an integer literal
		if let argumentLabels = callExpression["arg_labels"] {
			if argumentLabels == "_builtinIntegerLiteral:" {
				return try translate(asNumericLiteral: callExpression)
			}
			else if argumentLabels == "_builtinBooleanLiteral:" {
				return try translate(asBooleanLiteral: callExpression)
			}
			else if argumentLabels == "nilLiteral:" {
				return .nilLiteralExpression
			}
		}

		let function: GRYExpression

		// If it's an empty expression used in an "if" condition
		if callExpression.standaloneAttributes.contains("implicit"),
			callExpression["arg_labels"] == "",
			callExpression["type"] == "Int1",
			let containedExpression = callExpression
				.subtree(named: "Dot Syntax Call Expression")?
				.subtrees.last
		{
			return try translate(expression: containedExpression)
		}

		if let declarationReferenceExpression = callExpression
			.subtree(named: "Declaration Reference Expression")
		{
			function = try translate(
				declarationReferenceExpression: declarationReferenceExpression)
		}
		else if let dotSyntaxCallExpression = callExpression
				.subtree(named: "Dot Syntax Call Expression"),
			let methodName = dotSyntaxCallExpression
				.subtree(at: 0, named: "Declaration Reference Expression"),
			let methodOwner = dotSyntaxCallExpression.subtree(at: 1)
		{
			let methodName = try translate(declarationReferenceExpression: methodName)
			let methodOwner = try translate(expression: methodOwner)
			function = .dotExpression(leftExpression: methodOwner, rightExpression: methodName)
		}
		else if let typeExpression = callExpression
			.subtree(named: "Constructor Reference Call Expression")?
			.subtree(named: "Type Expression")
		{
			function = try translate(typeExpression: typeExpression)
		}
		else if let declaration = callExpression["decl"] {
			function = .declarationReferenceExpression(
				identifier: getIdentifierFromDeclaration(declaration))
		}
		else {
			throw unexpectedAstStructureError(
				"Failed to recognize function name", ast: callExpression)
		}

		let parameters = try translate(callExpressionParameters: callExpression)

		return .callExpression(function: function, parameters: parameters)
	}

	private func translate(callExpressionParameters callExpression: GRYSwiftAst) throws
		-> GRYExpression
	{
		try ensure(ast: callExpression, isNamed: "Call Expression")

		let parameters: GRYExpression
		if let parenthesesExpression = callExpression.subtree(named: "Parentheses Expression") {
			let expression = try translate(expression: parenthesesExpression)
			parameters = .tupleExpression(
				pairs: [GRYExpression.TuplePair(name: nil, expression: expression)])
		}
		else if let tupleExpression = callExpression.subtree(named: "Tuple Expression") {
			parameters = try translate(tupleExpression: tupleExpression)
		}
		else if let tupleShuffleExpression = callExpression
			.subtree(named: "Tuple Shuffle Expression")
		{
			if let tupleExpression = tupleShuffleExpression.subtree(named: "Tuple Expression") {
				parameters = try translate(tupleExpression: tupleExpression)
			}
			else if let parenthesesExpression = tupleShuffleExpression
				.subtree(named: "Parentheses Expression")
			{
				let expression = try translate(expression: parenthesesExpression)
				parameters = .tupleExpression(
					pairs: [GRYExpression.TuplePair(name: nil, expression: expression)])
			}
			else {
				throw unexpectedAstStructureError(
					"Unrecognized structure in parameters", ast: callExpression)
			}
		}
		else {
			throw unexpectedAstStructureError(
				"Unrecognized structure in parameters", ast: callExpression)
		}

		return parameters
	}

	private func translate(tupleExpression: GRYSwiftAst) throws -> GRYExpression {
		try ensure(ast: tupleExpression, isNamed: "Tuple Expression")

		// Only empty tuples don't have a list of names
		guard let names = tupleExpression["names"] else {
			return .tupleExpression(pairs: [])
		}

		let namesArray = names.split(separator: ",")

		var tuplePairs = [GRYExpression.TuplePair]()

		for (name, expression) in zip(namesArray, tupleExpression.subtrees) {
			let expression = try translate(expression: expression)

			// Empty names (like the underscore in "foo(_:)") are represented by ''
			if name == "_" {
				tuplePairs.append(GRYExpression.TuplePair(name: nil, expression: expression))
			}
			else {
				tuplePairs.append(
					GRYExpression.TuplePair(name: String(name), expression: expression))
			}
		}

		return .tupleExpression(pairs: tuplePairs)
	}

	private func translate(asNumericLiteral callExpression: GRYSwiftAst) throws -> GRYExpression {
		try ensure(ast: callExpression, isNamed: "Call Expression")

		if let tupleExpression = callExpression.subtree(named: "Tuple Expression"),
			let integerLiteralExpression = tupleExpression
				.subtree(named: "Integer Literal Expression"),
			let value = integerLiteralExpression["value"],

			let constructorReferenceCallExpression = callExpression
				.subtree(named: "Constructor Reference Call Expression"),
			let typeExpression = constructorReferenceCallExpression
				.subtree(named: "Type Expression"),
			let type = typeExpression["typerepr"]
		{
			if type == "Double" {
				return .literalDoubleExpression(value: Double(value)!)
			}
			else {
				return .literalIntExpression(value: Int(value)!)
			}
		}
		else {
			throw unexpectedAstStructureError(
				"Unrecognized structure for numeric literal", ast: callExpression)
		}
	}

	private func translate(asBooleanLiteral callExpression: GRYSwiftAst) throws
		-> GRYExpression
	{
		try ensure(ast: callExpression, isNamed: "Call Expression")

		if let tupleExpression = callExpression.subtree(named: "Tuple Expression"),
			let booleanLiteralExpression = tupleExpression
				.subtree(named: "Boolean Literal Expression"),
			let value = booleanLiteralExpression["value"]
		{
			return .literalBoolExpression(value: (value == "true"))
		}
		else {
			throw unexpectedAstStructureError(
				"Unrecognized structure for boolean literal", ast: callExpression)
		}
	}

	private func translate(stringLiteralExpression: GRYSwiftAst) throws -> GRYExpression {
		try ensure(ast: stringLiteralExpression, isNamed: "String Literal Expression")

		if let value = stringLiteralExpression["value"] {
			return .literalStringExpression(value: value)
		}
		else {
			throw unexpectedAstStructureError(
				"Unrecognized structure", ast: stringLiteralExpression)
		}
	}

	private func translate(interpolatedStringLiteralExpression: GRYSwiftAst) throws
		-> GRYExpression
	{
		precondition(
			interpolatedStringLiteralExpression.name == "Interpolated String Literal Expression")

		var expressions = [GRYExpression]()

		for expression in interpolatedStringLiteralExpression.subtrees {
			if expression.name == "String Literal Expression" {
				let expression = try translate(stringLiteralExpression: expression)
				guard case let .literalStringExpression(value: string) = expression else {
					throw unexpectedAstStructureError(
						"Failed to translate string literal",
						ast: interpolatedStringLiteralExpression)
				}

				// Empty strings, as a special case, are represented by the swift ast dump
				// as two double quotes with nothing between them, instead of an actual empty string
				guard string != "\"\"" else {
					continue
				}

				expressions.append(.literalStringExpression(value: string))
			}
			else {
				expressions.append(try translate(expression: expression))
			}
		}

		return .interpolatedStringLiteralExpression(expressions: expressions)
	}

	private func translate(declarationReferenceExpression: GRYSwiftAst) throws
		-> GRYExpression
	{
		try ensure(ast: declarationReferenceExpression, isNamed: "Declaration Reference Expression")

		if let codeDeclaration = declarationReferenceExpression.standaloneAttributes.first,
			codeDeclaration.hasPrefix("code.")
		{
			let identifier = getIdentifierFromDeclaration(codeDeclaration)
			return .declarationReferenceExpression(identifier: identifier)
		}
		else if let declaration = declarationReferenceExpression["decl"] {
			let identifier = getIdentifierFromDeclaration(declaration)
			return .declarationReferenceExpression(identifier: identifier)
		}
		else {
			throw unexpectedAstStructureError(
				"Unrecognized structure", ast: declarationReferenceExpression)
		}
	}

	private func translate(subscriptExpression: GRYSwiftAst) throws -> GRYExpression {
		try ensure(ast: subscriptExpression, isNamed: "Subscript Expression")

		if let parenthesesExpression = subscriptExpression.subtree(
			at: 1,
			named: "Parentheses Expression"),
			let subscriptContents = parenthesesExpression.subtree(at: 0),
			let subscriptedExpression = subscriptExpression.subtree(at: 0)
		{
			let subscriptContentsTranslation = try translate(expression: subscriptContents)
			let subscriptedExpressionTranslation = try translate(expression: subscriptedExpression)

			return .subscriptExpression(
				subscriptedExpression: subscriptedExpressionTranslation,
				indexExpression: subscriptContentsTranslation)
		}
		else {
			throw unexpectedAstStructureError(
				"Unrecognized structure", ast: subscriptExpression)
		}
	}

	private func translate(arrayExpression: GRYSwiftAst) throws -> GRYExpression {
		try ensure(ast: arrayExpression, isNamed: "Array Expression")

		let expressionsArray = try arrayExpression.subtrees.map(translate(expression:))

		return .arrayExpression(elements: expressionsArray)
	}

	// MARK: - Supporting methods
	private func process(patternBindingDeclaration: GRYSwiftAst) throws {
		try ensure(ast: patternBindingDeclaration, isNamed: "Pattern Binding Declaration")

		// Some patternBindingDeclarations are empty, and that's ok. See the classes.swift test
		// case.
		guard let expression = patternBindingDeclaration.subtrees.last,
			ASTIsExpression(expression) else
		{
			return
		}

		let translatedExpression = try translate(expression: expression)

		let binding: GRYSwiftAst

		if let unwrappedBinding = patternBindingDeclaration
			.subtree(named: "Pattern Typed")?
			.subtree(named: "Pattern Named")
		{
			binding = unwrappedBinding
		}
		else if let unwrappedBinding = patternBindingDeclaration.subtree(named: "Pattern Named") {
			binding = unwrappedBinding
		}
		else {
			throw unexpectedAstStructureError(
				"Pattern not recognized", ast: patternBindingDeclaration)
		}

		guard let identifier = binding.standaloneAttributes.first,
			let type = binding.keyValueAttributes["type"] else
		{
			throw unexpectedAstStructureError(
				"Type not recognized", ast: patternBindingDeclaration)
		}

		danglingPatternBinding =
			(identifier: identifier,
			 type: type,
			 expression: translatedExpression)

		return
	}

	private func getIdentifierFromDeclaration(_ declaration: String) -> String {
		var index = declaration.startIndex
		var lastPeriodIndex = declaration.startIndex
		while index != declaration.endIndex {
			let character = declaration[index]

			if character == "." {
				lastPeriodIndex = index
			}
			if character == "@" {
				break
			}

			index = declaration.index(after: index)
		}

		let identifierStartIndex = declaration.index(after: lastPeriodIndex)

		let identifier = declaration[identifierStartIndex..<index]

		if identifier == "self" {
			return "this"
		}
		else {
			return String(identifier)
		}
	}

	private func ASTIsExpression(_ ast: GRYSwiftAst) -> Bool {
		return ast.name.hasSuffix("Expression") || ast.name == "Inject Into Optional"
	}
}
