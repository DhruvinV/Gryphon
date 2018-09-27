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
	public class Diagnostics: CustomStringConvertible {
        private(set) var translatedSubtrees = GRYHistogram<String>()
		private(set) var refactorableSubtrees = GRYHistogram<String>()
        private(set) var unknownSubtrees = GRYHistogram<String>()

		fileprivate func logSuccessfulTranslation(_ subtreeName: String) {
			translatedSubtrees.increaseOccurence(of: subtreeName)
		}

        fileprivate func logRefactorableTranslation(_ subtreeName: String) {
            refactorableSubtrees.increaseOccurence(of: subtreeName)
        }

        fileprivate func logUnknownTranslation(_ subtreeName: String) {
            unknownSubtrees.increaseOccurence(of: subtreeName)
        }

		fileprivate func logResult(_ translationResult: TranslationResult, subtreeName: String) {
			if case .translation(_) = translationResult {
				logSuccessfulTranslation(subtreeName)
			}
			else {
				logUnknownTranslation(subtreeName)
			}
		}

		public var description: String {
			return """
			-----
			# Kotlin translation diagnostics:

			## Translated subtrees

			\(translatedSubtrees)
			## Refactorable subtrees

			\(refactorableSubtrees)
			## Unknown subtrees

			\(unknownSubtrees)
			"""
		}
	}

	/// Records the amount of translations that have been successfully translated;
	/// that can be refactored into translatable code; or that can't be translated.
	var diagnostics: Diagnostics?

	fileprivate enum TranslationError: Error {
		case refactorable
		case unknown
	}

	/// Used for the translation of Swift types into Kotlin types.
	static let typeMappings = ["Bool": "Boolean", "Error": "Exception"]

	private func translateType(_ type: String) -> String {
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

	/**
	This variable is used to allow calls to the `GRYIgnoreNext` function to ignore
	the next swift statement. When a call to that function is detected, this variable is set
	to true. Then, when the next statement comes along, the translator will see that this
	variable is set to true, ignore that statement, and then reset it to false to continue
	translation.
	*/
	private var shouldIgnoreNext = false

	/**
	Swift variables declared with a value, such as `var x = 0`, are represented in a weird way in
	the AST: first comes a `Pattern Binding Declaration` containing the variable's name, its type,
	and its initial value; then comes the actual `Variable Declaration`, but in a different branch
	of the AST and with no information on the previously mentioned initial value.
	
	Since both of them have essential information, we need both at the same time to translate a
	variable declaration. However, since they are in unpredictably different branches, it's hard to
	find the Variable Declaration when we first read the Pattern Binding Declaration.
	
	The solution then is to temporarily save the Pattern Binding Declaration's information on this
	variable. Then, once we find the Variable Declaration, we check to see if the stored value is
	appropriate and then use all the information available to complete the translation process. This
	variable is then reset to nil.
	
	- SeeAlso: translate(variableDeclaration:, withIndentation:)
	*/
	var danglingPatternBinding: (identifier: String, type: String, translatedExpression: String)?

	// MARK: - Interface

	/**
	Translates the swift statements in the `ast` into kotlin code.
	
	The swift AST may contain either top-level statements (such as in a "main" file), declarations
	(i.e. function or class declarations), or both. Any declarations will be translated at the
	beggining of the file, and any top-level statements will be wrapped in a `main` function and
	added to the end of the file.
	
	If no top-level statements are found, the main function is ommited.
	
	This function should be given the AST of a single source file, and should provide a translation
	of that source file's contents.
	
	- Parameter ast: The AST, obtained from swift, containing a "Source File" node at the root.
	- Returns: A kotlin translation of the contents of the AST.
	*/
	public func translateAST(_ sourceFile: GRYSourceFile) -> String? {
		let declarationsTranslation =
			translate(subtrees: sourceFile.declarations, withIndentation: "")

		// Then, translate the remaining statements (if there are any) and wrap them in the main
		// function
		let indentation = increaseIndentation("")
		let statementsTranslation =
			translate(subtrees: sourceFile.statements, withIndentation: indentation)

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

	private func translate(subtree: GRYTopLevelNode, withIndentation indentation: String)
		-> String
	{
		let result: String

		switch subtree {
		case .importDeclaration(name: _):
			result = ""
		case let .classDeclaration(name: name, inherits: inherits, members: members):
			result = translateClassDeclaration(
				name: name, inherits: inherits, members: members, withIndentation: indentation)
		case let .enumDeclaration(
			access: access, name: name, inherits: inherits, elements: elements):

			result = translateEnumDeclaration(
				access: access, name: name, inherits: inherits, elements: elements,
				withIndentation: indentation)
		case let .forEachStatement(
			collection: collection, variable: variable, statements: statements):

			result = translateForEachStatement(
				collection: collection, variable: variable, statements: statements,
				withIndentation: indentation)
		case let .functionDeclaration(
			prefix: prefix, parameterNames: parameterNames, parameterTypes: parameterTypes,
			returnType: returnType, isImplicit: isImplicit, statements: statements, access: access):

			result = translateFunctionDeclaration(
				prefix: prefix, parameterNames: parameterNames, parameterTypes: parameterTypes,
				returnType: returnType, isImplicit: isImplicit, statements: statements,
				access: access, withIndentation: indentation)
		case let .protocolDeclaration(name: name):
			result = translateProtocolDeclaration(name: name, withIndentation: indentation)
		case let .throwStatement(expression: expression):
			result = translateThrowStatement(expression: expression, withIndentation: indentation)
		case .structDeclaration(name: _):
			return ""
		case let .variableDeclaration(
			identifier: identifier, typeName: typeName, expression: expression, getter: getter,
			setter: setter, isLet: isLet, extendsType: extendsType):

			result = translateVariableDeclaration(
				identifier: identifier, typeName: typeName, expression: expression, getter: getter,
				setter: setter, isLet: isLet, extendsType: extendsType,
				withIndentation: indentation)
		case let .assignmentStatement(leftHand: leftHand, rightHand: rightHand):
			result = translateAssignmentStatement(
				leftHand: leftHand, rightHand: rightHand, withIndentation: indentation)
		case let .ifStatement(
			conditions: conditions, declarations: declarations, statements: statements,
			elseStatement: elseStatement, isGuard: isGuard):

			result = translateIfStatement(
				conditions: conditions, declarations: declarations, statements: statements,
				elseStatement: elseStatement, isGuard: isGuard, isElseIf: false,
				withIndentation: indentation)
		case let .returnStatement(expression: expression):
			result = translateReturnStatement(expression: expression, withIndentation: indentation)
		case let .expression(expression: expression):
			let expressionTranslation = translateExpression(expression)
			if !expressionTranslation.isEmpty {
				return indentation + expressionTranslation + "\n"
			}
			else {
				return ""
			}
		}

		return result
	}

	private func translate(subtrees: [GRYTopLevelNode], withIndentation indentation: String)
		-> String
	{
		var result = ""

		for subtree in subtrees {
			if shouldIgnoreNext {
				shouldIgnoreNext = false
				continue
			}

			result += translate(subtree: subtree, withIndentation: indentation)
		}

		return result
	}

	private func translateEnumDeclaration(
		access: String?, name: String, inherits: [String], elements: [String],
		withIndentation indentation: String) -> String
	{
		guard !inherits.contains("GRYIgnore") else {
			return ""
		}

		// TODO: Turn this into a pass
		GRYKotlinTranslator.enums.append(name)

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

	private func translateProtocolDeclaration(name: String, withIndentation indentation: String)
		-> String
	{
		precondition(name == "GRYIgnore")
		return ""
	}

	private func translateClassDeclaration(
		name: String, inherits: [String], members: [GRYTopLevelNode],
		withIndentation indentation: String) -> String
	{

		guard !inherits.contains("GRYIgnore") else {
			return ""
		}

		var result = "\(indentation)class \(name)"

		if !inherits.isEmpty {
			let translatedInheritances = inherits.map(translateType)
			result += ": " + translatedInheritances.joined(separator: ", ")
		}

		result += " {\n"

		let increasedIndentation = increaseIndentation(indentation)

		// Translate the contents
		let classContents = translate(
			subtrees: members,
			withIndentation: increasedIndentation)

		result += classContents + "\(indentation)}\n"

		return result
	}

	private func translateFunctionDeclaration(
		prefix: String, parameterNames: [String], parameterTypes: [String], returnType: String,
		isImplicit: Bool, statements: [GRYTopLevelNode], access: String?,
		withIndentation indentation: String) -> String
	{
		guard !isImplicit else {
			return ""
		}

		guard prefix != "GRYInsert",
			prefix != "GRYAlternative",
			prefix != "GRYIgnoreNext" else
		{
			return ""
		}

		// If it's GRYDeclarations, we want to add its contents as top-level statements
		guard prefix != "GRYDeclarations" else {
			return translate(subtrees: statements, withIndentation: indentation)
		}

		var indentation = indentation
		var result = indentation

		if let access = access {
			result += access + " "
		}

		result += "fun "

		result += prefix + "("

		let parameters = zip(parameterNames, parameterTypes).map { $0.0 + ": " + $0.1 }

		result += parameters.joined(separator: ", ")

		result += ")"

		if returnType != "()" {
			let translatedReturnType = translateType(returnType)
			result += ": \(translatedReturnType)"
		}

		result += " {\n"

		// Translate the function body
		indentation = increaseIndentation(indentation)

		result += translate(subtrees: statements, withIndentation: indentation)

		indentation = decreaseIndentation(indentation)
		result += indentation + "}\n"

		return result
	}

	private func translateForEachStatement(
		collection: GRYExpression, variable: GRYExpression, statements: [GRYTopLevelNode],
		withIndentation indentation: String) -> String
	{
		var result = "\(indentation)for ("

		let variableTranslation = translateExpression(variable)

		result += variableTranslation + " in "

		let collectionTranslation = translateExpression(collection)

		result += collectionTranslation + ") {\n"

		let increasedIndentation = increaseIndentation(indentation)
		let statementsTranslation = translate(
			subtrees: statements, withIndentation: increasedIndentation)

		result += statementsTranslation

		result += indentation + "}\n"
		return result
	}

	private func translateIfStatement(
		conditions: [GRYExpression], declarations: [GRYTopLevelNode], statements: [GRYTopLevelNode],
		elseStatement: GRYTopLevelNode?, isGuard: Bool, isElseIf: Bool,
		withIndentation indentation: String) -> String
	{
		let declarationsTranslation =
			translate(subtrees: declarations, withIndentation: indentation)

		var result = declarationsTranslation + indentation

		let keyword = (conditions.isEmpty && declarations.isEmpty) ?
			"else" :
			(isElseIf ? "else if" : "if")

		result += keyword + " "

		let increasedIndentation = increaseIndentation(indentation)

		// TODO: Turn this into an ast pass
		let explicitConditionsTranslations = conditions.map(translateExpression)
		let declarationConditionsTranslations = declarations.map
		{ (declaration: GRYTopLevelNode) -> String in
			guard case let .variableDeclaration(
				identifier: identifier, typeName: _, expression: _, getter: _, setter: _, isLet: _,
				extendsType: _) = declaration else
			{
				preconditionFailure()
			}
			return identifier + " != null"
		}
		let allConditions = declarationConditionsTranslations + explicitConditionsTranslations
		let conditionsTranslation = allConditions.joined(separator: " && ")

		if keyword != "else" {
			let parenthesizedCondition = isGuard ?
				("(!(" + conditionsTranslation + ")) ") :
				("(" + conditionsTranslation + ") ")

			result += parenthesizedCondition
		}

		result += "{\n"

		let statementsString =
			translate(subtrees: statements, withIndentation: increasedIndentation)

		result += statementsString + indentation + "}\n"

		if let unwrappedElse = elseStatement {
			guard case let .ifStatement(
				conditions: conditions, declarations: declarations, statements: statements,
				elseStatement: elseStatement, isGuard: isGuard) = unwrappedElse else
			{
				preconditionFailure()
			}
			result += translateIfStatement(
				conditions: conditions, declarations: declarations, statements: statements,
				elseStatement: elseStatement, isGuard: isGuard, isElseIf: true,
				withIndentation: indentation)
		}

		return result
	}

	private func translateThrowStatement(
		expression: GRYExpression, withIndentation indentation: String) -> String
	{
		let expressionString = translateExpression(expression)
		return "\(indentation)throw \(expressionString)\n"
	}

	private func translateReturnStatement(
		expression: GRYExpression?, withIndentation indentation: String) -> String
	{
		if let expression = expression {
			let expressionString = translateExpression(expression)
			return "\(indentation)return \(expressionString)\n"
		}
		else {
			return "\(indentation)return\n"
		}
	}

	/**
	Translates a swift variable declaration into kotlin code.
	
	This function checks the value stored in `danglingPatternBinding`. If a value is present and
	it's consistent with this variable declaration (same identifier and type), we use the expression
	inside it as the initial value for the variable (and the `danglingPatternBinding` is reset to
	`nil`). Otherwise, the variable is declared without an initial value.
	*/
	private func translateVariableDeclaration(
		identifier: String, typeName: String, expression: GRYExpression?, getter: GRYTopLevelNode?,
		setter: GRYTopLevelNode?, isLet: Bool, extendsType: String?,
		withIndentation indentation: String) -> String
	{
		var result = indentation

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
			let expressionTranslation = translateExpression(expression)
			result += " = " + expressionTranslation
		}

		result += "\n"

		let indentation1 = increaseIndentation(indentation)
		let indentation2 = increaseIndentation(indentation1)
		if let getter = getter {
			guard case let .functionDeclaration(
				prefix: _, parameterNames: _, parameterTypes: _, returnType: _, isImplicit: _,
				statements: statements, access: _) = getter else
			{
				preconditionFailure()
			}

			result += indentation1 + "get() {\n"
			result += translate(subtrees: statements, withIndentation: indentation2)
			result += indentation1 + "}\n"
		}

		if let setter = setter {
			guard case let .functionDeclaration(
				prefix: _, parameterNames: _, parameterTypes: _, returnType: _, isImplicit: _,
				statements: statements, access: _) = setter else
			{
				preconditionFailure()
			}

			result += indentation1 + "set(newValue) {\n"
			result += translate(subtrees: statements, withIndentation: indentation2)
			result += indentation1 + "}\n"
		}

		return result
	}

	private func translateAssignmentStatement(
		leftHand: GRYExpression, rightHand: GRYExpression, withIndentation indentation: String)
		-> String
	{
		let leftTranslation = translateExpression(leftHand)
		let rightTranslation = translateExpression(rightHand)
		return "\(indentation)\(leftTranslation) = \(rightTranslation)\n"
	}

	private func translateExpression(_ expression: GRYExpression) -> String {
		// Most diagnostics are logged by the child subTrees; others represent wrapper expressions
		// with little value in logging. There are a few expections.

		switch expression {
		case let .arrayExpression(elements: elements):
			return translateArrayExpression(elements: elements)
		case let .binaryOperatorExpression(
			leftExpression: leftExpression,
			rightExpression: rightExpression,
			operatorSymbol: operatorSymbol):

			return translateBinaryOperatorExpression(
				leftExpression: leftExpression,
				rightExpression: rightExpression,
				operatorSymbol: operatorSymbol)
		case let .callExpression(function: function, parameters: parameters):
			return translateCallExpression(function: function, parameters: parameters)
		case let .declarationReferenceExpression(identifier: identifier):
			return translateDeclarationReferenceExpression(identifier: identifier)
		case let .dotExpression(leftExpression: leftExpression, rightExpression: rightExpression):
			return translateDotSyntaxCallExpression(
				leftExpression: leftExpression, rightExpression: rightExpression)
		case let .literalStringExpression(value: value):
			return translateStringLiteral(value: value)
		case let .interpolatedStringLiteralExpression(expressions: expressions):
			return translateInterpolatedStringLiteralExpression(expressions: expressions)
		case let .unaryOperatorExpression(expression: expression, operatorSymbol: operatorSymbol):
			return translatePrefixUnaryExpression(
				expression: expression, operatorSymbol: operatorSymbol)
		case let .typeExpression(type: type):
			return translateType(type)
		case let .subscriptExpression(
			subscriptedExpression: subscriptedExpression, indexExpression: indexExpression):

			return translateSubscriptExpression(
				subscriptedExpression: subscriptedExpression, indexExpression: indexExpression)
		case let .parenthesesExpression(expression: expression):
			return "(" + translateExpression(expression) + ")"
		case let .forceValueExpression(expression: expression):
			return translateExpression(expression) + "!!"
		case let .literalIntExpression(value: value):
			return String(value)
		case let .literalDoubleExpression(value: value):
			return String(value)
		case let .literalBoolExpression(value: value):
			return String(value)
		case .nilLiteralExpression:
			return "null"
		case let .tupleExpression(pairs: pairs):
			return translateTupleExpression(pairs: pairs)
		}
	}

	private func translateSubscriptExpression(
		subscriptedExpression: GRYExpression, indexExpression: GRYExpression) -> String
	{
		return translateExpression(subscriptedExpression) +
			"[\(translateExpression(indexExpression))]"
	}

	private func translateArrayExpression(elements: [GRYExpression]) -> String {
		let expressionsString = elements.map {
			translateExpression($0)
		}.joined(separator: ", ")

		return "mutableListOf(\(expressionsString))"
	}

	private func translateDotSyntaxCallExpression(
		leftExpression: GRYExpression, rightExpression: GRYExpression) -> String
	{
		let leftHandString = translateExpression(leftExpression)
		let rightHandString = translateExpression(rightExpression)

		if GRYKotlinTranslator.enums.contains(leftHandString) {
			let capitalizedEnumCase = rightHandString.capitalizedAsCamelCase
			return "\(leftHandString).\(capitalizedEnumCase)()"
		}
		else {
			return "\(leftHandString).\(rightHandString)"
		}
	}

	private func translateBinaryOperatorExpression(
		leftExpression: GRYExpression,
		rightExpression: GRYExpression,
		operatorSymbol: String) -> String
	{
		let leftTranslation = translateExpression(leftExpression)
		let rightTranslation = translateExpression(rightExpression)
		return "\(leftTranslation) \(operatorSymbol) \(rightTranslation)"
	}

	private func translatePrefixUnaryExpression(
		expression: GRYExpression, operatorSymbol: String) -> String
	{
		let expressionTranslation = translateExpression(expression)
		return operatorSymbol + expressionTranslation
	}

	/**
	Translates a swift call expression into kotlin code.
	
	A call expression is a function call, but it can be explicit (as usual) or implicit
	(i.e. integer literals). Currently, the only implicit calls supported are integer, boolean and
	nil literals.
	
	As a special case, functions called GRYInsert, GRYAlternative and GRYIgnoreNext are used to
	directly manipulate the resulting kotlin code, and are treated separately below.
	
	As another special case, a call to the `print` function gets renamed to `println` for
	compatibility with kotlin. In the future, this will be done by a more complex system, but for
	now it allows integration tests to exist.
	
	- Note: If conditions include an "empty" call expression wrapping its real expression. This
	function handles the unwrapping then delegates the translation.
	*/
	private func translateCallExpression(function: GRYExpression, parameters: GRYExpression)
		-> String
	{
		guard case let .tupleExpression(pairs: pairs) = parameters else {
			preconditionFailure()
		}

		let functionTranslation = translateExpression(function)

		if functionTranslation == "GRYInsert" || functionTranslation == "GRYAlternative" {
			return translateAsKotlinLiteral(
				functionTranslation: functionTranslation,
				parameters: parameters)
		}
		else if functionTranslation == "GRYIgnoreNext" {
			shouldIgnoreNext = true
			return ""
		}

		let parametersTranslation = translateTupleExpression(pairs: pairs)

		// TODO: This should be replaced with a better system
		if functionTranslation == "print" {
			return "println" + parametersTranslation
		}
		else {
			return functionTranslation + parametersTranslation
		}
	}

	/**
	Translates functions that provide kotlin literals. There are two functions that
	can be declared in swift, `GRYInsert(_: String)` and
	`GRYAlternative<T>(swift: T, kotlin: String) -> T`, that allow a user to add
	literal kotlin code to the translation.
	
	The first one can be used to insert arbitrary kotlin statements in the middle
	of translated code, as in `GRYInsert("println(\"Hello, kotlin!\")")`.
	
	The second one can be used to provide a manual translation of a swift value, as in
	`let three = GRYAlternative(swift: sqrt(9), kotlin: "Math.sqrt(9.0)")`.

	Diagnostics get logged at caller (`translate(callExpression:)`).
	*/
	private func translateAsKotlinLiteral(
		functionTranslation: String,
		parameters: GRYExpression) -> String
	{
		let string: String
		if case let .tupleExpression(pairs: pairs) = parameters,
			let lastPair = pairs.last
		{
			// Remove this extra parentheses expression with an Ast pass
			if case let .literalStringExpression(value: value) = lastPair.expression {
				string = value
			}
			else if case let .parenthesesExpression(expression: expression) = lastPair.expression,
				case let .literalStringExpression(value: value) = expression
			{
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

	private func translateDeclarationReferenceExpression(identifier: String) -> String {
		return String(identifier.prefix { $0 != "(" })
	}

	/**
	Recovers an identifier formatted as a swift AST declaration.
	
	Declaration references are represented in the swift AST Dump in a rather complex format, so a
	few operations are used to extract only the relevant identifier.
	
	For instance: a declaration reference expression referring to the variable `x`, inside the `foo`
	function, in the /Users/Me/Documents/myFile.swift file, will be something like
	`myFile.(file).foo().x@/Users/Me/Documents/MyFile.swift:2:6`, but a declaration reference for
	the print function doesn't have the '@' or anything after it.
	
	Note that this function's job (in the example above) is to extract only the actual `x`
	identifier.
	*/
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

	private func translateTupleExpression(pairs: [GRYExpression.TuplePair]) -> String {
		guard !pairs.isEmpty else {
			return "()"
		}

		let contents = pairs.map { (pair: GRYExpression.TuplePair) -> String in

			// TODO: Turn this into an Ast pass
			let expression: String
			if case let .parenthesesExpression(expression: innerExpression) = pair.expression {
				expression = translateExpression(innerExpression)
			}
			else {
				expression = translateExpression(pair.expression)
			}

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
		-> String
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
				result += "${" + translateExpression(expression) + "}"
			}
		}

		result += "\""

		return result
	}

	//
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

	private func ASTIsExpression(_ ast: GRYSwiftAst) -> Bool {
		return ast.name.hasSuffix("Expression") || ast.name == "Inject Into Optional"
	}

	func increaseIndentation(_ indentation: String) -> String {
		return indentation + "\t"
	}

	func decreaseIndentation(_ indentation: String) -> String {
		return String(indentation.dropLast())
	}

	//
	enum TranslationResult: Equatable, CustomStringConvertible {
		case translation(String)
		case refactorable
		case failed

		init(stringLiteral value: StringLiteralType) {
			self = .translation(value)
		}

		static func +(left: TranslationResult, right: TranslationResult) -> TranslationResult {
			switch (left, right) {
			case (.failed, _), (_, .failed):
				return .failed
			case (.refactorable, _), (_, .refactorable):
				return .refactorable
			case (.translation(let leftTranslation), .translation(let rightTranslation)):
				return .translation(leftTranslation + rightTranslation)
			}
		}

		static func +(left: TranslationResult, right: String) -> TranslationResult {
			return left + .translation(right)
		}

		static func +(left: TranslationResult, right: Substring) -> TranslationResult {
			return left + String(right)
		}

		static func +(left: String, right: TranslationResult) -> TranslationResult {
			return .translation(left) + right
		}

		static func +(left: Substring, right: TranslationResult) -> TranslationResult {
			return String(left) + right
		}

		static func +=(left: inout TranslationResult, right: TranslationResult) {
			left = left + right
		}

		static func +=(left: inout TranslationResult, right: String) {
			left = left + right
		}

		static func +=(left: inout TranslationResult, right: Substring) {
			left = left + right
		}

		var stringValue: String? {
			switch self {
			case .translation(let value):
				return value
			case .failed, .refactorable:
				return nil
			}
		}

		var description: String {
			// The translator must turn TranslationResults into Strings explicitly, so as to force
			// the programmers to consider the possibilities and make their choices clearer.
			// This has already helped catch a few bugs.
			fatalError()
		}
	}
}

extension String {
	var capitalizedAsCamelCase: String {
		let firstCharacter = self.first!
		let capitalizedFirstCharacter = String(firstCharacter).uppercased()
		return String(capitalizedFirstCharacter + self.dropFirst())
	}
}
