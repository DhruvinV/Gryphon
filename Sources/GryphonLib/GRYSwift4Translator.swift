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

public class GRYSwift4Translator {
	// MARK: - Properties
	typealias PatternBindingDeclaration =
		(identifier: String, type: String, expression: GRYExpression?)?
	var danglingPatternBindings = [PatternBindingDeclaration?]()
	let errorDanglingPatternDeclaration: PatternBindingDeclaration =
		(identifier: "<<Error>>", type: "<<Error>>", expression: GRYExpression.error)

	private var sourceFile: GRYFile?

	// MARK: - Interface
	public init() { }

	public func translateAST(_ ast: GRYSwiftAST) throws -> GRYAST {
		let filePath = ast.standaloneAttributes[0]
		if let contents = try? String(contentsOfFile: filePath) {
			sourceFile = GRYFile(contents: contents)
		}

		// First, translate declarations that shouldn't be inside the main function
		let declarationNames = [
			"Protocol",
			"Class Declaration",
			"Struct Declaration",
			"Extension Declaration",
			"Function Declaration",
			"Enum Declaration",
			"Typealias",
		]
		let isDeclaration = { (ast: GRYSwiftAST) -> Bool in declarationNames.contains(ast.name) }
		let fileRange = sourceFile.map { 0..<$0.numberOfLines }

		let swiftDeclarations = ast.subtrees.filter(isDeclaration)
		let declarations = try translate(
			subtrees: swiftDeclarations.array, inScope: fileRange, asDeclarations: true)

		// Then, translate the remaining statements (if there are any) and wrap them in the main
		// function
		let swiftStatements = ast.subtrees.filter({ !isDeclaration($0) })
		let statements = try translate(
			subtrees: swiftStatements.array, inScope: fileRange, asDeclarations: false)

		return GRYAST(declarations: declarations, statements: statements)
	}

	// MARK: - Top-level translations
	internal func translate(subtree: GRYSwiftAST) throws -> [GRYTopLevelNode?] {

		if getComment(forNode: subtree, key: "kotlin") == "ignore" {
			return []
		}

		var result: GRYTopLevelNode?

		switch subtree.name {
		case "Top Level Code Declaration":
			result = try translate(topLevelCode: subtree)
		case "Import Declaration":
			result = .importDeclaration(name: subtree.standaloneAttributes[0])
		case "Typealias":
			result = try translate(typealiasDeclaration: subtree)
		case "Class Declaration":
			result = try translate(classDeclaration: subtree)
		case "Struct Declaration":
			result = try translate(structDeclaration: subtree)
		case "Enum Declaration":
			result = try translate(enumDeclaration: subtree)
		case "Extension Declaration":
			result = try translate(extensionDeclaration: subtree)
		case "For Each Statement":
			result = try translate(forEachStatement: subtree)
		case "Function Declaration", "Constructor Declaration":
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
		case "Switch Statement":
			result = try translate(switchStatement: subtree)
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
				// TODO: should this throw an error?
				result = nil
			}
		}

		return [result]
	}

	internal func translate(expression: GRYSwiftAST) throws -> GRYExpression {

		if let valueReplacement = getComment(forNode: expression, key: "value") {
			return GRYExpression.literalCodeExpression(string: valueReplacement)
		}

		switch expression.name {
		case "Array Expression":
			return try translate(arrayExpression: expression)
		case "Dictionary Expression":
			return try translate(dictionaryExpression: expression)
		case "Binary Expression":
			return try translate(binaryExpression: expression)
		case "Call Expression":
			return try translate(callExpression: expression)
		case "Closure Expression":
			return try translate(closureExpression: expression)
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
				return try unexpectedExpressionStructureError(
					"Unrecognized structure in automatic expression",
					AST: expression)
			}
		case "Prefix Unary Expression":
			return try translate(prefixUnaryExpression: expression)
		case "Postfix Unary Expression":
			return try translate(postfixUnaryExpression: expression)
		case "Type Expression":
			return try translate(typeExpression: expression)
		case "Member Reference Expression":
			return try translate(memberReferenceExpression: expression)
		case "Tuple Element Expression":
			return try translate(tupleElementExpression: expression)
		case "Subscript Expression":
			return try translate(subscriptExpression: expression)
		case "Open Existential Expression":
			let processedExpression = try process(openExistentialExpression: expression)
			return try translate(expression: processedExpression)
		case "Parentheses Expression":
			if let innerExpression = expression.subtree(at: 0) {
				// Swift 5: Compiler-created parentheses expressions may be marked with "implicit"
				if expression.standaloneAttributes.contains("implicit") {
					return try translate(expression: innerExpression)
				}
				else {
					return .parenthesesExpression(
						expression: try translate(expression: innerExpression))
				}
			}
			else {
				return try unexpectedExpressionStructureError(
					"Expected parentheses expression to have at least one subtree",
					AST: expression)
			}
		case "Force Value Expression":
			if let firstExpression = expression.subtree(at: 0) {
				let expression = try translate(expression: firstExpression)
				return .forceValueExpression(expression: expression)
			}
			else {
				return try unexpectedExpressionStructureError(
					"Expected force value expression to have at least one subtree",
					AST: expression)
			}
		case "Bind Optional Expression":
			if let firstExpression = expression.subtree(at: 0) {
				let expression = try translate(expression: firstExpression)
				return .optionalExpression(expression: expression)
			}
			else {
				return try unexpectedExpressionStructureError(
					"Expected optional expression to have at least one subtree",
					AST: expression)
			}
		case "Autoclosure Expression",
			 "Inject Into Optional",
			 "Optional Evaluation Expression",
			 "Inout Expression",
			 "Load Expression",
			 "Function Conversion Expression",
			 "Try Expression":
			if let lastExpression = expression.subtrees.last {
				return try translate(expression: lastExpression)
			}
			else {
				return try unexpectedExpressionStructureError(
					"Unrecognized structure in automatic expression",
					AST: expression)
			}
		case "Collection Upcast Expression":
			if let firstExpression = expression.subtrees.first {
				return try translate(expression: firstExpression)
			}
			else {
				return try unexpectedExpressionStructureError(
					"Unrecognized structure in automatic expression",
					AST: expression)
			}
		default:
			return try unexpectedExpressionStructureError("Unknown expression", AST: expression)
		}
	}

	internal func translate(
		subtrees: [GRYSwiftAST],
		inScope scope: GRYSwiftAST,
		asDeclarations: Bool = false) throws -> [GRYTopLevelNode]
	{
		let scopeRange = getRangeOfNode(scope)
		return try translate(
			subtrees: subtrees, inScope: scopeRange, asDeclarations: asDeclarations)
	}

	internal func translate(
		subtrees: [GRYSwiftAST],
		inScope scopeRange: Range<Int>?,
		asDeclarations: Bool = false) throws -> [GRYTopLevelNode]
	{
		let insertString = asDeclarations ? "declaration" : "insert"

		var result = [GRYTopLevelNode]()

		var lastRange: Range<Int>
		// I we have a scope, start at its lower bound
		if let scopeRange = scopeRange {
			lastRange = -1..<scopeRange.lowerBound
		}
			// If we don't, start at the first statement with a range
		else if let subtree = subtrees.first(where: { getRangeOfNode($0) != nil }) {
			lastRange = getRangeOfNode(subtree)!
		}
			// If there is no info on ranges, then just translate the subtrees normally
		else {
			return try subtrees
				.reduce([]) { acc, subtree in try acc + translate(subtree: subtree) }
				.compactMap { $0 }
		}

		for subtree in subtrees {
			if let currentRange = getRangeOfNode(subtree),
				lastRange.upperBound < currentRange.lowerBound
			{
				result += insertedCode(
					inRange: lastRange.upperBound..<currentRange.lowerBound, forKey: insertString)

				lastRange = currentRange
			}

			try result += translate(subtree: subtree).compactMap { $0 }
		}

		// Insert code in comments after the last translated node
		if let scopeRange = scopeRange,
			lastRange.upperBound < scopeRange.upperBound
		{
			result += insertedCode(
				inRange: lastRange.upperBound..<scopeRange.upperBound, forKey: insertString)
		}

		return result
	}

	// MARK: - Leaf translations
	internal func translate(subtreesOf ast: GRYSwiftAST) throws -> [GRYTopLevelNode] {
		return try translate(subtrees: ast.subtrees.array, inScope: ast)
	}

	internal func translate(braceStatement: GRYSwiftAST) throws -> [GRYTopLevelNode] {
		guard braceStatement.name == "Brace Statement" else {
			throw createUnexpectedASTStructureError(
				"Trying to translate \(braceStatement.name) as a brace statement",
				AST: braceStatement)
		}

		return try translate(subtrees: braceStatement.subtrees.array, inScope: braceStatement)
	}

	internal func translate(protocolDeclaration: GRYSwiftAST) throws -> GRYTopLevelNode {
		guard protocolDeclaration.name == "Protocol" else {
			return try unexpectedASTStructureError(
				"Trying to translate \(protocolDeclaration.name) as 'Protocol'",
				AST: protocolDeclaration)
		}

		guard let protocolName = protocolDeclaration.standaloneAttributes.first else {
			return try unexpectedASTStructureError(
				"Unrecognized structure",
				AST: protocolDeclaration)
		}

		let members = try translate(subtreesOf: protocolDeclaration)

		return .protocolDeclaration(name: protocolName, members: members)
	}

	internal func translate(assignExpression: GRYSwiftAST) throws -> GRYTopLevelNode {
		guard assignExpression.name == "Assign Expression" else {
			return try unexpectedASTStructureError(
				"Trying to translate \(assignExpression.name) as 'Assign Expression'",
				AST: assignExpression)
		}

		if let leftExpression = assignExpression.subtree(at: 0),
			let rightExpression = assignExpression.subtree(at: 1)
		{
			let leftTranslation = try translate(expression: leftExpression)
			let rightTranslation = try translate(expression: rightExpression)

			return .assignmentStatement(leftHand: leftTranslation, rightHand: rightTranslation)
		}
		else {
			return try unexpectedASTStructureError(
				"Unrecognized structure",
				AST: assignExpression)
		}
	}

	internal func translate(typealiasDeclaration: GRYSwiftAST) throws -> GRYTopLevelNode {
		let isImplicit: Bool
		let identifier: String
		if typealiasDeclaration.standaloneAttributes[0] == "implicit" {
			isImplicit = true
			identifier = typealiasDeclaration.standaloneAttributes[1]
		}
		else {
			isImplicit = false
			identifier = typealiasDeclaration.standaloneAttributes[0]
		}

		return .typealiasDeclaration(
			identifier: identifier, type: typealiasDeclaration["type"]!, isImplicit: isImplicit)
	}

	internal func translate(classDeclaration: GRYSwiftAST) throws -> GRYTopLevelNode? {
		guard classDeclaration.name == "Class Declaration" else {
			return try unexpectedASTStructureError(
				"Trying to translate \(classDeclaration.name) as 'Class Declaration'",
				AST: classDeclaration)
		}

		if getComment(forNode: classDeclaration, key: "kotlin") == "ignore" {
			return nil
		}

		// Get the class name
		let name = classDeclaration.standaloneAttributes.first!

		// Check for inheritance
		let inheritanceArray: [String]
		if let inheritanceList = classDeclaration["inherits"] {
			inheritanceArray = inheritanceList.split(withStringSeparator: ", ")
		}
		else {
			inheritanceArray = []
		}

		// Translate the contents
		let classContents = try translate(subtreesOf: classDeclaration)

		return .classDeclaration(name: name, inherits: inheritanceArray, members: classContents)
	}

	internal func translate(structDeclaration: GRYSwiftAST) throws -> GRYTopLevelNode? {
		guard structDeclaration.name == "Struct Declaration" else {
			return try unexpectedASTStructureError(
				"Trying to translate \(structDeclaration.name) as 'Struct Declaration'",
				AST: structDeclaration)
		}

		if getComment(forNode: structDeclaration, key: "kotlin") == "ignore" {
			return nil
		}

		// Get the struct name
		let name = structDeclaration.standaloneAttributes.first!

		// Check for inheritance
		let inheritanceArray: [String]
		if let inheritanceList = structDeclaration["inherits"] {
			inheritanceArray = inheritanceList.split(withStringSeparator: ", ")
		}
		else {
			inheritanceArray = []
		}

		// Translate the contents
		let structContents = try translate(subtreesOf: structDeclaration)

		return .structDeclaration(name: name, inherits: inheritanceArray, members: structContents)
	}

	internal func translate(throwStatement: GRYSwiftAST) throws -> GRYTopLevelNode {
		guard throwStatement.name == "Throw Statement" else {
			return try unexpectedASTStructureError(
				"Trying to translate \(throwStatement.name) as 'Throw Statement'",
				AST: throwStatement)
		}

		if let expression = throwStatement.subtrees.last {
			let expressionTranslation = try translate(expression: expression)
			return .throwStatement(expression: expressionTranslation)
		}
		else {
			return try unexpectedASTStructureError(
				"Unrecognized structure",
				AST: throwStatement)
		}
	}

	internal func translate(extensionDeclaration: GRYSwiftAST) throws -> GRYTopLevelNode {
		let type = cleanUpType(extensionDeclaration.standaloneAttributes[0])
		let members = try translate(subtreesOf: extensionDeclaration)
		return .extensionDeclaration(type: type, members: members)
	}

	internal func translate(enumDeclaration: GRYSwiftAST) throws -> GRYTopLevelNode? {
		guard enumDeclaration.name == "Enum Declaration" else {
			return try unexpectedASTStructureError(
				"Trying to translate \(enumDeclaration.name) as 'Enum Declaration'",
				AST: enumDeclaration)
		}

		if getComment(forNode: enumDeclaration, key: "kotlin") == "ignore" {
			return nil
		}

		let access = enumDeclaration["access"]

		let name: String
		let isImplicit: Bool
		if enumDeclaration.standaloneAttributes[0] == "implicit" {
			isImplicit = true
			name = enumDeclaration.standaloneAttributes[1]
		}
		else {
			isImplicit = false
			name = enumDeclaration.standaloneAttributes[0]
		}

		let inheritanceArray: [String]
		if let inheritanceList = enumDeclaration["inherits"] {
			inheritanceArray = inheritanceList.split(withStringSeparator: ", ")
		}
		else {
			inheritanceArray = []
		}

		var elements = [GRYASTEnumElement]()
		let enumElementDeclarations =
			enumDeclaration.subtrees.filter { $0.name == "Enum Element Declaration" }
		for enumElementDeclaration in enumElementDeclarations {
			guard let elementName = enumElementDeclaration.standaloneAttributes.first else {
				return try unexpectedASTStructureError(
					"Expected the element name to be the first standalone attribute in an Enum" +
					"Declaration",
					AST: enumDeclaration)
			}

			let annotations = getComment(forNode: enumElementDeclaration, key: "annotation")

			if !elementName.contains("(") {
				elements.append(GRYASTEnumElement(
					name: elementName, associatedValues: [], annotations: annotations))
			}
			else {
				let parenthesisIndex = elementName.firstIndex(of: "(")!
				let prefix = String(elementName[elementName.startIndex..<parenthesisIndex])
				let suffix = elementName[parenthesisIndex...]
				let valuesString = suffix.dropFirst().dropLast(2)
				let valueLabels = valuesString.split(separator: ":").map(String.init)

				guard let enumType = enumElementDeclaration["interface type"] else {
					return try unexpectedASTStructureError(
						"Expected an enum element with associated values to have an interface type",
						AST: enumDeclaration)
				}
				let enumTypeComponents = enumType.split(withStringSeparator: " -> ")
				let valuesComponent = enumTypeComponents[1]
				let valueTypesString = String(valuesComponent.dropFirst().dropLast())
				let valueTypes = valueTypesString.split(withStringSeparator: ", ")

				let associatedValues = zip(valueLabels, valueTypes).map(GRYASTLabeledType.init)

				elements.append(GRYASTEnumElement(
					name: prefix, associatedValues: associatedValues, annotations: annotations))
			}
		}

		let members = enumDeclaration.subtrees.filter {
			$0.name != "Enum Element Declaration" && $0.name != "Enum Case Declaration"
		}
		let translatedMembers = try translate(subtrees: members.array, inScope: enumDeclaration)

		return .enumDeclaration(
			access: access,
			name: name,
			inherits: inheritanceArray,
			elements: elements,
			members: translatedMembers,
			isImplicit: isImplicit)
	}

	internal func translate(memberReferenceExpression: GRYSwiftAST) throws -> GRYExpression {
		guard memberReferenceExpression.name == "Member Reference Expression" else {
			return try unexpectedExpressionStructureError(
				"Trying to translate \(memberReferenceExpression.name) as " +
				"'Member Reference Expression'",
				AST: memberReferenceExpression)
		}

		if let declaration = memberReferenceExpression["decl"],
			let memberOwner = memberReferenceExpression.subtree(at: 0),
			let rawType = memberReferenceExpression["type"]
		{
			let type = cleanUpType(rawType)
			let leftHand = try translate(expression: memberOwner)
			let (member, isStandardLibrary) = getIdentifierFromDeclaration(declaration)
			let isImplicit = memberReferenceExpression.standaloneAttributes.contains("implicit")
			let rightHand = GRYExpression.declarationReferenceExpression(
				identifier: member, type: type, isStandardLibrary: isStandardLibrary,
				isImplicit: isImplicit)
			return .dotExpression(leftExpression: leftHand,
								  rightExpression: rightHand)
		}
		else {
			return try unexpectedExpressionStructureError(
				"Unrecognized structure",
				AST: memberReferenceExpression)
		}
	}

	internal func translate(tupleElementExpression: GRYSwiftAST) throws -> GRYExpression {
		guard tupleElementExpression.name == "Tuple Element Expression" else {
			return try unexpectedExpressionStructureError(
				"Trying to translate \(tupleElementExpression.name) as " +
				"'Tuple Element Expression'",
				AST: tupleElementExpression)
		}

		if let numberString =
				tupleElementExpression.standaloneAttributes.first(where: { $0.hasPrefix("#") }),
			let number = Int(numberString.dropFirst()),
			let declarationReference =
				tupleElementExpression.subtree(named: "Declaration Reference Expression"),
			let tuple = declarationReference["type"]
		{
			let leftHand = try translate(declarationReferenceExpression: declarationReference)
			let tupleComponents =
				String(tuple.dropFirst().dropLast()).split(withStringSeparator: ", ")
			let tupleComponent = tupleComponents[safe: number]
			if let labelAndType = tupleComponent?.split(withStringSeparator: ": "),
				let label = labelAndType[safe: 0],
				let type = labelAndType[safe: 1],
				case let .declarationReferenceExpression(
					identifier: _, type: _, isStandardLibrary: isStandardLibrary,
					isImplicit: _) = leftHand
			{
				return .dotExpression(
					leftExpression: leftHand,
					rightExpression: .declarationReferenceExpression(
						identifier: label, type: type, isStandardLibrary: isStandardLibrary,
						isImplicit: false))
			}
		}

		return try unexpectedExpressionStructureError(
			"Unable to get the wither tuple element's number or its label.",
			AST: tupleElementExpression)
	}

	internal func translate(prefixUnaryExpression: GRYSwiftAST) throws -> GRYExpression {
		guard prefixUnaryExpression.name == "Prefix Unary Expression" else {
			return try unexpectedExpressionStructureError(
				"Trying to translate \(prefixUnaryExpression.name) as 'Prefix Unary Expression'",
				AST: prefixUnaryExpression)
		}

		if let rawType = prefixUnaryExpression["type"],
			let declaration = prefixUnaryExpression
			.subtree(named: "Dot Syntax Call Expression")?
			.subtree(named: "Declaration Reference Expression")?["decl"],
			let expression = prefixUnaryExpression.subtree(at: 1)
		{
			let type = cleanUpType(rawType)
			let expressionTranslation = try translate(expression: expression)
			let (operatorIdentifier, _) = getIdentifierFromDeclaration(declaration)

			return .prefixUnaryExpression(
				expression: expressionTranslation, operatorSymbol: operatorIdentifier, type: type)
		}
		else {
			return try unexpectedExpressionStructureError(
				"Expected Prefix Unary Expression to have a Dot Syntax Call Expression with a " +
				"Declaration Reference Expression, for the operator, and expected it to have " +
				"a second expression as the operand.",
				AST: prefixUnaryExpression)
		}
	}

	internal func translate(postfixUnaryExpression: GRYSwiftAST) throws -> GRYExpression {
		guard postfixUnaryExpression.name == "Postfix Unary Expression" else {
			return try unexpectedExpressionStructureError(
				"Trying to translate \(postfixUnaryExpression.name) as 'Postfix Unary Expression'",
				AST: postfixUnaryExpression)
		}

		if let rawType = postfixUnaryExpression["type"],
			let declaration = postfixUnaryExpression
				.subtree(named: "Dot Syntax Call Expression")?
				.subtree(named: "Declaration Reference Expression")?["decl"],
			let expression = postfixUnaryExpression.subtree(at: 1)
		{
			let type = cleanUpType(rawType)
			let expressionTranslation = try translate(expression: expression)
			let (operatorIdentifier, _) = getIdentifierFromDeclaration(declaration)

			return .postfixUnaryExpression(
				expression: expressionTranslation, operatorSymbol: operatorIdentifier, type: type)
		}
		else {
			return try unexpectedExpressionStructureError(
				"Expected Postfix Unary Expression to have a Dot Syntax Call Expression with a " +
				"Declaration Reference Expression, for the operator, and expected it to have " +
				"a second expression as the operand.",
				AST: postfixUnaryExpression)
		}
	}

	internal func translate(binaryExpression: GRYSwiftAST) throws -> GRYExpression {
		guard binaryExpression.name == "Binary Expression" else {
			return try unexpectedExpressionStructureError(
				"Trying to translate \(binaryExpression.name) as 'Binary Expression'",
				AST: binaryExpression)
		}

		let operatorIdentifier: String

		if let rawType = binaryExpression["type"],
			let declaration = binaryExpression
				.subtree(named: "Dot Syntax Call Expression")?
				.subtree(named: "Declaration Reference Expression")?["decl"] ??
					binaryExpression.subtree(named: "Declaration Reference Expression")?["decl"],
			let tupleExpression = binaryExpression.subtree(named: "Tuple Expression"),
			let leftHandExpression = tupleExpression.subtree(at: 0),
			let rightHandExpression = tupleExpression.subtree(at: 1)
		{
			let type = cleanUpType(rawType)
			(operatorIdentifier, _) = getIdentifierFromDeclaration(declaration)
			let leftHandTranslation = try translate(expression: leftHandExpression)
			let rightHandTranslation = try translate(expression: rightHandExpression)

			return .binaryOperatorExpression(
				leftExpression: leftHandTranslation,
				rightExpression: rightHandTranslation,
				operatorSymbol: operatorIdentifier,
				type: type)
		}
		else {
			return try unexpectedExpressionStructureError(
				"Unrecognized structure",
				AST: binaryExpression)
		}
	}

	internal func translate(typeExpression: GRYSwiftAST) throws -> GRYExpression {
		guard typeExpression.name == "Type Expression" else {
			return try unexpectedExpressionStructureError(
				"Trying to translate \(typeExpression.name) as 'Type Expression'",
				AST: typeExpression)
		}

		guard let type = typeExpression["typerepr"] else {
			return try unexpectedExpressionStructureError(
				"Unrecognized structure",
				AST: typeExpression)
		}

		return .typeExpression(type: cleanUpType(type))
	}

	internal func translate(dotSyntaxCallExpression: GRYSwiftAST) throws -> GRYExpression {
		guard dotSyntaxCallExpression.name == "Dot Syntax Call Expression" else {
			return try unexpectedExpressionStructureError(
				"Trying to translate \(dotSyntaxCallExpression.name) as " +
				"'Dot Syntax Call Expression'",
				AST: dotSyntaxCallExpression)
		}

		if let leftHandTree = dotSyntaxCallExpression.subtree(at: 1),
			let rightHandExpression = dotSyntaxCallExpression.subtree(at: 0)
		{
			let rightHand = try translate(expression: rightHandExpression)
			let leftHand = try translate(typeExpression: leftHandTree)

			// Swift 4.2
			if case .typeExpression(type: _) = leftHand,
				case let .declarationReferenceExpression(
					identifier: identifier, type: _, isStandardLibrary: _,
					isImplicit: _) = rightHand,
				identifier == "none"
			{
				return .nilLiteralExpression
			}

			return .dotExpression(leftExpression: leftHand, rightExpression: rightHand)
		}
		else {
			return try unexpectedExpressionStructureError(
				"Unrecognized structure",
				AST: dotSyntaxCallExpression)
		}
	}

	internal func translate(returnStatement: GRYSwiftAST) throws -> GRYTopLevelNode {
		guard returnStatement.name == "Return Statement" else {
			return try unexpectedASTStructureError(
				"Trying to translate \(returnStatement.name) as 'Return Statement'",
				AST: returnStatement)
		}

		if let expression = returnStatement.subtrees.last {
			let expression = try translate(expression: expression)
			return .returnStatement(expression: expression)
		}
		else {
			return .returnStatement(expression: nil)
		}
	}

	internal func translate(forEachStatement: GRYSwiftAST) throws -> GRYTopLevelNode {
		guard forEachStatement.name == "For Each Statement" else {
			return try unexpectedASTStructureError(
				"Trying to translate \(forEachStatement.name) as 'For Each Statement'",
				AST: forEachStatement)
		}

		guard let variableSubtree = forEachStatement.subtree(named: "Pattern Named"),
			let variableName = variableSubtree.standaloneAttributes.first,
			let rawType = variableSubtree["type"],
			let collectionExpression = forEachStatement.subtree(at: 2) else
		{
			return try unexpectedASTStructureError(
				"Unable to detect variable or collection",
				AST: forEachStatement)
		}

		let variableType = cleanUpType(rawType)

		guard let braceStatement = forEachStatement.subtrees.last,
			braceStatement.name == "Brace Statement" else
		{
			return try unexpectedASTStructureError(
				"Unable to detect body of statements",
				AST: forEachStatement)
		}

		let variable = GRYExpression.declarationReferenceExpression(
			identifier: variableName, type: variableType, isStandardLibrary: false,
			isImplicit: false)
		let collectionTranslation = try translate(expression: collectionExpression)
		let statements = try translate(braceStatement: braceStatement)

		return .forEachStatement(
			collection: collectionTranslation,
			variable: variable,
			statements: statements)
	}

	internal func translate(ifStatement: GRYSwiftAST) throws -> GRYTopLevelNode {
		do {
			let result: GRYASTIfStatement = try translate(ifStatement: ifStatement)
			return .ifStatement(value: result)
		}
		catch let error {
			return try handleUnexpectedASTStructureError(error)
		}
	}

	internal func translate(ifStatement: GRYSwiftAST) throws -> GRYASTIfStatement {
		guard ifStatement.name == "If Statement" || ifStatement.name == "Guard Statement" else {
			throw createUnexpectedASTStructureError(
				"Trying to translate \(ifStatement.name) as an if or guard statement",
				AST: ifStatement)
		}

		let isGuard = (ifStatement.name == "Guard Statement")

		let (letDeclarations, conditions) = try translateDeclarationsAndConditions(
			forIfStatement: ifStatement)

		let braceStatement: GRYSwiftAST
		let elseStatement: GRYASTIfStatement?

		if ifStatement.subtrees.count > 2,
			let unwrappedBraceStatement = ifStatement.subtrees.secondToLast,
			unwrappedBraceStatement.name == "Brace Statement",
			let elseIfAST = ifStatement.subtrees.last,
			elseIfAST.name == "If Statement"
		{
			braceStatement = unwrappedBraceStatement
			elseStatement = try translate(ifStatement: elseIfAST)
		}
		else if ifStatement.subtrees.count > 2,
			let unwrappedBraceStatement = ifStatement.subtrees.secondToLast,
			unwrappedBraceStatement.name == "Brace Statement",
			let elseAST = ifStatement.subtrees.last,
			elseAST.name == "Brace Statement"
		{
			braceStatement = unwrappedBraceStatement
			let statements = try translate(braceStatement: elseAST)
			elseStatement = GRYASTIfStatement(
				conditions: [], declarations: [],
				statements: statements,
				elseStatement: nil,
				isGuard: false)
		}
		else if let unwrappedBraceStatement = ifStatement.subtrees.last,
			unwrappedBraceStatement.name == "Brace Statement"
		{
			braceStatement = unwrappedBraceStatement
			elseStatement = nil
		}
		else {
			throw createUnexpectedASTStructureError(
				"Unable to detect body of statements",
				AST: ifStatement)
		}

		let statements = try translate(braceStatement: braceStatement)

		return GRYASTIfStatement(
			conditions: conditions,
			declarations: letDeclarations,
			statements: statements,
			elseStatement: elseStatement,
			isGuard: isGuard)
	}

	internal func translate(switchStatement: GRYSwiftAST) throws -> GRYTopLevelNode {
		guard switchStatement.name == "Switch Statement" else {
			return try unexpectedASTStructureError(
				"Trying to translate \(switchStatement.name) as 'Switch Statement'",
				AST: switchStatement)
		}

		guard let expression = switchStatement.subtrees.first else {
			return try unexpectedASTStructureError(
				"Unable to detect primary expression for switch statement",
				AST: switchStatement)
		}

		let translatedExpression = try translate(expression: expression)

		var cases = [GRYASTSwitchCase]()
		let caseSubtrees = switchStatement.subtrees.dropFirst()
		for caseSubtree in caseSubtrees {
			let caseExpression: GRYExpression?
			if let caseLabelItem = caseSubtree.subtree(named: "Case Label Item"),
				let expression = caseLabelItem.subtrees.first?.subtrees.first
			{
				let translateExpression = try translate(expression: expression)
				caseExpression = translateExpression
			}
			else {
				caseExpression = nil
			}

			guard let braceStatement = caseSubtree.subtree(named: "Brace Statement") else {
				return try unexpectedASTStructureError(
					"Unable to find a case's statements",
					AST: switchStatement)
			}

			let translatedStatements = try translate(braceStatement: braceStatement)

			cases.append(GRYASTSwitchCase(
				expression: caseExpression, statements: translatedStatements))
		}

		return .switchStatement(
			convertsToExpression: nil, expression: translatedExpression, cases: cases)
	}

	internal func translateDeclarationsAndConditions(
		forIfStatement ifStatement: GRYSwiftAST) throws
		-> (declarations: [GRYASTVariableDeclaration], conditions: [GRYExpression])
	{
		guard ifStatement.name == "If Statement" || ifStatement.name == "Guard Statement" else {
			return try (
				declarations: [],
				conditions: [unexpectedExpressionStructureError(
					"Trying to translate \(ifStatement.name) as an if or guard statement",
					AST: ifStatement), ])
		}

		var conditionsResult = [GRYExpression]()
		var declarationsResult = [GRYASTVariableDeclaration]()

		let conditions = ifStatement.subtrees.filter {
			$0.name != "If Statement" && $0.name != "Brace Statement"
		}

		for condition in conditions {
			// If it's an if-let
			if condition.name == "Pattern",
				let optionalSomeElement =
					condition.subtree(named: "Optional Some Element") ?? // Swift 4.1
					condition.subtree(named: "Pattern Optional Some") // Swift 4.2
			{
				let patternNamed: GRYSwiftAST
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
					return try (
					declarations: [],
					conditions: [unexpectedExpressionStructureError(
						"Unable to detect pattern in let declaration",
						AST: ifStatement), ])

				}

				guard let rawType = optionalSomeElement["type"] else {
					return try (
						declarations: [],
						conditions: [unexpectedExpressionStructureError(
							"Unable to detect type in let declaration",
							AST: ifStatement), ])
				}

				let type = cleanUpType(rawType)

				guard let name = patternNamed.standaloneAttributes.first,
					let lastCondition = condition.subtrees.last else
				{
					return try (
						declarations: [],
						conditions: [unexpectedExpressionStructureError(
							"Unable to get expression in let declaration",
							AST: ifStatement), ])
				}

				let expression = try translate(expression: lastCondition)

				declarationsResult.append(GRYASTVariableDeclaration(
					identifier: name,
					typeName: type,
					expression: expression,
					getter: nil, setter: nil,
					isLet: isLet,
					isImplicit: false,
					isStatic: false,
					extendsType: nil,
					annotations: nil))
			}
			else {
				conditionsResult.append(try translate(expression: condition))
			}
		}

		return (declarations: declarationsResult, conditions: conditionsResult)
	}

	internal func translate(functionDeclaration: GRYSwiftAST) throws -> GRYTopLevelNode? {
		guard ["Function Declaration", "Constructor Declaration"].contains(functionDeclaration.name)
			else
		{
			return try unexpectedASTStructureError(
				"Trying to translate \(functionDeclaration.name) as 'Function Declaration'",
				AST: functionDeclaration)
		}

		// Getters and setters will appear again in the Variable Declaration AST and get translated
		let isGetterOrSetter =
			(functionDeclaration["getter_for"] != nil) || (functionDeclaration["setter_for"] != nil)
		let isImplicit = functionDeclaration.standaloneAttributes.contains("implicit")
		guard !isImplicit && !isGetterOrSetter else {
			return nil
		}

		let functionName = functionDeclaration.standaloneAttributes.first ?? ""

		let access = functionDeclaration["access"]

		// Find out if it's static and if it's mutating
		guard let interfaceType = functionDeclaration["interface type"],
			let interfaceTypeComponents = functionDeclaration["interface type"]?
				.split(withStringSeparator: " -> "),
			let firstInterfaceTypeComponent = interfaceTypeComponents.first else
		{
			return try unexpectedASTStructureError(
				"Unable to find out if function is static", AST: functionDeclaration)
		}
		let isStatic = firstInterfaceTypeComponent.contains(".Type")
		let isMutating = firstInterfaceTypeComponent.contains("inout")

		let functionNamePrefix = functionName.prefix { $0 != "(" }

		// Get the function parameters.
		let parameterList: GRYSwiftAST?

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

		// Translate the parameters
		var parameters = [GRYASTFunctionParameter]()
		if let parameterList = parameterList {
			for parameter in parameterList.subtrees {
				if let name = parameter.standaloneAttributes.first,
					let type = parameter["interface type"]
				{
					guard name != "self" else {
						continue
					}

					let parameterName = name
					let parameterApiLabel = parameter["apiName"]
					let parameterType = cleanUpType(type)

					let defaultValue: GRYExpression?
					if let defaultValueTree = parameter.subtrees.first {
						defaultValue = try translate(expression: defaultValueTree)
					}
					else {
						defaultValue = nil
					}

					parameters.append(GRYASTFunctionParameter(
						label: parameterName,
						apiLabel: parameterApiLabel,
						type: parameterType,
						value: defaultValue))
				}
				else {
					return try unexpectedASTStructureError(
						"Unable to detect name or attribute for a parameter",
						AST: functionDeclaration)
				}
			}
		}

		// Translate the return type
		// FIXME: Doesn't allow to return function types
		guard let returnType = interfaceTypeComponents.last else
		{
			return try unexpectedASTStructureError(
				"Unable to get return type", AST: functionDeclaration)
		}

		// Translate the function body
		let statements: [GRYTopLevelNode]
		if let braceStatement = functionDeclaration.subtree(named: "Brace Statement") {
			statements = try translate(braceStatement: braceStatement)
		}
		else {
			statements = []
		}

		return .functionDeclaration(value: GRYASTFunctionDeclaration(
			prefix: String(functionNamePrefix),
			parameters: parameters,
			returnType: returnType,
			functionType: interfaceType,
			isImplicit: isImplicit,
			isStatic: isStatic,
			isMutating: isMutating,
			extendsType: nil,
			statements: statements,
			access: access))
	}

	internal func translate(topLevelCode topLevelCodeDeclaration: GRYSwiftAST) throws
		-> GRYTopLevelNode?
	{
		guard topLevelCodeDeclaration.name == "Top Level Code Declaration" else {
			return try unexpectedASTStructureError(
				"Trying to translate \(topLevelCodeDeclaration.name) as " +
				"'Top Level Code Declaration'",
				AST: topLevelCodeDeclaration)
		}

		guard let braceStatement = topLevelCodeDeclaration.subtree(named: "Brace Statement") else {
			return try unexpectedASTStructureError(
				"Unrecognized structure", AST: topLevelCodeDeclaration)
		}

		let subtrees = try translate(braceStatement: braceStatement)

		return subtrees.first
	}

	internal func translate(variableDeclaration: GRYSwiftAST) throws -> GRYTopLevelNode {
		guard variableDeclaration.name == "Variable Declaration" else {
			return try unexpectedASTStructureError(
				"Trying to translate \(variableDeclaration.name) as 'Variable Declaration'",
				AST: variableDeclaration)
		}

		let isImplicit = variableDeclaration.standaloneAttributes.contains("implicit")

		let annotations = getComment(forNode: variableDeclaration, key: "annotation")

		let isStatic: Bool
		if let accessorDeclaration = variableDeclaration.subtree(named: "Accessor Declaration"),
			let interfaceType = accessorDeclaration["interface type"],
			let firstTypeComponent = interfaceType.split(withStringSeparator: " -> ").first,
			firstTypeComponent.contains(".Type")
		{
			isStatic = true
		}
		else {
			isStatic = false
		}

		guard let identifier =
				variableDeclaration.standaloneAttributes.first(where: { $0 != "implicit" }),
			let rawType = variableDeclaration["interface type"] else
		{
			return try unexpectedASTStructureError(
				"Failed to get identifier and type", AST: variableDeclaration)
		}

		let isLet = variableDeclaration.standaloneAttributes.contains("let")
		let type = cleanUpType(rawType)

		let expression: GRYExpression?
		if let firstBindingExpression = danglingPatternBindings.first {
			if let maybeBindingExpression = firstBindingExpression,
				let bindingExpression = maybeBindingExpression,
				(bindingExpression.identifier == identifier &&
						bindingExpression.type == type) ||
					(bindingExpression.identifier == "<<Error>>")
			{
				expression = bindingExpression.expression
			}
			else {
				expression = nil
			}

			_ = danglingPatternBindings.removeFirst()
		}
		else {
			expression = nil
		}

		var getter: GRYTopLevelNode?
		var setter: GRYTopLevelNode?
		for subtree in variableDeclaration.subtrees
			where !subtree.standaloneAttributes.contains("implicit")
		{
			let access = subtree["access"]

			let statements: [GRYTopLevelNode]
			if let braceStatement = subtree.subtree(named: "Brace Statement") {
				statements = try translate(braceStatement: braceStatement)
			}
			else {
				statements = []
			}

			// Swift 5: "get_for" and "set_for" are the terms used in the Swift 5 AST
			if subtree["getter_for"] != nil || subtree["get_for"] != nil {
				getter = .functionDeclaration(value: GRYASTFunctionDeclaration(
					prefix: "get",
					parameters: [],
					returnType: type,
					functionType: "() -> (\(type))",
					isImplicit: false,
					isStatic: false,
					isMutating: false,
					extendsType: nil,
					statements: statements,
					access: access))
			}
			else if subtree["materializeForSet_for"] != nil ||
				subtree["setter_for"] != nil ||
				subtree["set_for"] != nil
			{
				setter = .functionDeclaration(value: GRYASTFunctionDeclaration(
					prefix: "set",
					parameters: [GRYASTFunctionParameter(
						label: "newValue", apiLabel: nil, type: type, value: nil), ],
					returnType: "()",
					functionType: "(\(type)) -> ()",
					isImplicit: false,
					isStatic: false,
					isMutating: false,
					extendsType: nil,
					statements: statements,
					access: access))
			}
		}

		return .variableDeclaration(value: GRYASTVariableDeclaration(
			identifier: identifier,
			typeName: type,
			expression: expression,
			getter: getter,
			setter: setter,
			isLet: isLet,
			isImplicit: isImplicit,
			isStatic: isStatic,
			extendsType: nil,
			annotations: annotations))
	}

	internal func translate(callExpression: GRYSwiftAST) throws -> GRYExpression {
		guard callExpression.name == "Call Expression" else {
			return try unexpectedExpressionStructureError(
				"Trying to translate \(callExpression.name) as 'Call Expression'",
				AST: callExpression)
		}

		// If the call expression corresponds to an integer literal
		if let argumentLabels = callExpression["arg_labels"] {
			if argumentLabels == "_builtinIntegerLiteral:" ||
				argumentLabels == "_builtinFloatLiteral:"
			{
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

		guard let rawType = callExpression["type"] else {
			return try unexpectedExpressionStructureError(
				"Failed to recognize type", AST: callExpression)
		}
		let type = cleanUpType(rawType)

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
		else {
			return try unexpectedExpressionStructureError(
				"Failed to recognize function name", AST: callExpression)
		}

		let parameters = try translate(callExpressionParameters: callExpression)

		return .callExpression(function: function, parameters: parameters, type: type)
	}

	internal func translate(closureExpression: GRYSwiftAST) throws -> GRYExpression {
		guard closureExpression.name == "Closure Expression" else {
			return try unexpectedExpressionStructureError(
				"Trying to translate \(closureExpression.name) as 'Closure Expression'",
				AST: closureExpression)
		}

		// Get the parameters.
		let parameterList: GRYSwiftAST?

		if let unwrapped = closureExpression.subtree(named: "Parameter List") {
			parameterList = unwrapped
		}
		else {
			parameterList = nil
		}

		// Translate the parameters
		var parameters = [GRYASTLabeledType]()
		if let parameterList = parameterList {
			for parameter in parameterList.subtrees {
				if let name = parameter.standaloneAttributes.first,
					let type = parameter["interface type"]
				{
					parameters.append(GRYASTLabeledType(label: name, type: cleanUpType(type)))
				}
				else {
					return try unexpectedExpressionStructureError(
						"Unable to detect name or attribute for a parameter",
						AST: closureExpression)
				}
			}
		}

		// Translate the return type
		// FIXME: Doesn't allow to return function types
		guard let type = closureExpression["type"] else
		{
			return try unexpectedExpressionStructureError(
				"Unable to get type or return type", AST: closureExpression)
		}

		// Translate the closure body
		guard let lastSubtree = closureExpression.subtrees.last else {
			return try unexpectedExpressionStructureError(
				"Unable to get closure body", AST: closureExpression)
		}

		let statements: [GRYTopLevelNode]
		if lastSubtree.name == "Brace Statement" {
			statements = try translate(braceStatement: lastSubtree)
		}
		else {
			let expression = try translate(expression: lastSubtree)
			statements = [GRYTopLevelNode.expression(expression: expression)]
		}

		return .closureExpression(
			parameters: parameters,
			statements: statements,
			type: cleanUpType(type))
	}

	internal func translate(callExpressionParameters callExpression: GRYSwiftAST) throws
		-> GRYExpression
	{
		guard callExpression.name == "Call Expression" else {
			return try unexpectedExpressionStructureError(
				"Trying to translate \(callExpression.name) as 'Call Expression'",
				AST: callExpression)
		}

		let parameters: GRYExpression
		if let parenthesesExpression = callExpression.subtree(named: "Parentheses Expression") {
			let expression = try translate(expression: parenthesesExpression)
			parameters = .tupleExpression(
				pairs: [GRYASTLabeledExpression(label: nil, expression: expression)])
		}
		else if let tupleExpression = callExpression.subtree(named: "Tuple Expression") {
			parameters = try translate(tupleExpression: tupleExpression)
		}
		else if let tupleShuffleExpression = callExpression
			.subtree(named: "Tuple Shuffle Expression")
		{
			if let parenthesesExpression = tupleShuffleExpression
				.subtree(named: "Parentheses Expression")
			{
				let expression = try translate(expression: parenthesesExpression)
				parameters = .tupleExpression(
					pairs: [GRYASTLabeledExpression(label: nil, expression: expression)])
			}
			else if let tupleExpression = tupleShuffleExpression.subtree(named: "Tuple Expression"),
				let type = tupleShuffleExpression["type"],
				let elements = tupleShuffleExpression["elements"],
				let rawIndices = elements.split(withStringSeparator: ", ").map(Int.init) as? [Int]
			{
				var indices = [GRYTupleShuffleIndex]()
				for rawIndex in rawIndices {
					if rawIndex == -2 {
						guard let variadicCount = tupleShuffleExpression["variadic_sources"]?
							.split(withStringSeparator: ", ").count else
						{
							return try unexpectedExpressionStructureError(
								"Failed to read variadic sources", AST: callExpression)
						}
						indices.append(.variadic(count: variadicCount))
					}
					else if rawIndex == -1 {
						indices.append(.absent)
					}
					else if rawIndex >= 0 {
						indices.append(.present)
					}
					else {
						return try unexpectedExpressionStructureError(
							"Unknown tuple shuffle index: \(rawIndex)", AST: callExpression)
					}
				}

				let labels = String(type.dropFirst().dropLast())
					.split(withStringSeparator: ", ")
					.map { $0.prefix(while: { $0 != ":" }) }
					.map(String.init)
				let expressions = try tupleExpression.subtrees.map(translate(expression:))
				parameters = .tupleShuffleExpression(
					labels: labels, indices: indices, expressions: expressions.array)
			}
			else {
				return try unexpectedExpressionStructureError(
					"Unrecognized structure in parameters", AST: callExpression)
			}
		}
		else {
			return try unexpectedExpressionStructureError(
				"Unrecognized structure in parameters", AST: callExpression)
		}

		return parameters
	}

	internal func translate(tupleExpression: GRYSwiftAST) throws -> GRYExpression {
		guard tupleExpression.name == "Tuple Expression" else {
			return try unexpectedExpressionStructureError(
				"Trying to translate \(tupleExpression.name) as 'Tuple Expression'",
				AST: tupleExpression)
		}

		// Only empty tuples don't have a list of names
		guard let names = tupleExpression["names"] else {
			return .tupleExpression(pairs: [])
		}

		let namesArray = names.split(separator: ",")

		var tuplePairs = [GRYASTLabeledExpression]()

		for (name, expression) in zip(namesArray, tupleExpression.subtrees) {
			let expression = try translate(expression: expression)

			// Empty names (like the underscore in "foo(_:)") are represented by ''
			if name == "_" {
				tuplePairs.append(GRYASTLabeledExpression(label: nil, expression: expression))
			}
			else {
				tuplePairs.append(
					GRYASTLabeledExpression(label: String(name), expression: expression))
			}
		}

		return .tupleExpression(pairs: tuplePairs)
	}

	internal func translate(asNumericLiteral callExpression: GRYSwiftAST) throws -> GRYExpression {
		guard callExpression.name == "Call Expression" else {
			return try unexpectedExpressionStructureError(
				"Trying to translate \(callExpression.name) as 'Call Expression'",
				AST: callExpression)
		}

		// TODO: Negative float literals are translated as positive becuase the AST dump doesn't
		// seemd to include any info showing they're negative.
		if let tupleExpression = callExpression.subtree(named: "Tuple Expression"),
			let literalExpression = tupleExpression.subtree(named: "Integer Literal Expression") ??
				tupleExpression.subtree(named: "Float Literal Expression"),
			let value = literalExpression["value"],

			let constructorReferenceCallExpression = callExpression
				.subtree(named: "Constructor Reference Call Expression"),
			let typeExpression = constructorReferenceCallExpression
				.subtree(named: "Type Expression"),
			let rawType = typeExpression["typerepr"]
		{
			if value.hasPrefix("0b") || value.hasPrefix("0o") ||
				value.hasPrefix("<<memory address>")
			{
				// Fixable
				return try unexpectedExpressionStructureError(
					"No support yet for alternative integer formats", AST: callExpression)
			}

			let signedValue: String
			if literalExpression.standaloneAttributes.contains("negative") {
				signedValue = "-" + value
			}
			else {
				signedValue = value
			}

			let type = cleanUpType(rawType)
			if type == "Double" || type == "Float64" {
				return .literalDoubleExpression(value: Double(signedValue)!)
			}
			else if type == "Float" || type == "Float32" {
				return .literalFloatExpression(value: Float(signedValue)!)
			}
			else if type == "Float80" {
				return try unexpectedExpressionStructureError(
					"No support for 80-bit Floats", AST: callExpression)
			}
			else if type.hasPrefix("U") {
				return .literalUIntExpression(value: UInt64(signedValue)!)
			}
			else {
				if signedValue == "-9223372036854775808" {
					return try unexpectedExpressionStructureError(
						"Kotlin's Long (equivalent to Int64) only goes down to " +
							"-9223372036854775807", AST: callExpression)
				}
				else {
					return .literalIntExpression(value: Int64(signedValue)!)
				}
			}
		}
		else {
			return try unexpectedExpressionStructureError(
				"Unrecognized structure for numeric literal", AST: callExpression)
		}
	}

	internal func translate(asBooleanLiteral callExpression: GRYSwiftAST) throws
		-> GRYExpression
	{
		guard callExpression.name == "Call Expression" else {
			return try unexpectedExpressionStructureError(
				"Trying to translate \(callExpression.name) as 'Call Expression'",
				AST: callExpression)
		}

		if let tupleExpression = callExpression.subtree(named: "Tuple Expression"),
			let booleanLiteralExpression = tupleExpression
				.subtree(named: "Boolean Literal Expression"),
			let value = booleanLiteralExpression["value"]
		{
			return .literalBoolExpression(value: (value == "true"))
		}
		else {
			return try unexpectedExpressionStructureError(
				"Unrecognized structure for boolean literal", AST: callExpression)
		}
	}

	internal func translate(stringLiteralExpression: GRYSwiftAST) throws -> GRYExpression {
		guard stringLiteralExpression.name == "String Literal Expression" else {
			return try unexpectedExpressionStructureError(
				"Trying to translate \(stringLiteralExpression.name) as " +
				"'String Literal Expression'",
				AST: stringLiteralExpression)
		}

		if let value = stringLiteralExpression["value"] {
			return .literalStringExpression(value: value)
		}
		else {
			return try unexpectedExpressionStructureError(
				"Unrecognized structure", AST: stringLiteralExpression)
		}
	}

	internal func translate(interpolatedStringLiteralExpression: GRYSwiftAST) throws
		-> GRYExpression
	{
		guard interpolatedStringLiteralExpression.name == "Interpolated String Literal Expression"
			else
		{
			return try unexpectedExpressionStructureError(
				"Trying to translate \(interpolatedStringLiteralExpression.name) as " +
				"'Interpolated String Literal Expression'",
				AST: interpolatedStringLiteralExpression)
		}

		var expressions = [GRYExpression]()

		for expression in interpolatedStringLiteralExpression.subtrees {
			if expression.name == "String Literal Expression" {
				let expression = try translate(stringLiteralExpression: expression)
				guard case let .literalStringExpression(value: string) = expression else {
					return try unexpectedExpressionStructureError(
						"Failed to translate string literal",
						AST: interpolatedStringLiteralExpression)
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

	internal func translate(declarationReferenceExpression: GRYSwiftAST) throws
		-> GRYExpression
	{
		guard declarationReferenceExpression.name == "Declaration Reference Expression" else {
			return try unexpectedExpressionStructureError(
				"Trying to translate \(declarationReferenceExpression.name) as " +
				"'Declaration Reference Expression'",
				AST: declarationReferenceExpression)
		}

		guard let rawType = declarationReferenceExpression["type"] else {
			return try unexpectedExpressionStructureError(
				"Failed to recognize type", AST: declarationReferenceExpression)
		}
		let type = cleanUpType(rawType)

		let isImplicit = declarationReferenceExpression.standaloneAttributes.contains("implicit")

		if let discriminator = declarationReferenceExpression["discriminator"] {
			let (identifier, isStandardLibrary) = getIdentifierFromDeclaration(discriminator)
			return .declarationReferenceExpression(
				identifier: identifier, type: type, isStandardLibrary: isStandardLibrary,
				isImplicit: isImplicit)
		}
		else if let codeDeclaration = declarationReferenceExpression.standaloneAttributes.first,
			codeDeclaration.hasPrefix("code.")
		{
			let (identifier, isStandardLibrary) = getIdentifierFromDeclaration(codeDeclaration)
			return .declarationReferenceExpression(
				identifier: identifier, type: type, isStandardLibrary: isStandardLibrary,
				isImplicit: isImplicit)
		}
		else if let declaration = declarationReferenceExpression["decl"] {
			let (identifier, isStandardLibrary) = getIdentifierFromDeclaration(declaration)
			return .declarationReferenceExpression(
				identifier: identifier, type: type, isStandardLibrary: isStandardLibrary,
				isImplicit: isImplicit)
		}
		else {
			return try unexpectedExpressionStructureError(
				"Unrecognized structure", AST: declarationReferenceExpression)
		}
	}

	internal func translate(subscriptExpression: GRYSwiftAST) throws -> GRYExpression {
		guard subscriptExpression.name == "Subscript Expression" else {
			return try unexpectedExpressionStructureError(
				"Trying to translate \(subscriptExpression.name) as 'Subscript Expression'",
				AST: subscriptExpression)
		}

		if let rawType = subscriptExpression["type"],
			let parenthesesExpression = subscriptExpression.subtree(
			at: 1,
			named: "Parentheses Expression"),
			let subscriptContents = parenthesesExpression.subtree(at: 0),
			let subscriptedExpression = subscriptExpression.subtree(at: 0)
		{
			let type = cleanUpType(rawType)
			let subscriptContentsTranslation = try translate(expression: subscriptContents)
			let subscriptedExpressionTranslation = try translate(expression: subscriptedExpression)

			return .subscriptExpression(
				subscriptedExpression: subscriptedExpressionTranslation,
				indexExpression: subscriptContentsTranslation, type: type)
		}
		else {
			return try unexpectedExpressionStructureError(
				"Unrecognized structure", AST: subscriptExpression)
		}
	}

	internal func translate(arrayExpression: GRYSwiftAST) throws -> GRYExpression {
		guard arrayExpression.name == "Array Expression" else {
			return try unexpectedExpressionStructureError(
				"Trying to translate \(arrayExpression.name) as 'Array Expression'",
				AST: arrayExpression)
		}

		let expressionsArray = try arrayExpression.subtrees.map(translate(expression:))

		guard let rawType = arrayExpression["type"] else {
			return try unexpectedExpressionStructureError(
				"Failed to get type", AST: arrayExpression)
		}
		let type = cleanUpType(rawType)

		return .arrayExpression(elements: expressionsArray.array, type: type)
	}

	// TODO: Add tests for dictionaries
	internal func translate(dictionaryExpression: GRYSwiftAST) throws -> GRYExpression {
		guard dictionaryExpression.name == "Dictionary Expression" else {
			return try unexpectedExpressionStructureError(
				"Trying to translate \(dictionaryExpression.name) as 'Dictionary Expression'",
				AST: dictionaryExpression)
		}

		var keys = [GRYExpression]()
		var values = [GRYExpression]()
		for tupleExpression in dictionaryExpression.subtrees {
			guard tupleExpression.name == "Tuple Expression" else {
				continue
			}
			guard let keyAST = tupleExpression.subtree(at: 0),
				let valueAST = tupleExpression.subtree(at: 1) else
			{
				return try unexpectedExpressionStructureError(
					"Unable to get either key or value for one of the tuple expressions",
					AST: dictionaryExpression)
			}

			let keyTranslation = try translate(expression: keyAST)
			let valueTranslation = try translate(expression: valueAST)
			keys.append(keyTranslation)
			values.append(valueTranslation)
		}

		guard let type = dictionaryExpression["type"] else {
			return try unexpectedExpressionStructureError(
				"Unable to get type",
				AST: dictionaryExpression)
		}

		return .dictionaryExpression(keys: keys, values: values, type: type)
	}

	// MARK: - Supporting methods
	internal func process(openExistentialExpression: GRYSwiftAST) throws -> GRYSwiftAST {
		guard openExistentialExpression.name == "Open Existential Expression" else {
			_ = try unexpectedExpressionStructureError(
				"Trying to translate \(openExistentialExpression.name) as " +
				"'Open Existential Expression'",
				AST: openExistentialExpression)
			return GRYSwiftAST("Error", [], [:], [])
		}

		guard let replacementSubtree = openExistentialExpression.subtree(at: 1),
			let resultSubtree = openExistentialExpression.subtrees.last else
		{
			_ = try unexpectedExpressionStructureError(
				"Expected the AST to contain 3 subtrees: an Opaque Value Expression, an " +
				"expression to replace the opaque value, and an expression containing " +
				"opaque values to be replaced.",
				AST: openExistentialExpression)
			return GRYSwiftAST("Error", [], [:], [])
		}

		return astReplacingOpaqueValues(in: resultSubtree, with: replacementSubtree)
	}

	internal func astReplacingOpaqueValues(in ast: GRYSwiftAST, with replacementAST: GRYSwiftAST)
		-> GRYSwiftAST
	{
		if ast.name == "Opaque Value Expression" {
			return replacementAST
		}

		var newSubtrees = [GRYSwiftAST]()
		for subtree in ast.subtrees {
			newSubtrees.append(astReplacingOpaqueValues(in: subtree, with: replacementAST))
		}

		return GRYSwiftAST(
			ast.name, ast.standaloneAttributes, ast.keyValueAttributes,
			ArrayReference(array: newSubtrees))
	}

	internal func process(patternBindingDeclaration: GRYSwiftAST) throws {
		guard patternBindingDeclaration.name == "Pattern Binding Declaration" else {
			_ = try unexpectedExpressionStructureError(
				"Trying to translate \(patternBindingDeclaration.name) as " +
				"'Pattern Binding Declaration'",
				AST: patternBindingDeclaration)
			danglingPatternBindings = [errorDanglingPatternDeclaration]
			return
		}

		var result = [PatternBindingDeclaration]()

		let subtrees = patternBindingDeclaration.subtrees
		while !subtrees.isEmpty {
			var pattern = subtrees.removeFirst()
			if pattern.name == "Pattern Typed",
				let newPattern = pattern.subtree(named: "Pattern Named")
			{
				pattern = newPattern
			}

			if let expression = subtrees.first, ASTIsExpression(expression) {
				_ = subtrees.removeFirst()

				let translatedExpression = try translate(expression: expression)

				guard let identifier = pattern.standaloneAttributes.first,
					let rawType = pattern["type"] else
				{
					_ = try unexpectedExpressionStructureError(
						"Type not recognized", AST: patternBindingDeclaration)
					result.append(errorDanglingPatternDeclaration)
					continue
				}

				let type = cleanUpType(rawType)

				result.append(
					(identifier: identifier,
					 type: type,
					 expression: translatedExpression))
			}
			else {
				result.append(nil)
			}
		}

		danglingPatternBindings = result
	}

	internal func getIdentifierFromDeclaration(_ declaration: String)
		-> (declaration: String, isStandardLibrary: Bool)
	{
		let isStandardLibrary = declaration.hasPrefix("Swift")

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

		// If it's an identifier that contains periods, like the range operators `..<` etc
		var beforeLastPeriodIndex = declaration.index(before: lastPeriodIndex)
		while declaration[beforeLastPeriodIndex] == "." {
			lastPeriodIndex = beforeLastPeriodIndex
			beforeLastPeriodIndex = declaration.index(before: lastPeriodIndex)
		}

		let identifierStartIndex = declaration.index(after: lastPeriodIndex)

		let identifier = declaration[identifierStartIndex..<index]

		return (declaration: String(identifier), isStandardLibrary: isStandardLibrary)
	}

	internal func getRangeOfNode(_ ast: GRYSwiftAST) -> Range<Int>? {
		if let rangeString = ast["range"] {
			let wholeStringRange = Range<String.Index>(uncheckedBounds:
				(lower: rangeString.startIndex, upper: rangeString.endIndex))
			if let startRange = rangeString.range(of: "swift:", range: wholeStringRange) {
				let startNumberSuffix = rangeString[startRange.upperBound...]
				let startDigits = startNumberSuffix.prefix(while: { $0.isNumber })
				if let startNumber = Int(startDigits),
					let endRange = rangeString.range(of: "line:", range: wholeStringRange)
				{
					let endNumberSuffix = rangeString[endRange.upperBound...]
					let endDigits = endNumberSuffix.prefix(while: { $0.isNumber })
					if let endNumber = Int(endDigits) {
						return startNumber..<(endNumber + 1)
					}
				}
			}
		}

		return nil
	}

	internal func getComment(forNode ast: GRYSwiftAST, key: String) -> String? {
		if let comment = getComment(forNode: ast), comment.key == key {
			return comment.value
		}
		return nil
	}

	internal func getComment(forNode ast: GRYSwiftAST) -> (key: String, value: String)? {
		if let rangeString = ast["range"] {
			let wholeStringRange = Range<String.Index>(uncheckedBounds:
				(lower: rangeString.startIndex, upper: rangeString.endIndex))
			if let lineRange = rangeString.range(of: "swift:", range: wholeStringRange) {
				let lineNumberSuffix = rangeString[lineRange.upperBound...]
				let lineDigits = lineNumberSuffix.prefix(while: { $0.isNumber })
				if let lineNumber = Int(lineDigits) {
					return sourceFile?.getCommentFromLine(lineNumber)
				}
			}
		}

		return nil
	}

	internal func insertedCode(inRange range: Range<Int>, forKey key: String) -> [GRYTopLevelNode] {
		var result = [GRYTopLevelNode]()
		for lineNumber in range {
			if let insertComment = sourceFile?.getCommentFromLine(lineNumber),
				insertComment.key == key
			{
				result.append(
					.expression(expression: .literalCodeExpression(string: insertComment.value)))
			}
		}
		return result
	}

	internal func cleanUpType(_ type: String) -> String {
		if type.hasPrefix("@lvalue ") {
			return String(type.suffix(from: "@lvalue ".endIndex))
		}
		else if type.hasPrefix("("), type.hasSuffix(")"), !type.contains("->"), !type.contains(",")
		{
			return String(type.dropFirst().dropLast())
		}
		else {
			return type
		}
	}

	internal func ASTIsExpression(_ ast: GRYSwiftAST) -> Bool {
		return ast.name.hasSuffix("Expression") || ast.name == "Inject Into Optional"
	}
}

enum GRYSwiftTranslatorError: Error, CustomStringConvertible {
	case unexpectedASTStructure(
		file: String,
		line: Int,
		function: String,
		message: String,
		AST: GRYSwiftAST)

	var description: String {
		switch self {
		case let .unexpectedASTStructure(
			file: file, line: line, function: function, message: message, AST: ast):

			var nodeDescription = ""
			ast.prettyPrint {
				nodeDescription += $0
			}

			return "Translation error: failed to translate Swift AST into Gryphon AST.\n" +
				"On file \(file), line \(line), function \(function).\n" +
				message + ".\n" +
				"Thrown when translating the following AST node:\n\(nodeDescription)"
		}
	}

	var astName: String {
		switch self {
		case let .unexpectedASTStructure(file: _, line: _, function: _, message: _, AST: ast):
			return ast.name
		}
	}
}

func createUnexpectedASTStructureError(
	file: String = #file, line: Int = #line, function: String = #function, _ message: String,
	AST ast: GRYSwiftAST) -> GRYSwiftTranslatorError
{
	return GRYSwiftTranslatorError.unexpectedASTStructure(
		file: file, line: line, function: function, message: message, AST: ast)
}

func handleUnexpectedASTStructureError(_ error: Error) throws -> GRYTopLevelNode {
	try GRYCompiler.handleError(error)
	return .error
}

func unexpectedASTStructureError(
	file: String = #file, line: Int = #line, function: String = #function, _ message: String,
	AST ast: GRYSwiftAST) throws -> GRYTopLevelNode
{
	let error = createUnexpectedASTStructureError(
		file: file, line: line, function: function, message, AST: ast)
	return try handleUnexpectedASTStructureError(error)
}

func unexpectedExpressionStructureError(
	file: String = #file, line: Int = #line, function: String = #function, _ message: String,
	AST ast: GRYSwiftAST) throws -> GRYExpression
{
	let error = GRYSwiftTranslatorError.unexpectedASTStructure(
		file: file, line: line, function: function, message: message, AST: ast)
	try GRYCompiler.handleError(error)
	return .error
}
