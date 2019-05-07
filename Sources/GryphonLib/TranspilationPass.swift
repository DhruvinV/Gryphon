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

public class TranspilationPass {
	internal static func isASwiftRawRepresentableType(_ typeName: String) -> Bool {
		return [
			"String",
			"Int", "Int8", "Int16", "Int32", "Int64",
			"UInt", "UInt8", "UInt16", "UInt32", "UInt64",
			"Float", "Float32", "Float64", "Float80", "Double",
			].contains(typeName)
	}

	//
	var ast: GryphonAST

	fileprivate var parents: ArrayClass<ASTNode> = []
	fileprivate var parent: ASTNode {
		return parents.secondToLast!
	}

	init(ast: GryphonAST) {
		self.ast = ast
	}

	func run() -> GryphonAST { // annotation: open
		let replacedStatements = replaceStatements(ast.statements)
		let replacedDeclarations = replaceStatements(ast.declarations)
		return GryphonAST(
			sourceFile: ast.sourceFile,
			declarations: replacedDeclarations,
			statements: replacedStatements)
	}

	func replaceStatements( // annotation: open
		_ statements: ArrayClass<Statement>)
		-> ArrayClass<Statement>
	{
		return statements.flatMap { replaceStatement($0) }
	}

	func replaceStatement( // annotation: open
		_ statement: Statement)
		-> ArrayClass<Statement>
	{
		parents.append(.statementNode(value: statement))
		defer { parents.removeLast() }

		switch statement {
		case let .expressionStatement(expression: expression):
			return replaceExpressionStatement(expression: expression)
		case let .extensionDeclaration(typeName: typeName, members: members):
			return replaceExtension(typeName: typeName, members: members)
		case let .importDeclaration(moduleName: moduleName):
			return replaceImportDeclaration(moduleName: moduleName)
		case let .typealiasDeclaration(
			identifier: identifier,
			typeName: typeName,
			isImplicit: isImplicit):

			return replaceTypealiasDeclaration(
				identifier: identifier, typeName: typeName, isImplicit: isImplicit)
		case let .classDeclaration(className: name, inherits: inherits, members: members):
			return replaceClassDeclaration(name: name, inherits: inherits, members: members)
		case let .companionObject(members: members):
			return replaceCompanionObject(members: members)
		case let .enumDeclaration(
			access: access,
			enumName: enumName,
			inherits: inherits,
			elements: elements,
			members: members,
			isImplicit: isImplicit):

			return replaceEnumDeclaration(
				access: access, enumName: enumName, inherits: inherits, elements: elements,
				members: members, isImplicit: isImplicit)
		case let .protocolDeclaration(protocolName: protocolName, members: members):
			return replaceProtocolDeclaration(protocolName: protocolName, members: members)
		case let .structDeclaration(
			annotations: annotations, structName: structName, inherits: inherits, members: members):

			return replaceStructDeclaration(
				annotations: annotations,
				structName: structName,
				inherits: inherits,
				members: members)
		case let .functionDeclaration(data: functionDeclaration):
			return replaceFunctionDeclaration(functionDeclaration)
		case let .variableDeclaration(data: variableDeclaration):

			return replaceVariableDeclaration(variableDeclaration)

		case let .doStatement(statements: statements):
			return replaceDoStatement(statements: statements)
		case let .catchStatement(variableDeclaration: variableDeclaration, statements: statements):
			return replaceCatchStatement(
				variableDeclaration: variableDeclaration,
				statements: statements)
		case let .forEachStatement(
			collection: collection, variable: variable, statements: statements):

			return replaceForEachStatement(
				collection: collection, variable: variable, statements: statements)
		case let .whileStatement(expression: expression, statements: statements):
			return replaceWhileStatement(expression: expression, statements: statements)
		case let .ifStatement(data: ifStatement):
			return replaceIfStatement(ifStatement)
		case let .switchStatement(
			convertsToExpression: convertsToExpression, expression: expression, cases: cases):

			return replaceSwitchStatement(
				convertsToExpression: convertsToExpression, expression: expression, cases: cases)
		case let .deferStatement(statements: statements):
			return replaceDeferStatement(statements: statements)
		case let .throwStatement(expression: expression):
			return replaceThrowStatement(expression: expression)
		case let .returnStatement(expression: expression):
			return replaceReturnStatement(expression: expression)
		case .breakStatement:
			return [.breakStatement]
		case .continueStatement:
			return [.continueStatement]
		case let .assignmentStatement(leftHand: leftHand, rightHand: rightHand):
			return replaceAssignmentStatement(leftHand: leftHand, rightHand: rightHand)
		case .error:
			return [.error]
		}
	}

	func replaceExpressionStatement( // annotation: open
		expression: Expression)
		-> ArrayClass<Statement>
	{
		return [.expressionStatement(expression: replaceExpression(expression))]
	}

	func replaceExtension( // annotation: open
		typeName: String,
		members: ArrayClass<Statement>)
		-> ArrayClass<Statement>
	{
		return [.extensionDeclaration(typeName: typeName, members: replaceStatements(members))]
	}

	func replaceImportDeclaration( // annotation: open
		moduleName: String)
		-> ArrayClass<Statement>
	{
		return [.importDeclaration(moduleName: moduleName)]
	}

	func replaceTypealiasDeclaration( // annotation: open
		identifier: String,
		typeName: String,
		isImplicit: Bool)
		-> ArrayClass<Statement>
	{
		return [.typealiasDeclaration(
			identifier: identifier,
			typeName: typeName,
			isImplicit: isImplicit), ]
	}

	func replaceClassDeclaration( // annotation: open
		name: String,
		inherits: ArrayClass<String>,
		members: ArrayClass<Statement>)
		-> ArrayClass<Statement>
	{
		return [.classDeclaration(
			className: name,
			inherits: inherits,
			members: replaceStatements(members)), ]
	}

	func replaceCompanionObject( // annotation: open
		members: ArrayClass<Statement>)
		-> ArrayClass<Statement>
	{
		return [.companionObject(members: replaceStatements(members))]
	}

	func replaceEnumDeclaration( // annotation: open
		access: String?,
		enumName: String,
		inherits: ArrayClass<String>,
		elements: ArrayClass<EnumElement>,
		members: ArrayClass<Statement>,
		isImplicit: Bool)
		-> ArrayClass<Statement>
	{
		return [
			.enumDeclaration(
				access: access,
				enumName: enumName,
				inherits: inherits,
				elements: elements.flatMap {
						replaceEnumElementDeclaration(
							enumName: $0.name,
							associatedValues: $0.associatedValues,
							rawValue: $0.rawValue,
							annotations: $0.annotations)
					},
				members: replaceStatements(members), isImplicit: isImplicit), ]
	}

	func replaceEnumElementDeclaration( // annotation: open
		enumName: String,
		associatedValues: ArrayClass<LabeledType>,
		rawValue: Expression?,
		annotations: String?)
		-> ArrayClass<EnumElement>
	{
		return [EnumElement(
			name: enumName,
			associatedValues: associatedValues,
			rawValue: rawValue,
			annotations: annotations), ]
	}

	func replaceProtocolDeclaration( // annotation: open
		protocolName: String,
		members: ArrayClass<Statement>)
		-> ArrayClass<Statement>
	{
		return [.protocolDeclaration(
			protocolName: protocolName,
			members: replaceStatements(members)), ]
	}

	func replaceStructDeclaration( // annotation: open
		annotations: String?,
		structName: String,
		inherits: ArrayClass<String>,
		members: ArrayClass<Statement>)
		-> ArrayClass<Statement>
	{
		return [.structDeclaration(
			annotations: annotations,
			structName: structName,
			inherits: inherits,
			members: replaceStatements(members)), ]
	}

	func replaceFunctionDeclaration( // annotation: open
		_ functionDeclaration: FunctionDeclarationData)
		-> ArrayClass<Statement>
	{
		if let result = replaceFunctionDeclarationData(functionDeclaration) {
			return [.functionDeclaration(data: result)]
		}
		else {
			return []
		}
	}

	func replaceFunctionDeclarationData( // annotation: open
		_ functionDeclaration: FunctionDeclarationData)
		-> FunctionDeclarationData?
	{
		let replacedParameters = functionDeclaration.parameters
			.map {
				FunctionParameter(
					label: $0.label,
					apiLabel: $0.apiLabel,
					typeName: $0.typeName,
					value: $0.value.map { replaceExpression($0) })
			}

		let functionDeclaration = functionDeclaration
		functionDeclaration.parameters = replacedParameters
		functionDeclaration.statements =
			functionDeclaration.statements.map { replaceStatements($0) }
		return functionDeclaration
	}

	func replaceVariableDeclaration( // annotation: open
		_ variableDeclaration: VariableDeclarationData)
		-> ArrayClass<Statement>
	{
		return [.variableDeclaration(data: replaceVariableDeclarationData(variableDeclaration))]
	}

	func replaceVariableDeclarationData( // annotation: open
		_ variableDeclaration: VariableDeclarationData)
		-> VariableDeclarationData
	{
		let variableDeclaration = variableDeclaration
		variableDeclaration.expression =
			variableDeclaration.expression.map { replaceExpression($0) }
		if let getter = variableDeclaration.getter {
			variableDeclaration.getter = replaceFunctionDeclarationData(getter)
		}
		if let setter = variableDeclaration.setter {
			variableDeclaration.setter = replaceFunctionDeclarationData(setter)
		}
		return variableDeclaration
	}

	func replaceDoStatement( // annotation: open
		statements: ArrayClass<Statement>)
		-> ArrayClass<Statement>
	{
		return [.doStatement(statements: replaceStatements(statements))]
	}

	func replaceCatchStatement( // annotation: open
		variableDeclaration: VariableDeclarationData?,
		statements: ArrayClass<Statement>)
		-> ArrayClass<Statement>
	{
		return [.catchStatement(
			variableDeclaration: variableDeclaration.map { replaceVariableDeclarationData($0) },
			statements: replaceStatements(statements)),
		]
	}

	func replaceForEachStatement( // annotation: open
		collection: Expression, variable: Expression, statements: ArrayClass<Statement>)
		-> ArrayClass<Statement>
	{
		return [.forEachStatement(
			collection: replaceExpression(collection),
			variable: replaceExpression(variable),
			statements: replaceStatements(statements)), ]
	}

	func replaceWhileStatement( // annotation: open
		expression: Expression,
		statements: ArrayClass<Statement>)
		-> ArrayClass<Statement>
	{
		return [.whileStatement(
			expression: replaceExpression(expression),
			statements: replaceStatements(statements)), ]
	}

	func replaceIfStatement( // annotation: open
		_ ifStatement: IfStatementData)
		-> ArrayClass<Statement>
	{
		return [Statement.ifStatement(data: replaceIfStatementData(ifStatement))]
	}

	func replaceIfStatementData( // annotation: open
		_ ifStatement: IfStatementData)
		-> IfStatementData
	{
		let ifStatement = ifStatement
		ifStatement.conditions = replaceIfConditions(ifStatement.conditions)
		ifStatement.declarations =
			ifStatement.declarations.map { replaceVariableDeclarationData($0) }
		ifStatement.statements = replaceStatements(ifStatement.statements)
		ifStatement.elseStatement = ifStatement.elseStatement.map { replaceIfStatementData($0) }
		return ifStatement
	}

	func replaceIfConditions( // annotation: open
		_ conditions: ArrayClass<IfStatementData.IfCondition>)
		-> ArrayClass<IfStatementData.IfCondition>
	{
		return conditions.map { replaceIfCondition($0) }
	}

	func replaceIfCondition( // annotation: open
		_ condition: IfStatementData.IfCondition)
		-> IfStatementData.IfCondition
	{
		switch condition {
		case let .condition(expression: expression):
			return .condition(expression: replaceExpression(expression))
		case let .declaration(variableDeclaration: variableDeclaration):
			return .declaration(
				variableDeclaration: replaceVariableDeclarationData(variableDeclaration))
		}
	}

	func replaceSwitchStatement( // annotation: open
		convertsToExpression: Statement?, expression: Expression,
		cases: ArrayClass<SwitchCase>) -> ArrayClass<Statement>
	{
		let replacedConvertsToExpression: Statement?
		if let convertsToExpression = convertsToExpression {
			if let replacedExpression = replaceStatement(convertsToExpression).first {
				replacedConvertsToExpression = replacedExpression
			}
			else {
				replacedConvertsToExpression = nil
			}
		}
		else {
			replacedConvertsToExpression = nil
		}

		let replacedCases = cases.map
			{
				SwitchCase(
					expressions: $0.expressions.map { replaceExpression($0) },
					statements: replaceStatements($0.statements))
			}

		return [.switchStatement(
			convertsToExpression: replacedConvertsToExpression,
			expression: replaceExpression(expression),
			cases: replacedCases), ]
	}

	func replaceDeferStatement( // annotation: open
		statements: ArrayClass<Statement>)
		-> ArrayClass<Statement>
	{
		return [.deferStatement(statements: replaceStatements(statements))]
	}

	func replaceThrowStatement( // annotation: open
		expression: Expression)
		-> ArrayClass<Statement>
	{
		return [.throwStatement(expression: replaceExpression(expression))]
	}

	func replaceReturnStatement( // annotation: open
		expression: Expression?)
		-> ArrayClass<Statement>
	{
		return [.returnStatement(expression: expression.map { replaceExpression($0) })]
	}

	func replaceAssignmentStatement( // annotation: open
		leftHand: Expression,
		rightHand: Expression)
		-> ArrayClass<Statement>
	{
		return [.assignmentStatement(
			leftHand: replaceExpression(leftHand), rightHand: replaceExpression(rightHand)), ]
	}

	func replaceExpression( // annotation: open
		_ expression: Expression)
		-> Expression
	{
		parents.append(.expressionNode(value: expression))
		defer { parents.removeLast() }

		switch expression {
		case let .templateExpression(pattern: pattern, matches: matches):
			return replaceTemplateExpression(pattern: pattern, matches: matches)
		case let .literalCodeExpression(string: string):
			return replaceLiteralCodeExpression(string: string)
		case let .literalDeclarationExpression(string: string):
			return replaceLiteralCodeExpression(string: string)
		case let .parenthesesExpression(expression: expression):
			return replaceParenthesesExpression(expression: expression)
		case let .forceValueExpression(expression: expression):
			return replaceForceValueExpression(expression: expression)
		case let .optionalExpression(expression: expression):
			return replaceOptionalExpression(expression: expression)
		case let .declarationReferenceExpression(data: declarationReferenceExpression):
			return replaceDeclarationReferenceExpression(declarationReferenceExpression)
		case let .typeExpression(typeName: typeName):
			return replaceTypeExpression(typeName: typeName)
		case let .subscriptExpression(
			subscriptedExpression: subscriptedExpression, indexExpression: indexExpression,
			typeName: typeName):

			return replaceSubscriptExpression(
				subscriptedExpression: subscriptedExpression, indexExpression: indexExpression,
				typeName: typeName)
		case let .arrayExpression(elements: elements, typeName: typeName):
			return replaceArrayExpression(elements: elements, typeName: typeName)
		case let .dictionaryExpression(keys: keys, values: values, typeName: typeName):
			return replaceDictionaryExpression(keys: keys, values: values, typeName: typeName)
		case let .returnExpression(expression: innerExpression):
			return replaceReturnExpression(innerExpression: innerExpression)
		case let .dotExpression(leftExpression: leftExpression, rightExpression: rightExpression):
			return replaceDotExpression(
				leftExpression: leftExpression, rightExpression: rightExpression)
		case let .binaryOperatorExpression(
			leftExpression: leftExpression, rightExpression: rightExpression,
			operatorSymbol: operatorSymbol, typeName: typeName):

			return replaceBinaryOperatorExpression(
				leftExpression: leftExpression, rightExpression: rightExpression,
				operatorSymbol: operatorSymbol, typeName: typeName)
		case let .prefixUnaryExpression(
			subExpression: subExpression, operatorSymbol: operatorSymbol, typeName: typeName):

			return replacePrefixUnaryExpression(
				subExpression: subExpression, operatorSymbol: operatorSymbol, typeName: typeName)
		case let .postfixUnaryExpression(
			subExpression: subExpression, operatorSymbol: operatorSymbol, typeName: typeName):

			return replacePostfixUnaryExpression(
				subExpression: subExpression, operatorSymbol: operatorSymbol, typeName: typeName)
		case let .ifExpression(
			condition: condition, trueExpression: trueExpression, falseExpression: falseExpression):

			return replaceIfExpression(
				condition: condition,
				trueExpression: trueExpression,
				falseExpression: falseExpression)
		case let .callExpression(data: callExpression):
			return replaceCallExpression(callExpression)
		case let .closureExpression(parameters: parameters, statements: statements, typeName: typeName):
			return replaceClosureExpression(
				parameters: parameters, statements: statements, typeName: typeName)
		case let .literalIntExpression(value: value):
			return replaceLiteralIntExpression(value: value)
		case let .literalUIntExpression(value: value):
			return replaceLiteralUIntExpression(value: value)
		case let .literalDoubleExpression(value: value):
			return replaceLiteralDoubleExpression(value: value)
		case let .literalFloatExpression(value: value):
			return replaceLiteralFloatExpression(value: value)
		case let .literalBoolExpression(value: value):
			return replaceLiteralBoolExpression(value: value)
		case let .literalStringExpression(value: value):
			return replaceLiteralStringExpression(value: value)
		case let .literalCharacterExpression(value: value):
			return replaceLiteralCharacterExpression(value: value)
		case .nilLiteralExpression:
			return replaceNilLiteralExpression()
		case let .interpolatedStringLiteralExpression(expressions: expressions):
			return replaceInterpolatedStringLiteralExpression(expressions: expressions)
		case let .tupleExpression(pairs: pairs):
			return replaceTupleExpression(pairs: pairs)
		case let .tupleShuffleExpression(
			labels: labels, indices: indices, expressions: expressions):

			return replaceTupleShuffleExpression(
				labels: labels, indices: indices, expressions: expressions)
		case .error:
			return .error
		}
	}

	func replaceTemplateExpression( // annotation: open
		pattern: String,
		matches: DictionaryClass<String, Expression>)
		-> Expression
	{
		let newMatches = matches.mapValues { replaceExpression($0) } // kotlin: ignore
		// insert: val newMatches = matches.mapValues { replaceExpression(it.value) }.toMutableMap()

		return .templateExpression(
			pattern: pattern,
			matches: newMatches)
	}

	func replaceLiteralCodeExpression( // annotation: open
		string: String)
		-> Expression
	{
		return .literalCodeExpression(string: string)
	}

	func replaceParenthesesExpression( // annotation: open
		expression: Expression)
		-> Expression
	{
		return .parenthesesExpression(expression: replaceExpression(expression))
	}

	func replaceForceValueExpression( // annotation: open
		expression: Expression)
		-> Expression
	{
		return .forceValueExpression(expression: replaceExpression(expression))
	}

	func replaceOptionalExpression( // annotation: open
		expression: Expression)
		-> Expression
	{
		return .optionalExpression(expression: replaceExpression(expression))
	}

	func replaceDeclarationReferenceExpression( // annotation: open
		_ declarationReferenceExpression: DeclarationReferenceData)
		-> Expression
	{
		return .declarationReferenceExpression(
			data: replaceDeclarationReferenceExpressionData(declarationReferenceExpression))
	}

	func replaceDeclarationReferenceExpressionData( // annotation: open
		_ declarationReferenceExpression: DeclarationReferenceData)
		-> DeclarationReferenceData
	{
		return declarationReferenceExpression
	}

	func replaceTypeExpression( // annotation: open
		typeName: String)
		-> Expression
	{
		return .typeExpression(typeName: typeName)
	}

	func replaceSubscriptExpression( // annotation: open
		subscriptedExpression: Expression,
		indexExpression: Expression,
		typeName: String)
		-> Expression
	{
		return .subscriptExpression(
			subscriptedExpression: replaceExpression(subscriptedExpression),
			indexExpression: replaceExpression(indexExpression), typeName: typeName)
	}

	func replaceArrayExpression( // annotation: open
		elements: ArrayClass<Expression>,
		typeName: String)
		-> Expression
	{
		return .arrayExpression(
			elements: elements.map { replaceExpression($0) },
			typeName: typeName)
	}

	func replaceDictionaryExpression( // annotation: open
		keys: ArrayClass<Expression>,
		values: ArrayClass<Expression>,
		typeName: String)
		-> Expression
	{
		return .dictionaryExpression(keys: keys, values: values, typeName: typeName)
	}

	func replaceReturnExpression( // annotation: open
		innerExpression: Expression?)
		-> Expression
	{
		return .returnExpression(expression: innerExpression.map { replaceExpression($0) })
	}

	func replaceDotExpression( // annotation: open
		leftExpression: Expression,
		rightExpression: Expression)
		-> Expression
	{
		return .dotExpression(
			leftExpression: replaceExpression(leftExpression),
			rightExpression: replaceExpression(rightExpression))
	}

	func replaceBinaryOperatorExpression( // annotation: open
		leftExpression: Expression,
		rightExpression: Expression,
		operatorSymbol: String,
		typeName: String) -> Expression
	{
		return .binaryOperatorExpression(
			leftExpression: replaceExpression(leftExpression),
			rightExpression: replaceExpression(rightExpression),
			operatorSymbol: operatorSymbol,
			typeName: typeName)
	}

	func replacePrefixUnaryExpression( // annotation: open
		subExpression: Expression,
		operatorSymbol: String,
		typeName: String)
		-> Expression
	{
		return .prefixUnaryExpression(
			subExpression: replaceExpression(subExpression),
			operatorSymbol: operatorSymbol,
			typeName: typeName)
	}

	func replacePostfixUnaryExpression( // annotation: open
		subExpression: Expression,
		operatorSymbol: String,
		typeName: String)
		-> Expression
	{
		return .postfixUnaryExpression(
			subExpression: replaceExpression(subExpression),
			operatorSymbol: operatorSymbol,
			typeName: typeName)
	}

	func replaceIfExpression( // annotation: open
		condition: Expression,
		trueExpression: Expression,
		falseExpression: Expression)
		-> Expression
	{
		return .ifExpression(
			condition: replaceExpression(condition),
			trueExpression: replaceExpression(trueExpression),
			falseExpression: replaceExpression(falseExpression))
	}

	func replaceCallExpression( // annotation: open
		_ callExpression: CallExpressionData)
		-> Expression
	{
		return .callExpression(data: replaceCallExpressionData(callExpression))
	}

	func replaceCallExpressionData( // annotation: open
		_ callExpression: CallExpressionData)
		-> CallExpressionData
	{
		return CallExpressionData(
			function: replaceExpression(callExpression.function),
			parameters: replaceExpression(callExpression.parameters),
			typeName: callExpression.typeName,
			range: callExpression.range)
	}

	func replaceClosureExpression( // annotation: open
		parameters: ArrayClass<LabeledType>,
		statements: ArrayClass<Statement>,
		typeName: String)
		-> Expression
	{
		return .closureExpression(
			parameters: parameters,
			statements: replaceStatements(statements),
			typeName: typeName)
	}

	func replaceLiteralIntExpression(value: Int64) -> Expression { // annotation: open
		return .literalIntExpression(value: value)
	}

	func replaceLiteralUIntExpression(value: UInt64) -> Expression { // annotation: open
		return .literalUIntExpression(value: value)
	}

	func replaceLiteralDoubleExpression(value: Double) -> Expression { // annotation: open
		return .literalDoubleExpression(value: value)
	}

	func replaceLiteralFloatExpression(value: Float) -> Expression { // annotation: open
		return .literalFloatExpression(value: value)
	}

	func replaceLiteralBoolExpression(value: Bool) -> Expression { // annotation: open
		return .literalBoolExpression(value: value)
	}

	func replaceLiteralStringExpression(value: String) -> Expression { // annotation: open
		return .literalStringExpression(value: value)
	}

	func replaceLiteralCharacterExpression(value: String) -> Expression { // annotation: open
		return .literalCharacterExpression(value: value)
	}

	func replaceNilLiteralExpression() -> Expression { // annotation: open
		return .nilLiteralExpression
	}

	func replaceInterpolatedStringLiteralExpression( // annotation: open
		expressions: ArrayClass<Expression>)
		-> Expression
	{
		return .interpolatedStringLiteralExpression(
			expressions: expressions.map { replaceExpression($0) })
	}

	func replaceTupleExpression( // annotation: open
		pairs: ArrayClass<LabeledExpression>)
		-> Expression
	{
		return .tupleExpression( pairs: pairs.map {
			LabeledExpression(label: $0.label, expression: replaceExpression($0.expression))
		})
	}

	func replaceTupleShuffleExpression( // annotation: open
		labels: ArrayClass<String>,
		indices: ArrayClass<TupleShuffleIndex>,
		expressions: ArrayClass<Expression>)
		-> Expression
	{
		return .tupleShuffleExpression(
			labels: labels,
			indices: indices,
			expressions: expressions.map { replaceExpression($0) })
	}
}

public class DescriptionAsToStringTranspilationPass: TranspilationPass {
	// declaration: constructor(ast: GryphonAST): super(ast) { }

	override func replaceVariableDeclaration( // annotation: override
		_ variableDeclaration: VariableDeclarationData)
		-> ArrayClass<Statement>
	{
		if variableDeclaration.identifier == "description",
			variableDeclaration.typeName == "String",
			let getter = variableDeclaration.getter
		{
			return [.functionDeclaration(data: FunctionDeclarationData(
				prefix: "toString",
				parameters: [],
				returnType: "String",
				functionType: "() -> String",
				genericTypes: [],
				isImplicit: false,
				isStatic: false,
				isMutating: false,
				isPure: false,
				extendsType: variableDeclaration.extendsType,
				statements: getter.statements,
				access: nil,
				annotations: variableDeclaration.annotations)), ]
		}

		return super.replaceVariableDeclaration(variableDeclaration)
	}
}

public class RemoveParenthesesTranspilationPass: TranspilationPass {
	// declaration: constructor(ast: GryphonAST): super(ast) { }

	override func replaceSubscriptExpression( // annotation: override
		subscriptedExpression: Expression,
		indexExpression: Expression,
		typeName: String)
		-> Expression
	{
		if case let .parenthesesExpression(expression: innerExpression) = indexExpression {
			return super.replaceSubscriptExpression(
				subscriptedExpression: subscriptedExpression,
				indexExpression: innerExpression,
				typeName: typeName)
		}

		return super.replaceSubscriptExpression(
			subscriptedExpression: subscriptedExpression,
			indexExpression: indexExpression,
			typeName: typeName)
	}

	override func replaceParenthesesExpression( // annotation: override
		expression: Expression)
		-> Expression
	{
		let myParent = self.parent
		if case let .expressionNode(parentExpression) = myParent {
			switch parentExpression {
			case .tupleExpression, .interpolatedStringLiteralExpression:
				return replaceExpression(expression)
			default:
				break
			}
		}

		return .parenthesesExpression(expression: replaceExpression(expression))
	}

	override func replaceIfExpression( // annotation: override
		condition: Expression,
		trueExpression: Expression,
		falseExpression: Expression)
		-> Expression
	{
		let replacedCondition: Expression
		if case let .parenthesesExpression(expression: innerExpression) = condition {
			replacedCondition = innerExpression
		}
		else {
			replacedCondition = condition
		}

		let replacedTrueExpression: Expression
		if case let .parenthesesExpression(expression: innerExpression) = trueExpression {
			replacedTrueExpression = innerExpression
		}
		else {
			replacedTrueExpression = trueExpression
		}

		let replacedFalseExpression: Expression
		if case let .parenthesesExpression(expression: innerExpression) = falseExpression {
			replacedFalseExpression = innerExpression
		}
		else {
			replacedFalseExpression = falseExpression
		}

		return .ifExpression(
			condition: replacedCondition,
			trueExpression: replacedTrueExpression,
			falseExpression: replacedFalseExpression)
	}
}

/// Removes implicit declarations so that they don't show up on the translation
public class RemoveImplicitDeclarationsTranspilationPass: TranspilationPass {
	// declaration: constructor(ast: GryphonAST): super(ast) { }

	override func replaceEnumDeclaration( // annotation: override
		access: String?,
		enumName: String,
		inherits: ArrayClass<String>,
		elements: ArrayClass<EnumElement>,
		members: ArrayClass<Statement>,
		isImplicit: Bool)
		-> ArrayClass<Statement>
	{
		if isImplicit {
			return []
		}
		else {
			return super.replaceEnumDeclaration(
				access: access,
				enumName: enumName,
				inherits: inherits,
				elements: elements,
				members: members,
				isImplicit: isImplicit)
		}
	}

	override func replaceTypealiasDeclaration( // annotation: override
		identifier: String,
		typeName: String,
		isImplicit: Bool)
		-> ArrayClass<Statement>
	{
		if isImplicit {
			return []
		}
		else {
			return super.replaceTypealiasDeclaration(
				identifier: identifier, typeName: typeName, isImplicit: isImplicit)
		}
	}

	override func replaceVariableDeclaration( // annotation: override
		_ variableDeclaration: VariableDeclarationData)
		-> ArrayClass<Statement>
	{
		if variableDeclaration.isImplicit {
			return []
		}
		else {
			return super.replaceVariableDeclaration(variableDeclaration)
		}
	}

	override func replaceFunctionDeclarationData( // annotation: override
		_ functionDeclaration: FunctionDeclarationData)
		-> FunctionDeclarationData?
	{
		if functionDeclaration.isImplicit {
			return nil
		}
		else {
			return super.replaceFunctionDeclarationData(functionDeclaration)
		}
	}
}

/// Optional initializers can be translated as `invoke` operators to have similar syntax and
/// functionality.
public class OptionalInitsTranspilationPass: TranspilationPass {
	// declaration: constructor(ast: GryphonAST): super(ast) { }

	private var isFailableInitializer: Bool = false

	override func replaceFunctionDeclarationData( // annotation: override
		_ functionDeclaration: FunctionDeclarationData)
		-> FunctionDeclarationData?
	{
		if functionDeclaration.isStatic == true,
			functionDeclaration.extendsType == nil,
			functionDeclaration.prefix == "init"
		{
			if functionDeclaration.returnType.hasSuffix("?") {
				let functionDeclaration = functionDeclaration

				isFailableInitializer = true
				let newStatements = replaceStatements(functionDeclaration.statements ?? [])
				isFailableInitializer = false

				functionDeclaration.prefix = "invoke"
				functionDeclaration.statements = newStatements
				return functionDeclaration
			}
		}

		return super.replaceFunctionDeclarationData(functionDeclaration)
	}

	override func replaceAssignmentStatement( // annotation: override
		leftHand: Expression,
		rightHand: Expression)
		-> ArrayClass<Statement>
	{
		if isFailableInitializer,
			case let .declarationReferenceExpression(data: expression) = leftHand
		{
			if expression.identifier == "self" {
				return [.returnStatement(expression: rightHand)]
			}
		}

		return super.replaceAssignmentStatement(leftHand: leftHand, rightHand: rightHand)
	}
}

public class RemoveExtraReturnsInInitsTranspilationPass: TranspilationPass {
	// declaration: constructor(ast: GryphonAST): super(ast) { }

	override func replaceFunctionDeclarationData( // annotation: override
		_ functionDeclaration: FunctionDeclarationData)
		-> FunctionDeclarationData?
	{
		if functionDeclaration.isStatic == true,
			functionDeclaration.extendsType == nil,
			functionDeclaration.prefix == "init",
			let lastStatement = functionDeclaration.statements?.last,
			case .returnStatement(expression: nil) = lastStatement
		{
			let functionDeclaration = functionDeclaration
			functionDeclaration.statements?.removeLast()
			return functionDeclaration
		}

		return functionDeclaration
	}
}

/// The static functions and variables in a class must all be placed inside a single companion
/// object.
public class StaticMembersTranspilationPass: TranspilationPass {
	// declaration: constructor(ast: GryphonAST): super(ast) { }

	private func sendStaticMembersToCompanionObject(
		_ members: ArrayClass<Statement>)
		-> ArrayClass<Statement>
	{
		let isStaticMember = { (member: Statement) -> Bool in
			if case let .functionDeclaration(data: functionDeclaration) = member {
				if functionDeclaration.isStatic == true,
					functionDeclaration.extendsType == nil,
					functionDeclaration.prefix != "init"
				{
					return true
				}
			}

			if case let .variableDeclaration(data: variableDeclaration) = member {
				if variableDeclaration.isStatic {
					return true
				}
			}

			return false
		}

		let staticMembers = members.filter { isStaticMember($0) }

		guard !staticMembers.isEmpty else {
			return members
		}

		let nonStaticMembers = members.filter { !isStaticMember($0) }

		let newMembers = ArrayClass<Statement>([.companionObject(members: staticMembers)])
		newMembers.append(contentsOf: nonStaticMembers)

		return newMembers
	}

	override func replaceClassDeclaration( // annotation: override
		name: String,
		inherits: ArrayClass<String>,
		members: ArrayClass<Statement>)
		-> ArrayClass<Statement>
	{
		let newMembers = sendStaticMembersToCompanionObject(members)
		return super.replaceClassDeclaration(name: name, inherits: inherits, members: newMembers)
	}

	override func replaceStructDeclaration( // annotation: override
		annotations: String?,
		structName: String,
		inherits: ArrayClass<String>,
		members: ArrayClass<Statement>)
		-> ArrayClass<Statement>
	{
		let newMembers = sendStaticMembersToCompanionObject(members)
		return super.replaceStructDeclaration(
			annotations: annotations,
			structName: structName,
			inherits: inherits,
			members: newMembers)
	}

	override func replaceEnumDeclaration( // annotation: override
		access: String?,
		enumName: String,
		inherits: ArrayClass<String>,
		elements: ArrayClass<EnumElement>,
		members: ArrayClass<Statement>,
		isImplicit: Bool)
		-> ArrayClass<Statement>
	{
		let newMembers = sendStaticMembersToCompanionObject(members)
		return super.replaceEnumDeclaration(
			access: access,
			enumName: enumName,
			inherits: inherits,
			elements: elements,
			members: newMembers,
			isImplicit: isImplicit)
	}
}

/// Removes the unnecessary prefixes for inner types.
///
/// For instance:
/// ````
/// class A {
/// 	class B { }
/// 	let x = A.B() // This becomes just B()
/// }
/// ````
public class InnerTypePrefixesTranspilationPass: TranspilationPass {
	// declaration: constructor(ast: GryphonAST): super(ast) { }

	var typeNamesStack: ArrayClass<String> = []

	func removePrefixes(_ typeName: String) -> String {
		var result = typeName
		for typeName in typeNamesStack {
			let prefix = typeName + "."
			if result.hasPrefix(prefix) {
				result = String(result.dropFirst(prefix.count))
			}
			else {
				return result
			}
		}

		return result
	}

	override func replaceClassDeclaration( // annotation: override
		name: String,
		inherits: ArrayClass<String>,
		members: ArrayClass<Statement>)
		-> ArrayClass<Statement>
	{
		typeNamesStack.append(name)
		let result = super.replaceClassDeclaration(name: name, inherits: inherits, members: members)
		typeNamesStack.removeLast()
		return result
	}

	override func replaceStructDeclaration( // annotation: override
		annotations: String?,
		structName: String,
		inherits: ArrayClass<String>,
		members: ArrayClass<Statement>)
		-> ArrayClass<Statement>
	{
		typeNamesStack.append(structName)
		let result = super.replaceStructDeclaration(
			annotations: annotations,
			structName: structName,
			inherits: inherits,
			members: members)
		typeNamesStack.removeLast()
		return result
	}

	override func replaceVariableDeclarationData( // annotation: override
		_ variableDeclaration: VariableDeclarationData)
		-> VariableDeclarationData
	{
		let variableDeclaration = variableDeclaration
		variableDeclaration.typeName = removePrefixes(variableDeclaration.typeName)
		return super.replaceVariableDeclarationData(variableDeclaration)
	}

	override func replaceTypeExpression( // annotation: override
		typeName: String)
		-> Expression
	{
		return .typeExpression(typeName: removePrefixes(typeName))
	}
}

// TODO: test
/// Capitalizes references to enums (since enum cases in Kotlin are conventionally written in
/// capitalized forms)
public class CapitalizeEnumsTranspilationPass: TranspilationPass { // kotlin: ignore
	override func replaceDotExpression(
		leftExpression: Expression, rightExpression: Expression) -> Expression
	{
		if case let .typeExpression(typeName: enumType) = leftExpression,
			case let .declarationReferenceExpression(data: enumExpression) = rightExpression
		{
			let lastEnumType = String(enumType.split(separator: ".").last!)

			if KotlinTranslator.sealedClasses.contains(lastEnumType) {
				let enumExpression = enumExpression
				enumExpression.identifier = enumExpression.identifier.capitalizedAsCamelCase()
				return .dotExpression(
					leftExpression: .typeExpression(typeName: enumType),
					rightExpression: .declarationReferenceExpression(data: enumExpression))
			}
			else if KotlinTranslator.enumClasses.contains(lastEnumType) {
				let enumExpression = enumExpression
				enumExpression.identifier = enumExpression.identifier.upperSnakeCase()
				return .dotExpression(
					leftExpression: .typeExpression(typeName: enumType),
					rightExpression: .declarationReferenceExpression(data: enumExpression))
			}
		}

		return super.replaceDotExpression(
			leftExpression: leftExpression, rightExpression: rightExpression)
	}

	override func replaceEnumDeclaration(
		access: String?,
		enumName: String,
		inherits: ArrayClass<String>,
		elements: ArrayClass<EnumElement>,
		members: ArrayClass<Statement>,
		isImplicit: Bool)
		-> ArrayClass<Statement>
	{
		let isSealedClass = KotlinTranslator.sealedClasses.contains(enumName)
		let isEnumClass = KotlinTranslator.enumClasses.contains(enumName)

		let newElements = elements.map { (element: EnumElement) -> EnumElement in
			if isSealedClass {
				return EnumElement(
					name: element.name.capitalizedAsCamelCase(),
					associatedValues: element.associatedValues,
					rawValue: element.rawValue,
					annotations: element.annotations)
			}
			else if isEnumClass {
				return EnumElement(
					name: element.name.upperSnakeCase(),
					associatedValues: element.associatedValues,
					rawValue: element.rawValue,
					annotations: element.annotations)
			}
			else {
				return element
			}
		}

		return super.replaceEnumDeclaration(
			access: access,
			enumName: enumName,
			inherits: inherits,
			elements: newElements,
			members: members,
			isImplicit: isImplicit)
	}
}

/// Some enum prefixes can be omitted. For instance, there's no need to include `MyEnum.` before
/// `ENUM_CASE` in the variable declarations or function returns below:
///
/// enum class MyEnum {
/// 	ENUM_CASE
/// }
/// var x: MyEnum = ENUM_CASE
/// fun f(): MyEnum {
/// 	ENUM_CASE
/// }
///
/// Assumes subtrees like the one below are references to enums (see also
/// CapitalizeAllEnumsTranspilationPass).
///
///	    ...
///        └─ dotExpression
///          ├─ left
///          │  └─ typeExpression
///          │     └─ MyEnum
///          └─ right
///             └─ declarationReferenceExpression
///                ├─ (MyEnum.Type) -> MyEnum
///                └─ myEnum
// TODO: test
// TODO: add support for return whens (maybe put this before the when pass)
public class OmitImplicitEnumPrefixesTranspilationPass: TranspilationPass { // kotlin: ignore
	// declaration: constructor(ast: GryphonAST): super(ast) { }

	private var returnTypesStack: ArrayClass<String> = []

	private func removePrefixFromPossibleEnumReference(
		leftExpression: Expression,
		rightExpression: Expression)
		-> Expression
	{
		if case let .typeExpression(typeName: enumType) = leftExpression,
			case let .declarationReferenceExpression(data: enumExpression) = rightExpression,
			enumExpression.typeName == "(\(enumType).Type) -> \(enumType)",
			!KotlinTranslator.sealedClasses.contains(enumType)
		{
			return .declarationReferenceExpression(data: enumExpression)
		}
		else {
			return super.replaceDotExpression(
				leftExpression: leftExpression, rightExpression: rightExpression)
		}
	}

	override func replaceFunctionDeclarationData( // annotation: override
		_ functionDeclaration: FunctionDeclarationData)
		-> FunctionDeclarationData?
	{
		returnTypesStack.append(functionDeclaration.returnType)
		defer { returnTypesStack.removeLast() }
		return super.replaceFunctionDeclarationData(functionDeclaration)
	}

	override func replaceReturnStatement( // annotation: override
		expression: Expression?)
		-> ArrayClass<Statement>
	{
		if let returnType = returnTypesStack.last,
			let expression = expression,
			case let .dotExpression(
				leftExpression: leftExpression,
				rightExpression: rightExpression) = expression
		{
			if case let .typeExpression(typeName: typeExpression) = leftExpression {
				// It's ok to omit if the return type is an optional enum too
				var returnType = returnType
				if returnType.hasSuffix("?") {
					returnType.removeLast("?".count)
				}

				if typeExpression == returnType {
					let newExpression = removePrefixFromPossibleEnumReference(
						leftExpression: leftExpression, rightExpression: rightExpression)
					return [.returnStatement(expression: newExpression)]
				}
			}
		}

		return [.returnStatement(expression: expression)]
	}
}

public class RenameOperatorsTranspilationPass: TranspilationPass {
	// declaration: constructor(ast: GryphonAST): super(ast) { }

	override func replaceBinaryOperatorExpression( // annotation: override
		leftExpression: Expression,
		rightExpression: Expression,
		operatorSymbol: String,
		typeName: String)
		-> Expression
	{
		if operatorSymbol == "??" {
			return super.replaceBinaryOperatorExpression(
				leftExpression: leftExpression,
				rightExpression: rightExpression,
				operatorSymbol: "?:",
				typeName: typeName)
		}
		else {
			return super.replaceBinaryOperatorExpression(
				leftExpression: leftExpression,
				rightExpression: rightExpression,
				operatorSymbol: operatorSymbol,
				typeName: typeName)
		}
	}
}

public class SelfToThisTranspilationPass: TranspilationPass {
	// declaration: constructor(ast: GryphonAST): super(ast) { }

	override func replaceDotExpression( // annotation: override
		leftExpression: Expression,
		rightExpression: Expression)
		-> Expression
	{
		if case let .declarationReferenceExpression(data: expression) = leftExpression {
			if expression.identifier == "self", expression.isImplicit {
				return replaceExpression(rightExpression)
			}
		}

		return .dotExpression(
			leftExpression: replaceExpression(leftExpression),
			rightExpression: replaceExpression(rightExpression))
	}

	override func replaceDeclarationReferenceExpressionData( // annotation: override
		_ expression: DeclarationReferenceData)
		-> DeclarationReferenceData
	{
		if expression.identifier == "self" {
			let expression = expression
			expression.identifier = "this"
			return expression
		}
		return super.replaceDeclarationReferenceExpressionData(expression)
	}
}

/// Declarations can't conform to Swift-only protocols like Codable and Equatable, and enums can't
/// inherit from types Strings and Ints.
public class CleanInheritancesTranspilationPass: TranspilationPass {
	// declaration: constructor(ast: GryphonAST): super(ast) { }

	private func isASwiftProtocol(_ protocolName: String) -> Bool {
		return [
			"Equatable", "Codable", "Decodable", "Encodable", "CustomStringConvertible",
			].contains(protocolName)
	}

	override func replaceEnumDeclaration( // annotation: override
		access: String?,
		enumName: String,
		inherits: ArrayClass<String>,
		elements: ArrayClass<EnumElement>,
		members: ArrayClass<Statement>,
		isImplicit: Bool)
		-> ArrayClass<Statement>
	{
		return super.replaceEnumDeclaration(
			access: access,
			enumName: enumName,
			inherits: inherits.filter {
					!isASwiftProtocol($0) && !TranspilationPass.isASwiftRawRepresentableType($0)
				},
			elements: elements,
			members: members,
			isImplicit: isImplicit)
	}

	override func replaceStructDeclaration( // annotation: override
		annotations: String?,
		structName: String,
		inherits: ArrayClass<String>,
		members: ArrayClass<Statement>)
		-> ArrayClass<Statement>
	{
		return super.replaceStructDeclaration(
			annotations: annotations,
			structName: structName,
			inherits: inherits.filter { !isASwiftProtocol($0) },
			members: members)
	}

	override func replaceClassDeclaration( // annotation: override
		name: String,
		inherits: ArrayClass<String>,
		members: ArrayClass<Statement>)
		-> ArrayClass<Statement>
	{
		return super.replaceClassDeclaration(
			name: name,
			inherits: inherits.filter { !isASwiftProtocol($0) },
			members: members)
	}
}

/// The "anonymous parameter" `$0` has to be replaced by `it`
public class AnonymousParametersTranspilationPass: TranspilationPass {
	// declaration: constructor(ast: GryphonAST): super(ast) { }

	override func replaceDeclarationReferenceExpressionData( // annotation: override
		_ expression: DeclarationReferenceData)
		-> DeclarationReferenceData
	{
		if expression.identifier == "$0" {
			let expression = expression
			expression.identifier = "it"
			return expression
		}
		else {
			return super.replaceDeclarationReferenceExpressionData(expression)
		}
	}

	override func replaceClosureExpression( // annotation: override
		parameters: ArrayClass<LabeledType>,
		statements: ArrayClass<Statement>,
		typeName: String)
		-> Expression
	{
		if parameters.count == 1,
			parameters[0].label == "$0"
		{
			return super.replaceClosureExpression(
				parameters: [], statements: statements, typeName: typeName)
		}
		else {
			return super.replaceClosureExpression(
				parameters: parameters, statements: statements, typeName: typeName)
		}
	}
}

/**
ArrayClass needs explicit initializers to account for the fact that it can't be implicitly
cast to covariant types. For instance:

````
let myIntArray: ArrayClass = [1, 2, 3]
let myAnyArray = myIntArray as ArrayClass<Any> // error
let myAnyArray = ArrayClass<Any>(myIntArray) // OK
````

This transformation can't be done with the current template mode because there's no way to get
the type for the cast. However, since this seems to be a specific case that only shows up in the
stdlib at the moment, this pass should serve as a workaround.

The conversion is done by calling `array.toMutableList<Element>()` rather than a normal class. This
allows translations to cover a few (not fully understood) corner cases where the array isn't a
`MutableList` (it happened once with an `EmptyList`), meaning a normal cast would fail.
*/
public class CovarianceInitsAsCallsTranspilationPass: TranspilationPass {
	// declaration: constructor(ast: GryphonAST): super(ast) { }

	override func replaceCallExpression( // annotation: override
		_ callExpression: CallExpressionData)
		-> Expression
	{
		if case let .typeExpression(typeName: typeName) = callExpression.function,
			case let .tupleExpression(pairs: pairs) = callExpression.parameters
		{
			if typeName.hasPrefix("ArrayClass<"),
				pairs.count == 1,
				let onlyPair = pairs.first
			{
				let arrayClassElementType = String(typeName.dropFirst("ArrayClass<".count).dropLast())
				let mappedElementType = Utilities.getTypeMapping(for: arrayClassElementType) ??
					arrayClassElementType

				if onlyPair.label == "array" {
					// If we're initializing with an Array of a different type, we might need to call
					// `toMutableList`
					if let arrayType = onlyPair.expression.swiftType {
						let arrayElementType = arrayType.dropFirst().dropLast()

						if arrayElementType != arrayClassElementType {
							return .dotExpression(
								leftExpression: replaceExpression(onlyPair.expression),
								rightExpression: .callExpression(data: CallExpressionData(
									function: .declarationReferenceExpression(data:
										DeclarationReferenceData(
											identifier: "toMutableList<\(mappedElementType)>",
											typeName: typeName,
											isStandardLibrary: false,
											isImplicit: false,
											range: nil)),
									parameters: .tupleExpression(pairs: []),
									typeName: typeName,
									range: nil)))
						}
					}
					// If it's an Array of the same type, just return the array itself
					return replaceExpression(onlyPair.expression)
				}
				else {
					return .dotExpression(
						leftExpression: replaceExpression(onlyPair.expression),
						rightExpression: .callExpression(data: CallExpressionData(
							function: .declarationReferenceExpression(data:
								DeclarationReferenceData(
									identifier: "toMutableList<\(mappedElementType)>",
									typeName: typeName,
									isStandardLibrary: false,
									isImplicit: false,
									range: nil)),
							parameters: .tupleExpression(pairs: []),
							typeName: typeName,
							range: nil)))
				}
			}
		}

		if case let .dotExpression(
				leftExpression: leftExpression,
				rightExpression: rightExpression) = callExpression.function
		{
			if let leftType = leftExpression.swiftType,
				leftType.hasPrefix("ArrayClass"),
				case let .declarationReferenceExpression(
					data: declarationReferenceExpression) = rightExpression,
				case let .tupleExpression(pairs: pairs) = callExpression.parameters
			{
				if declarationReferenceExpression.identifier == "as",
					pairs.count == 1,
					let onlyPair = pairs.first,
					case let .typeExpression(typeName: typeName) = onlyPair.expression
				{
					return .binaryOperatorExpression(
						leftExpression: leftExpression,
						rightExpression: .typeExpression(typeName: typeName),
						operatorSymbol: "as?",
						typeName: typeName + "?")
				}
			}
		}

		return super.replaceCallExpression(callExpression)
	}
}

/// Closures in kotlin can't have normal "return" statements. Instead, they must have return@f
/// statements (not yet implemented) or just standalone expressions (easier to implement but more
/// error-prone). This pass turns return statements in closures into standalone expressions
public class ReturnsInLambdasTranspilationPass: TranspilationPass {
	// declaration: constructor(ast: GryphonAST): super(ast) { }

	var isInClosure = false

	override func replaceClosureExpression( // annotation: override
		parameters: ArrayClass<LabeledType>,
		statements: ArrayClass<Statement>,
		typeName: String)
		-> Expression
	{
		isInClosure = true
		defer { isInClosure = false }
		return super.replaceClosureExpression(
			parameters: parameters, statements: statements, typeName: typeName)
	}

	override func replaceReturnStatement( // annotation: override
		expression: Expression?)
		-> ArrayClass<Statement>
	{
		if isInClosure, let expression = expression {
			return [.expressionStatement(expression: expression)]
		}
		else {
			return [.returnStatement(expression: expression)]
		}
	}
}

/// Optional subscripts in kotlin have to be refactored as function calls:
///
/// ````
/// let array: [Int]? = [1, 2, 3]
/// array?[0] // Becomes `array?.get(0)` in Kotlin
/// ````
public class RefactorOptionalsInSubscriptsTranspilationPass: TranspilationPass {
	// declaration: constructor(ast: GryphonAST): super(ast) { }

	override func replaceSubscriptExpression( // annotation: override
		subscriptedExpression: Expression,
		indexExpression: Expression,
		typeName: String)
		-> Expression
	{
		if case .optionalExpression = subscriptedExpression {
			return replaceDotExpression(
				leftExpression: subscriptedExpression,
				rightExpression: .callExpression(data: CallExpressionData(
					function: .declarationReferenceExpression(data: DeclarationReferenceData(
						identifier: "get",
						typeName: "(\(indexExpression.swiftType ?? "<<Error>>")) -> \(typeName)",
						isStandardLibrary: false,
						isImplicit: false,
						range: subscriptedExpression.range)),
					parameters: .tupleExpression(pairs:
						[LabeledExpression(label: nil, expression: indexExpression)]),
					typeName: typeName,
					range: subscriptedExpression.range)))
		}
		else {
			return super.replaceSubscriptExpression(
				subscriptedExpression: subscriptedExpression,
				indexExpression: indexExpression,
				typeName: typeName)
		}
	}
}

/// Optional chaining in Kotlin must continue down the dot syntax chain.
///
/// ````
/// foo?.bar.baz
/// // Becomes
/// foo?.bar?.baz
/// ````
public class AddOptionalsInDotChainsTranspilationPass: TranspilationPass {
	// declaration: constructor(ast: GryphonAST): super(ast) { }

	override func replaceDotExpression( // annotation: override
		leftExpression: Expression,
		rightExpression: Expression)
		-> Expression
	{
		if case .optionalExpression = rightExpression {
		}
		else if case let .dotExpression(
			leftExpression: innerLeftExpression,
			rightExpression: innerRightExpression) = leftExpression
		{
			if dotExpressionChainHasOptionals(innerLeftExpression) {
				return .dotExpression(
					leftExpression: addOptionalsToDotExpressionChain(
						leftExpression: innerLeftExpression,
						rightExpression: innerRightExpression),
					rightExpression: rightExpression)
			}
		}

		return super.replaceDotExpression(
			leftExpression: leftExpression,
			rightExpression: rightExpression)
	}

	func addOptionalsToDotExpressionChain(
		leftExpression: Expression,
		rightExpression: Expression)
		-> Expression
	{
		if case .optionalExpression = rightExpression {
		}
		else if dotExpressionChainHasOptionals(leftExpression) {

			let processedLeftExpression: Expression
			if case let .dotExpression(
				leftExpression: innerLeftExpression,
				rightExpression: innerRightExpression) = leftExpression
			{
				processedLeftExpression = addOptionalsToDotExpressionChain(
					leftExpression: innerLeftExpression,
					rightExpression: innerRightExpression)
			}
			else {
				processedLeftExpression = leftExpression
			}

			return addOptionalsToDotExpressionChain(
				leftExpression: processedLeftExpression,
				rightExpression: .optionalExpression(expression: rightExpression))
		}

		return super.replaceDotExpression(
			leftExpression: leftExpression,
			rightExpression: rightExpression)
	}

	private func dotExpressionChainHasOptionals(_ expression: Expression) -> Bool {
		if case .optionalExpression = expression {
			return true
		}
		else if case let .dotExpression(
			leftExpression: leftExpression, rightExpression: _) = expression
		{
			return dotExpressionChainHasOptionals(leftExpression)
		}
		else {
			return false
		}
	}
}

/// When statements in Kotlin can be used as expressions, for instance in return statements or in
/// assignments. This pass turns switch statements whose bodies all end in the same return or
/// assignment into those expressions. It also turns a variable declaration followed by a switch
/// statement that assigns to that variable into a single variable declaration with the switch
/// statement as its expression.
///
/// An ideal conversion would somehow check if the last expressions in a switch were similar in a
/// more generic way, thus allowing this conversion to happen (for instance) inside the parameter of
/// a function call. However, that would be much more complicated and it's not clear that it would
/// be desirable.
public class SwitchesToExpressionsTranspilationPass: TranspilationPass {
	// declaration: constructor(ast: GryphonAST): super(ast) { }

	/// Detect switches whose bodies all end in the same returns or assignments
	override func replaceSwitchStatement( // annotation: override
		convertsToExpression: Statement?, expression: Expression,
		cases: ArrayClass<SwitchCase>) -> ArrayClass<Statement>
	{
		var hasAllReturnCases = true
		var hasAllAssignmentCases = true
		var assignmentExpression: Expression?

		for statements in cases.map({ $0.statements }) {
			// TODO: breaks in switches are ignored, which will be incorrect if there's code after
			// the break. Throw a warning.
			guard let lastStatement = statements.last else {
				hasAllReturnCases = false
				hasAllAssignmentCases = false
				break
			}

			if case let .returnStatement(expression: expression) = lastStatement,
				expression != nil
			{
				hasAllAssignmentCases = false
				continue
			}
			else if case let .assignmentStatement(leftHand: leftHand, rightHand: _) = lastStatement
			{
				if assignmentExpression == nil || assignmentExpression == leftHand {
					hasAllReturnCases = false
					assignmentExpression = leftHand
					continue
				}
			}

			hasAllReturnCases = false
			hasAllAssignmentCases = false
			break
		}

		if hasAllReturnCases {
			let newCases: ArrayClass<SwitchCase> = []
			for switchCase in cases {
				// Swift switches must have at least one statement
				let lastStatement = switchCase.statements.last!
				if case let .returnStatement(expression: maybeExpression) = lastStatement {
					if let returnExpression = maybeExpression {
						let newStatements = ArrayClass<Statement>(switchCase.statements.dropLast())
						newStatements.append(.expressionStatement(expression: returnExpression))
						newCases.append(SwitchCase(
							expressions: switchCase.expressions,
							statements: newStatements))
					}
				}
			}
			let conversionExpression =
				Statement.returnStatement(expression: .nilLiteralExpression)
			return [.switchStatement(
				convertsToExpression: conversionExpression,
				expression: expression,
				cases: newCases), ]
		}
		else if hasAllAssignmentCases, let assignmentExpression = assignmentExpression {
			let newCases: ArrayClass<SwitchCase> = []
			for switchCase in cases {
				// Swift switches must have at least one statement
				let lastStatement = switchCase.statements.last!
				if case let .assignmentStatement(leftHand: _, rightHand: rightHand) = lastStatement
				{
					let newStatements = ArrayClass<Statement>(switchCase.statements.dropLast())
					newStatements.append(.expressionStatement(expression: rightHand))
					newCases.append(SwitchCase(
						expressions: switchCase.expressions,
						statements: newStatements))
				}
			}
			let conversionExpression = Statement.assignmentStatement(
				leftHand: assignmentExpression, rightHand: .nilLiteralExpression)
			return [.switchStatement(
				convertsToExpression: conversionExpression, expression: expression,
				cases: newCases), ]
		}
		else {
			return super.replaceSwitchStatement(
				convertsToExpression: nil, expression: expression, cases: cases)
		}
	}

	/// Replace variable declarations followed by switch statements assignments
	override func replaceStatements( // annotation: override
		_ oldStatement: ArrayClass<Statement>)
		-> ArrayClass<Statement>
	{
		let statements = super.replaceStatements(oldStatement)

		let result: ArrayClass<Statement> = []

		var i = 0
		while i < (statements.count - 1) {
			let currentStatement = statements[i]
			let nextStatement = statements[i + 1]
			if case let .variableDeclaration(data: variableDeclaration) = currentStatement,
				case let .switchStatement(
					convertsToExpression: maybeConversion,
					expression: switchExpression,
					cases: cases) = nextStatement
			{
				if variableDeclaration.isImplicit == false,
					variableDeclaration.extendsType == nil,
					let switchConversion = maybeConversion,
					case let .assignmentStatement(
						leftHand: leftHand,
						rightHand: _) = switchConversion
				{
					if case let .declarationReferenceExpression(
						data: assignmentExpression) = leftHand
					{

						if assignmentExpression.identifier == variableDeclaration.identifier,
							!assignmentExpression.isStandardLibrary,
							!assignmentExpression.isImplicit
						{
							variableDeclaration.expression = .nilLiteralExpression
							variableDeclaration.getter = nil
							variableDeclaration.setter = nil
							variableDeclaration.isStatic = false
							let newConversionExpression =
								Statement.variableDeclaration(data: variableDeclaration)
							result.append(.switchStatement(
								convertsToExpression: newConversionExpression,
								expression: switchExpression,
								cases: cases))

							// Skip appending variable declaration and the switch declaration, thus
							// replacing both with the new switch declaration
							i += 2

							continue
						}
					}
				}
			}

			result.append(currentStatement)
			i += 1
		}

		if let lastStatement = statements.last {
			result.append(lastStatement)
		}

		return result
	}
}

/// Breaks are not allowed in Kotlin `when` statements, but the `when` statements don't have to be
/// exhaustive. Just remove the cases that only have breaks.
public class RemoveBreaksInSwitchesTranspilationPass: TranspilationPass {
	// declaration: constructor(ast: GryphonAST): super(ast) { }

	override func replaceSwitchStatement( // annotation: override
		convertsToExpression: Statement?,
		expression: Expression,
		cases: ArrayClass<SwitchCase>)
		-> ArrayClass<Statement>
	{
		let newCases = cases.compactMap { removeBreaksInSwitchCase($0) }

		return super.replaceSwitchStatement(
			convertsToExpression: convertsToExpression,
			expression: expression,
			cases: newCases)
	}

	private func removeBreaksInSwitchCase(_ switchCase: SwitchCase) -> SwitchCase? {
		if switchCase.statements.count == 1,
			let onlyStatement = switchCase.statements.first,
			case .breakStatement = onlyStatement
		{
			return nil
		}
		else {
			return switchCase
		}
	}
}

/// Sealed classes should be tested for subclasses with the `is` operator. This is automatically
/// done for enum cases with associated values, but in other cases it has to be handled here.
public class IsOperatorsInSealedClassesTranspilationPass: TranspilationPass { // kotlin: ignore
	override func replaceSwitchStatement(
		convertsToExpression: Statement?,
		expression: Expression,
		cases: ArrayClass<SwitchCase>)
		-> ArrayClass<Statement>
	{
		if case let .declarationReferenceExpression(
				data: declarationReferenceExpression) = expression
		{
			if KotlinTranslator.sealedClasses.contains(declarationReferenceExpression.typeName) {
				let newCases = cases.map {
					replaceIsOperatorsInSwitchCase($0, usingExpression: expression)
				}

				return super.replaceSwitchStatement(
					convertsToExpression: convertsToExpression,
					expression: expression,
					cases: newCases)
			}
		}

		return super.replaceSwitchStatement(
			convertsToExpression: convertsToExpression,
			expression: expression,
			cases: cases)
	}

	private func replaceIsOperatorsInSwitchCase(
		_ switchCase: SwitchCase,
		usingExpression expression: Expression)
		-> SwitchCase
	{
		let newExpressions = switchCase.expressions.map
		{ (caseExpression: Expression) -> Expression in
			if case let .dotExpression(
				leftExpression: leftExpression,
				rightExpression: rightExpression) = caseExpression,
				case let .typeExpression(typeName: typeName) = leftExpression,
				case let .declarationReferenceExpression(
					data: declarationReferenceExpression) = rightExpression
			{
				return Expression.binaryOperatorExpression(
					leftExpression: expression,
					rightExpression: .typeExpression(
						typeName: "\(typeName).\(declarationReferenceExpression.identifier)"),
					operatorSymbol: "is",
					typeName: "Bool")
			}
			else {
				return caseExpression
			}
		}

		return SwitchCase(
			expressions: newExpressions,
			statements: switchCase.statements)
	}
}

public class RemoveExtensionsTranspilationPass: TranspilationPass { // kotlin: ignore
	var extendingType: String?

	override func replaceExtension(
		typeName: String,
		members: ArrayClass<Statement>)
		-> ArrayClass<Statement>
	{
		extendingType = typeName
		let members = replaceStatements(members)
		extendingType = nil
		return members
	}

	override func replaceStatement(_ statement: Statement) -> ArrayClass<Statement> {
		switch statement {
		case let .extensionDeclaration(typeName: typeName, members: members):
			return replaceExtension(typeName: typeName, members: members)
		case let .functionDeclaration(data: functionDeclaration):
			return replaceFunctionDeclaration(functionDeclaration)
		case let .variableDeclaration(data: variableDeclaration):
			return replaceVariableDeclaration(variableDeclaration)
		default:
			return [statement]
		}
	}

	override func replaceFunctionDeclaration(_ functionDeclaration: FunctionDeclarationData)
		-> ArrayClass<Statement>
	{
		let functionDeclaration = functionDeclaration
		functionDeclaration.extendsType = self.extendingType
		return [Statement.functionDeclaration(data: functionDeclaration)]
	}

	override func replaceVariableDeclarationData(_ variableDeclaration: VariableDeclarationData)
		-> VariableDeclarationData
	{
		let variableDeclaration = variableDeclaration
		variableDeclaration.extendsType = self.extendingType
		return variableDeclaration
	}
}

/// Swift functions (both declarations and calls) have to be translated using their internal
/// parameter names, not their API names. This is both for correctness and readability. Since calls
/// only contain the API names, we need a way to use the API names to retrieve the internal names.
/// KotlinTranslator has an array of "translations" exactly for this purpose: it uses the Swift
/// name (with API labels) and the type to look up the "translation" and stores the prefix and the
/// internal names it should return.
/// This pass goes through all the function declarations it finds and stores the information needed
/// to translate these functions correctly later.
///
/// It also records all functions that have been marked as pure so that they don't raise warnings
/// for possible side-effects in if-lets.
public class RecordFunctionsTranspilationPass: TranspilationPass { // kotlin: ignore
	override func replaceFunctionDeclarationData(_ functionDeclaration: FunctionDeclarationData)
		-> FunctionDeclarationData?
	{
		let swiftAPIName = functionDeclaration.prefix + "(" +
			functionDeclaration.parameters.map { ($0.apiLabel ?? "_") + ":" }.joined() + ")"

		KotlinTranslator.addFunctionTranslation(KotlinTranslator.FunctionTranslation(
			swiftAPIName: swiftAPIName,
			typeName: functionDeclaration.functionType,
			prefix: functionDeclaration.prefix,
			parameters: functionDeclaration.parameters.map { $0.label }))

		//
		if functionDeclaration.isPure {
			KotlinTranslator.recordPureFunction(functionDeclaration)
		}

		return super.replaceFunctionDeclarationData(functionDeclaration)
	}
}

public class RecordEnumsTranspilationPass: TranspilationPass { // kotlin: ignore
	override func replaceEnumDeclaration(
		access: String?,
		enumName: String,
		inherits: ArrayClass<String>,
		elements: ArrayClass<EnumElement>,
		members: ArrayClass<Statement>,
		isImplicit: Bool)
		-> ArrayClass<Statement>
	{
		let isEnumClass = inherits.isEmpty && elements.allSatisfy { $0.associatedValues.isEmpty }

		if isEnumClass {
			KotlinTranslator.addEnumClass(enumName)
		}
		else {
			KotlinTranslator.addSealedClass(enumName)
		}

		return [.enumDeclaration(
			access: access,
			enumName: enumName,
			inherits: inherits,
			elements: elements,
			members: members,
			isImplicit: isImplicit), ]
	}
}

/// Records all protocol declarations in the Kotlin Translator
public class RecordProtocolsTranspilationPass: TranspilationPass { // kotlin: ignore
	override func replaceProtocolDeclaration(
		protocolName: String,
		members: ArrayClass<Statement>)
		-> ArrayClass<Statement>
	{
		KotlinTranslator.addProtocol(protocolName)

		return super.replaceProtocolDeclaration(protocolName: protocolName, members: members)
	}
}

public class RaiseStandardLibraryWarningsTranspilationPass: TranspilationPass { // kotlin: ignore
	override func replaceDeclarationReferenceExpressionData(
		_ expression: DeclarationReferenceData) -> DeclarationReferenceData
	{
		if expression.isStandardLibrary {
			let message = "Reference to standard library \"\(expression.identifier)\" was not " +
				"translated."
			Compiler.handleWarning(
					message: message,
					sourceFile: ast.sourceFile,
					sourceFileRange: expression.range)
		}
		return super.replaceDeclarationReferenceExpressionData(expression)
	}
}

/// If a value type's members are all immutable, that value type can safely be translated as a
/// class. Otherwise, the translation can cause inconsistencies, so this pass raises warnings.
/// Source: https://forums.swift.org/t/are-immutable-structs-like-classes/16270
public class RaiseMutableValueTypesWarningsTranspilationPass: TranspilationPass { // kotlin: ignore
	override func replaceStructDeclaration(
		annotations: String?,
		structName: String,
		inherits: ArrayClass<String>,
		members: ArrayClass<Statement>)
		-> ArrayClass<Statement>
	{
		for member in members {
			if case let .variableDeclaration(data: variableDeclaration) = member,
				!variableDeclaration.isImplicit,
				!variableDeclaration.isStatic,
				!variableDeclaration.isLet,
				variableDeclaration.getter == nil
			{
				let message = "No support for mutable variables in value types: found variable " +
					"\(variableDeclaration.identifier) inside struct \(structName)"
				Compiler.handleWarning(
					message: message,
					sourceFile: ast.sourceFile,
					sourceFileRange: nil)
			}
			else if case let .functionDeclaration(data: functionDeclaration) = member,
				functionDeclaration.isMutating
			{
				let methodName = functionDeclaration.prefix + "(" +
					functionDeclaration.parameters.map { $0.label + ":" }
						.joined(separator: ", ") + ")"
				let message = "No support for mutating methods in value types: found method " +
					"\(methodName) inside struct \(structName)"
				Compiler.handleWarning(
					message: message,
					sourceFile: ast.sourceFile,
					sourceFileRange: nil)
			}
		}

		return super.replaceStructDeclaration(
			annotations: annotations, structName: structName, inherits: inherits, members: members)
	}

	override func replaceEnumDeclaration(
		access: String?,
		enumName: String,
		inherits: ArrayClass<String>,
		elements: ArrayClass<EnumElement>,
		members: ArrayClass<Statement>,
		isImplicit: Bool)
		-> ArrayClass<Statement>
	{
		for member in members {
			if case let .functionDeclaration(data: functionDeclaration) = member,
				functionDeclaration.isMutating
			{
				let methodName = functionDeclaration.prefix + "(" +
					functionDeclaration.parameters.map { $0.label + ":" }
						.joined(separator: ", ") + ")"
				let message = "No support for mutating methods in value types: found method " +
					"\(methodName) inside enum \(enumName)"
				Compiler.handleWarning(
					message: message,
					sourceFile: ast.sourceFile,
					sourceFileRange: nil)
			}
		}

		return super.replaceEnumDeclaration(
			access: access,
			enumName: enumName,
			inherits: inherits,
			elements: elements,
			members: members,
			isImplicit: isImplicit)
	}
}

/// If statements with let declarations get translated to Kotlin by having their let declarations
/// rearranged to be before the if statement. This will cause any let conditions that have side
/// effects (i.e. `let x = sideEffects()`) to run eagerly on Kotlin but lazily on Swift, which can
/// lead to incorrect behavior.
public class RaiseWarningsForSideEffectsInIfLetsTranspilationPass: // kotlin: ignore
	TranspilationPass
{
	override func replaceIfStatementData(_ ifStatement: IfStatementData) -> IfStatementData {
		raiseWarningsForIfStatement(ifStatement, isElse: false)

		// No recursion by calling super, otherwise we'd run on the else statements twice
		return ifStatement
	}

	private func raiseWarningsForIfStatement(_ ifStatement: IfStatementData, isElse: Bool) {
		// The first condition of an non-else if statement is the only one that can safely have side
		// effects
		let conditions = isElse ?
			ifStatement.conditions :
			ArrayClass(ifStatement.conditions.dropFirst())

		let sideEffectsRanges = conditions.flatMap { mayHaveSideEffectsOnRanges($0) }
		for range in sideEffectsRanges {
			Compiler.handleWarning(
				message: "If condition may have side effects.",
				details: "",
				sourceFile: ast.sourceFile,
				sourceFileRange: range)
		}

		if let elseStatement = ifStatement.elseStatement {
			raiseWarningsForIfStatement(elseStatement, isElse: true)
		}
	}

	private func mayHaveSideEffectsOnRanges(
		_ condition: IfStatementData.IfCondition)
		-> ArrayClass<SourceFileRange>
	{
		if case let .declaration(variableDeclaration: variableDeclaration) = condition,
			let expression = variableDeclaration.expression
		{
			return mayHaveSideEffectsOnRanges(expression)
		}

		return []
	}

	private func mayHaveSideEffectsOnRanges(_ expression: Expression) -> ArrayClass<SourceFileRange>
	{
		switch expression {
		case let .callExpression(data: callExpression):
			if !KotlinTranslator.isReferencingPureFunction(callExpression),
				let range = callExpression.range
			{
				return [range]
			}
			else {
				return []
			}
		case let .parenthesesExpression(expression: expression):
			return mayHaveSideEffectsOnRanges(expression)
		case let .forceValueExpression(expression: expression):
			return mayHaveSideEffectsOnRanges(expression)
		case let .optionalExpression(expression: expression):
			return mayHaveSideEffectsOnRanges(expression)
		case let .subscriptExpression(
			subscriptedExpression: subscriptedExpression,
			indexExpression: indexExpression,
			typeName: _):

			return mayHaveSideEffectsOnRanges(subscriptedExpression) +
				mayHaveSideEffectsOnRanges(indexExpression)

		case let .arrayExpression(elements: elements, typeName: _):
			return elements.flatMap { mayHaveSideEffectsOnRanges($0) }
		case let .dictionaryExpression(keys: keys, values: values, typeName: _):
			return keys.flatMap { mayHaveSideEffectsOnRanges($0) } +
				values.flatMap { mayHaveSideEffectsOnRanges($0) }
		case let .dotExpression(leftExpression: leftExpression, rightExpression: rightExpression):
			return mayHaveSideEffectsOnRanges(leftExpression) +
				mayHaveSideEffectsOnRanges(rightExpression)
		case let .binaryOperatorExpression(
			leftExpression: leftExpression,
			rightExpression: rightExpression,
			operatorSymbol: _,
			typeName: _):

			return mayHaveSideEffectsOnRanges(leftExpression) +
				mayHaveSideEffectsOnRanges(rightExpression)
		case let .prefixUnaryExpression(
			subExpression: subExpression, operatorSymbol: _, typeName: _):

			return mayHaveSideEffectsOnRanges(subExpression)
		case let .postfixUnaryExpression(
			subExpression: subExpression, operatorSymbol: _, typeName: _):

			return mayHaveSideEffectsOnRanges(subExpression)
		case let .ifExpression(
			condition: condition,
			trueExpression: trueExpression,
			falseExpression: falseExpression):

			return mayHaveSideEffectsOnRanges(condition) +
				mayHaveSideEffectsOnRanges(trueExpression) +
				mayHaveSideEffectsOnRanges(falseExpression)

		case let .interpolatedStringLiteralExpression(expressions: expressions):
			return expressions.flatMap { mayHaveSideEffectsOnRanges($0) }
		case let .tupleExpression(pairs: pairs):
			return pairs.flatMap { mayHaveSideEffectsOnRanges($0.expression) }
		case let .tupleShuffleExpression(labels: _, indices: _, expressions: expressions):
			return expressions.flatMap { mayHaveSideEffectsOnRanges($0) }
		default:
			return []
 		}
	}
}

/// Sends let declarations to before the if statement, and replaces them with `x != null` conditions
public class RearrangeIfLetsTranspilationPass: TranspilationPass { // kotlin: ignore

	/// Send the let declarations to before the if statement
	override func replaceIfStatement(_ ifStatement: IfStatementData) -> ArrayClass<Statement> {
		let letDeclarations = gatherLetDeclarations(ifStatement)
			.map { Statement.variableDeclaration(data: $0) }

		return letDeclarations + super.replaceIfStatement(ifStatement)
	}

	/// Add conditions (`x != null`) for all let declarations
	override func replaceIfStatementData(_ ifStatement: IfStatementData) -> IfStatementData {
		let newConditions = ifStatement.conditions.map { condition -> IfStatementData.IfCondition in
			if case let .declaration(variableDeclaration: variableDeclaration) = condition {
				return .condition(expression: .binaryOperatorExpression(
					leftExpression: .declarationReferenceExpression(data:
						DeclarationReferenceData(
							identifier: variableDeclaration.identifier,
							typeName: variableDeclaration.typeName,
							isStandardLibrary: false,
							isImplicit: false,
							range: variableDeclaration.expression?.range)),
					rightExpression: .nilLiteralExpression, operatorSymbol: "!=",
					typeName: "Boolean"))
			}
			else {
				return condition
			}
		}

		let ifStatement = ifStatement
		ifStatement.conditions = newConditions
		return super.replaceIfStatementData(ifStatement)
	}

	/// Gather the let declarations from the if statement and its else( if)s into a single array
	private func gatherLetDeclarations(
		_ ifStatement: IfStatementData?)
		-> ArrayClass<VariableDeclarationData>
	{
		guard let ifStatement = ifStatement else {
			return []
		}

		let letDeclarations =
			ifStatement.conditions.compactMap { condition -> VariableDeclarationData? in
				if case let .declaration(variableDeclaration: variableDeclaration) = condition {
					return variableDeclaration
				}
				else {
					return nil
				}
			}.filter { variableDeclaration in
				// If it's a shadowing identifier there's no need to declare it in Kotlin
				// (i.e. `if let x = x { }`)
				if let declarationExpression = variableDeclaration.expression,
					case let .declarationReferenceExpression(
						data: expression) = declarationExpression,
					expression.identifier == variableDeclaration.identifier
				{
					return false
				}
				else {
					return true
				}
			}

		let elseLetDeclarations = gatherLetDeclarations(ifStatement.elseStatement)

		return letDeclarations + elseLetDeclarations
	}
}

/// Create a rawValue variable for enums that conform to rawRepresentable
public class RawValuesTranspilationPass: TranspilationPass { // kotlin: ignore
	override func replaceEnumDeclaration(
		access: String?,
		enumName: String,
		inherits: ArrayClass<String>,
		elements: ArrayClass<EnumElement>,
		members: ArrayClass<Statement>,
		isImplicit: Bool) -> ArrayClass<Statement>
	{
		if let typeName = elements.compactMap({ $0.rawValue?.swiftType }).first {
			let rawValueVariable = createRawValueVariable(
				rawValueType: typeName,
				access: access,
				enumName: enumName,
				elements: elements)

			guard let rawValueInitializer = createRawValueInitializer(
				rawValueType: typeName,
				access: access,
				enumName: enumName,
				elements: elements) else
			{
				Compiler.handleWarning(
					message: "Failed to create init(rawValue:)",
					details: "Unable to get all raw values in enum declaration.",
					sourceFile: ast.sourceFile,
					sourceFileRange: elements.compactMap { $0.rawValue?.range }.first)
				return super.replaceEnumDeclaration(
					access: access,
					enumName: enumName,
					inherits: inherits,
					elements: elements,
					members: members,
					isImplicit: isImplicit)
			}

			let newMembers = members
			newMembers.append(.functionDeclaration(data: rawValueInitializer))
			newMembers.append(.variableDeclaration(data: rawValueVariable))

			return super.replaceEnumDeclaration(
				access: access,
				enumName: enumName,
				inherits: inherits,
				elements: elements,
				members: newMembers,
				isImplicit: isImplicit)
		}
		else {
			return super.replaceEnumDeclaration(
				access: access,
				enumName: enumName,
				inherits: inherits,
				elements: elements,
				members: members,
				isImplicit: isImplicit)
		}
	}

	private func createRawValueInitializer(
		rawValueType: String,
		access: String?,
		enumName: String,
		elements: ArrayClass<EnumElement>)
		-> FunctionDeclarationData?
	{
		let maybeSwitchCases = elements.map { element -> SwitchCase? in
			guard let rawValue = element.rawValue else {
				return nil
			}

			return SwitchCase(
				expressions: [rawValue],
				statements: [
					.returnStatement(
						expression: .dotExpression(
							leftExpression: .typeExpression(typeName: enumName),
							rightExpression: .declarationReferenceExpression(data:
								DeclarationReferenceData(
									identifier: element.name,
									typeName: enumName,
									isStandardLibrary: false,
									isImplicit: false,
									range: nil)))),
				])
		}

		guard let switchCases = maybeSwitchCases.as(ArrayClass<SwitchCase>.self) else {
			return nil
		}

		let defaultSwitchCase = SwitchCase(
			expressions: [],
			statements: [.returnStatement(expression: .nilLiteralExpression)])

		switchCases.append(defaultSwitchCase)

		let switchStatement = Statement.switchStatement(
			convertsToExpression: nil,
			expression: .declarationReferenceExpression(data:
				DeclarationReferenceData(
					identifier: "rawValue",
					typeName: rawValueType,
					isStandardLibrary: false,
					isImplicit: false,
					range: nil)),
			cases: switchCases)

		return FunctionDeclarationData(
			prefix: "init",
			parameters: [FunctionParameter(
				label: "rawValue",
				apiLabel: nil,
				typeName: rawValueType,
				value: nil), ],
			returnType: enumName + "?",
			functionType: "(\(rawValueType)) -> \(enumName)?",
			genericTypes: [],
			isImplicit: false,
			isStatic: true,
			isMutating: false,
			isPure: true,
			extendsType: nil,
			statements: [switchStatement],
			access: access,
			annotations: nil)
	}

	private func createRawValueVariable(
		rawValueType: String,
		access: String?,
		enumName: String,
		elements: ArrayClass<EnumElement>)
		-> VariableDeclarationData
	{
		let switchCases = elements.map { element in
			SwitchCase(
				expressions: [.dotExpression(
					leftExpression: .typeExpression(typeName: enumName),
					rightExpression: .declarationReferenceExpression(data:
						DeclarationReferenceData(
							identifier: element.name,
							typeName: enumName,
							isStandardLibrary: false,
							isImplicit: false,
							range: nil))), ],
				statements: [
					.returnStatement(
						expression: element.rawValue),
				])
		}

		let switchStatement = Statement.switchStatement(
			convertsToExpression: nil,
			expression: .declarationReferenceExpression(data:
				DeclarationReferenceData(
					identifier: "this",
					typeName: enumName,
					isStandardLibrary: false,
					isImplicit: false,
					range: nil)),
			cases: switchCases)

		let getter = FunctionDeclarationData(
			prefix: "get",
			parameters: [],
			returnType: rawValueType,
			functionType: "() -> \(rawValueType)",
			genericTypes: [],
			isImplicit: false,
			isStatic: false,
			isMutating: false,
			isPure: false,
			extendsType: nil,
			statements: [switchStatement],
			access: access,
			annotations: nil)

		return VariableDeclarationData(
			identifier: "rawValue",
			typeName: rawValueType,
			expression: nil,
			getter: getter,
			setter: nil,
			isLet: false,
			isImplicit: false,
			isStatic: false,
			extendsType: nil,
			annotations: nil)
	}
}

/// Guards are translated as if statements with a ! at the start of the condition. Sometimes, the
/// ! combines with a != or even another !, causing a double negative in the condition that can
/// be removed (or turned into a single ==). This pass performs that transformation.
public class DoubleNegativesInGuardsTranspilationPass: TranspilationPass { // kotlin: ignore
	override func replaceIfStatementData(_ ifStatement: IfStatementData) -> IfStatementData {
		if ifStatement.isGuard,
			ifStatement.conditions.count == 1,
			let onlyCondition = ifStatement.conditions.first,
			case let .condition(expression: onlyConditionExpression) = onlyCondition
		{
			let shouldStillBeGuard: Bool
			let newCondition: Expression
			if case let .prefixUnaryExpression(
				subExpression: innerExpression,
				operatorSymbol: "!",
				typeName: _) = onlyConditionExpression
			{
				newCondition = innerExpression
				shouldStillBeGuard = false
			}
			else if case let .binaryOperatorExpression(
				leftExpression: leftExpression, rightExpression: rightExpression,
				operatorSymbol: "!=", typeName: typeName) = onlyConditionExpression
			{
				newCondition = .binaryOperatorExpression(
					leftExpression: leftExpression, rightExpression: rightExpression,
					operatorSymbol: "==", typeName: typeName)
				shouldStillBeGuard = false
			}
			else if case let .binaryOperatorExpression(
				leftExpression: leftExpression, rightExpression: rightExpression,
				operatorSymbol: "==", typeName: typeName) = onlyConditionExpression
			{
				newCondition = .binaryOperatorExpression(
					leftExpression: leftExpression, rightExpression: rightExpression,
					operatorSymbol: "!=", typeName: typeName)
				shouldStillBeGuard = false
			}
			else {
				newCondition = onlyConditionExpression
				shouldStillBeGuard = true
			}

			let ifStatement = ifStatement
			ifStatement.conditions = ArrayClass([newCondition]).map {
				IfStatementData.IfCondition.condition(expression: $0)
			}
			ifStatement.isGuard = shouldStillBeGuard
			return super.replaceIfStatementData(ifStatement)
		}
		else {
			return super.replaceIfStatementData(ifStatement)
		}
	}
}

/// Statements of the type `if (a == null) { return }` in Swift can be translated as `a ?: return`
/// in Kotlin.
public class ReturnIfNilTranspilationPass: TranspilationPass { // kotlin: ignore
	override func replaceStatement(_ statement: Statement) -> ArrayClass<Statement> {
		if case let .ifStatement(data: ifStatement) = statement,
			ifStatement.conditions.count == 1,
			let onlyCondition = ifStatement.conditions.first,
			case let .condition(expression: onlyConditionExpression) = onlyCondition,
			case let .binaryOperatorExpression(
				leftExpression: declarationReference,
				rightExpression: Expression.nilLiteralExpression,
				operatorSymbol: "==",
				typeName: _) = onlyConditionExpression,
			case let .declarationReferenceExpression(
				data: declarationExpression) = declarationReference,
			ifStatement.statements.count == 1,
			let onlyStatement = ifStatement.statements.first,
			case let .returnStatement(expression: returnExpression) = onlyStatement
		{
			return [.expressionStatement(expression:
				.binaryOperatorExpression(
					leftExpression: declarationReference,
					rightExpression: .returnExpression(expression: returnExpression),
					operatorSymbol: "?:",
					typeName: declarationExpression.typeName)), ]
		}
		else {
			return super.replaceStatement(statement)
		}
	}
}

public class FixProtocolContentsTranspilationPass: TranspilationPass { // kotlin: ignore
	var isInProtocol = false

	override func replaceProtocolDeclaration(
		protocolName: String,
		members: ArrayClass<Statement>)
		-> ArrayClass<Statement>
	{
		isInProtocol = true
		let result = super.replaceProtocolDeclaration(protocolName: protocolName, members: members)
		isInProtocol = false

		return result
	}

	override func replaceFunctionDeclarationData(_ functionDeclaration: FunctionDeclarationData)
		-> FunctionDeclarationData?
	{
		if isInProtocol {
			let functionDeclaration = functionDeclaration
			functionDeclaration.statements = nil
			return super.replaceFunctionDeclarationData(functionDeclaration)
		}
		else {
			return super.replaceFunctionDeclarationData(functionDeclaration)
		}
	}

	override func replaceVariableDeclarationData(_ variableDeclaration: VariableDeclarationData)
		-> VariableDeclarationData
	{
		if isInProtocol {
			let variableDeclaration = variableDeclaration
			variableDeclaration.getter?.isImplicit = true
			variableDeclaration.setter?.isImplicit = true
			variableDeclaration.getter?.statements = nil
			variableDeclaration.setter?.statements = nil
			return super.replaceVariableDeclarationData(variableDeclaration)
		}
		else {
			return super.replaceVariableDeclarationData(variableDeclaration)
		}
	}
}

public extension TranspilationPass { // kotlin: ignore
	/// Runs transpilation passes that have to be run on all files before the other passes can
	/// run. For instance, we need to record all enums declared on all files before we can
	/// translate references to them correctly.
	static func runFirstRoundOfPasses(on sourceFile: GryphonAST) -> GryphonAST {
		var result = sourceFile

		// Remove declarations that shouldn't even be considered in the passes
		result = RemoveImplicitDeclarationsTranspilationPass(ast: result).run()

		// RecordEnums needs to be after CleanInheritance: it needs Swift-only inheritances removed
		// in order to know if the enum inherits from a class or not, and therefore is a sealed
		// class or an enum class.
		result = CleanInheritancesTranspilationPass(ast: result).run()

		// Record information on enum and function translations
		result = RecordTemplatesTranspilationPass(ast: result).run()
		result = RecordEnumsTranspilationPass(ast: result).run()
		result = RecordProtocolsTranspilationPass(ast: result).run()
		result = RecordFunctionsTranspilationPass(ast: result).run()

		return result
	}

	/// Runs transpilation passes that can be run independently on any files, provided they happen
	/// after the `runFirstRoundOfPasses`.
	static func runSecondRoundOfPasses(on sourceFile: GryphonAST) -> GryphonAST {
		var result = sourceFile

		// Replace templates (must go before other passes since templates are recorded before
		// running any passes)
		result = ReplaceTemplatesTranspilationPass(ast: result).run()

		// Cleanup
		result = RemoveParenthesesTranspilationPass(ast: result).run()
		result = RemoveExtraReturnsInInitsTranspilationPass(ast: result).run()

		// Transform structures that need to be significantly different in Kotlin
		result = RawValuesTranspilationPass(ast: result).run()
		result = DescriptionAsToStringTranspilationPass(ast: result).run()
		result = OptionalInitsTranspilationPass(ast: result).run()
		result = StaticMembersTranspilationPass(ast: result).run()
		result = FixProtocolContentsTranspilationPass(ast: result).run()
		result = RemoveExtensionsTranspilationPass(ast: result).run()
		// Note: We have to know the order of the conditions to raise warnings here, so they must go
		// before the conditions are rearranged
		result = RaiseWarningsForSideEffectsInIfLetsTranspilationPass(ast: result).run()
		result = RearrangeIfLetsTranspilationPass(ast: result).run()

		// Transform structures that need to be slightly different in Kotlin
		result = SelfToThisTranspilationPass(ast: result).run()
		result = AnonymousParametersTranspilationPass(ast: result).run()
		result = CovarianceInitsAsCallsTranspilationPass(ast: result).run()
		result = ReturnsInLambdasTranspilationPass(ast: result).run()
		result = RefactorOptionalsInSubscriptsTranspilationPass(ast: result).run()
		result = AddOptionalsInDotChainsTranspilationPass(ast: result).run()
		result = RenameOperatorsTranspilationPass(ast: result).run()

		// - CapitalizeEnums has to be before IsOperatorsInSealedClasses
		result = CapitalizeEnumsTranspilationPass(ast: result).run()
		result = IsOperatorsInSealedClassesTranspilationPass(ast: result).run()

		// - SwitchesToExpressions has to be before RemoveBreaksInSwitches:
		//   RemoveBreaks might remove a case that only has a break, turning an exhaustive switch
		//   into a non-exhaustive one and making it convertible to an expression. However, only
		//   exhaustive switches can be converted to expressions, so this should be avoided.
		result = SwitchesToExpressionsTranspilationPass(ast: result).run()
		result = RemoveBreaksInSwitchesTranspilationPass(ast: result).run()

		// Improve Kotlin readability
		result = OmitImplicitEnumPrefixesTranspilationPass(ast: result).run()
		result = InnerTypePrefixesTranspilationPass(ast: result).run()
		result = DoubleNegativesInGuardsTranspilationPass(ast: result).run()
		result = ReturnIfNilTranspilationPass(ast: result).run()

		// Raise any warnings that may be left
		result = RaiseStandardLibraryWarningsTranspilationPass(ast: result).run()
		result = RaiseMutableValueTypesWarningsTranspilationPass(ast: result).run()

		return result
	}

	func printParents() {
		print("[")
		for parent in parents {
			switch parent {
			case let .statementNode(statement):
				print("\t\(statement.name),")
			case let .expressionNode(expression):
				print("\t\(expression.name),")
			}
		}
		print("]")
	}
}

//
public enum ASTNode: Equatable {
	case statementNode(value: Statement)
	case expressionNode(value: Expression)
}
