public class GRYKotlinTranslator {
	/// Used for the translation of Swift types into Kotlin types.
	static let typeMappings = ["Bool": "Boolean", "Error": "Exception"]
	
	private func translateType(_ type: String) -> String {
		return GRYKotlinTranslator.typeMappings[type] ?? type
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
	Swift variables declared with a value, such as `var x = 0`, are represented in a weird way in the AST:
	first comes a `Pattern Binding Declaration` containing the variable's name, its type, and
	its initial value; then comes the actual `Variable Declaration`, but in a different branch of the AST and
	with no information on the previously mentioned initial value.
	Since both of them have essential information, we need both at the same time to translate a variable
	declaration. However, since they are in unpredictably different branches, it's hard to find the Variable
	Declaration when we first read the Pattern Binding Declaration.
	
	The solution then is to temporarily save the Pattern Binding Declaration's information on this variable. Then,
	once we find the Variable Declaration, we check to see if the stored value is appropriate
	and then use all the information available to complete the translation process. This variable is then reset to nil.
	
	- SeeAlso: translate(variableDeclaration:, withIndentation:)
	*/
	var danglingPatternBinding: (identifier: String, type: String, translatedExpression: String)?
	
	// MARK: - Interface

	/**
	Translates the swift statements in the `ast` into kotlin code.
	
	The swift AST may contain either top-level statements (such as in a "main" file), declarations
	(i.e. function or class declarations), or both. Any declarations will be translated at the beggining
	of the file, and any top-level statements will be wrapped in a `main` function and added to the end
	of the file.
	
	If no top-level statements are found, the main function is ommited.
	
	This function should be given the AST of a single source file, and should provide a translation of that
	source file's contents.
	
	- Parameter ast: The AST, obtained from swift, containing a "Source File" node at the root.
	- Returns: A kotlin translation of the contents of the AST.
	*/
	public func translateAST(_ ast: GRYAst) -> String {
		// First, translate declarations that shouldn't be inside the main function
		let declarationNames = ["Class Declaration", "Extension Declaration", "Function Declaration", "Enum Declaration"]
		let isDeclaration = { (ast: GRYAst) -> Bool in declarationNames.contains(ast.name) }
		
		let declarations = ast.subTrees.filter(isDeclaration)
		
		var result = translate(subTrees: declarations, withIndentation: "")
		
		// Then, translate the remaining statements (if there are any) and wrap them in the main function
		let indentation = increaseIndentation("")
		let statements = ast.subTrees.filter({!isDeclaration($0)})
		let statementsString = translate(subTrees: statements, withIndentation: indentation)
		guard !statementsString.isEmpty else { return result }
		
		// Add newline between declarations and the main function, if needed
		if !result.isEmpty {
			result += "\n"
		}
		
		result += "fun main(args: Array<String>) {\n\(statementsString)}\n"
		
		return result
	}
	
	// MARK: - Implementation
	
	private func translate(subTrees: [GRYAst], withIndentation indentation: String) -> String {
		var result = ""
		
		for subTree in subTrees {
			if shouldIgnoreNext {
				shouldIgnoreNext = false
				continue
			}
			
			switch subTree.name {
			case "Import Declaration": break
			case "Class Declaration":
				let string = translate(classDeclaration: subTree, withIndentation: indentation)
				result += string
			case "Constructor Declaration":
				let string = translate(constructorDeclaration: subTree, withIndentation: indentation)
				result += string
			case "Destructor Declaration":
				let string = translate(destructorDeclaration: subTree, withIndentation: indentation)
				result += string
			case "Enum Declaration":
				let string = translate(enumDeclaration: subTree, withIndentation: indentation)
				result += string
			case "Extension Declaration":
				let string = translate(subTrees: subTree.subTrees, withIndentation: indentation)
				result += string
			case "Function Declaration":
				let string = translate(functionDeclaration: subTree, withIndentation: indentation)
				result += string
			case "Top Level Code Declaration":
				let string = translate(topLevelCode: subTree, withIndentation: indentation)
				result += string
			case "Throw Statement":
				let string = translate(throwStatement: subTree, withIndentation: indentation)
				result += string
			case "Variable Declaration":
				let string = translate(variableDeclaration: subTree, withIndentation: indentation)
				result += string
			case "Assign Expression":
				let string = translate(assignExpression: subTree, withIndentation: indentation)
				result += string
			case "Guard Statement":
				result += translate(ifStatement: subTree, asGuard: true, withIndentation: indentation)
			case "If Statement":
				result += translate(ifStatement: subTree, withIndentation: indentation)
			case "Pattern Binding Declaration":
				process(patternBindingDeclaration: subTree)
			case "Return Statement":
				result += translate(returnStatement: subTree, withIndentation: indentation)
			case "Call Expression":
				let string = translate(callExpression: subTree)
				if !string.isEmpty {
					result += indentation + string + "\n"
				}
			default:
				if subTree.name.hasSuffix("Expression") {
					result += indentation + translate(expression: subTree) + "\n"
				}
				else {
					result += "<Unknown: \(subTree.name)>\n\n"
				}
			}
		}
		
		return result
	}
	
	private func process(patternBindingDeclaration: GRYAst) {
		precondition(patternBindingDeclaration.name == "Pattern Binding Declaration")

		let expression = patternBindingDeclaration.subTrees.last!
		guard ASTIsExpression(expression) else { return }
		
		let binding: GRYAst
		if let unwrappedBinding = patternBindingDeclaration.subTree(named: "Pattern Typed")?.subTree(named: "Pattern Named") {
			binding = unwrappedBinding
		}
		else {
			binding = patternBindingDeclaration.subTree(named: "Pattern Named")!
		}
		
		
		let identifier = binding.standaloneAttributes[0]
		let rawType = binding.keyValueAttributes["type"]!
		let type = translateType(rawType)
		
		danglingPatternBinding = (identifier: identifier,
								  type: type,
								  translatedExpression: translate(expression: expression))
	}
	
	private func translate(topLevelCode: GRYAst, withIndentation indentation: String) -> String {
		precondition(topLevelCode.name == "Top Level Code Declaration")
		
		let braceStatement = topLevelCode.subTree(named: "Brace Statement")!
		return translate(subTrees: braceStatement.subTrees, withIndentation: indentation)
	}
	
	private func translate(enumDeclaration: GRYAst, withIndentation indentation: String) -> String {
		precondition(enumDeclaration.name == "Enum Declaration")
		
		let enumName = enumDeclaration.standaloneAttributes[0]
		
		GRYKotlinTranslator.enums.append(enumName)
		
		let access = enumDeclaration.keyValueAttributes["access"]!
		
		if let inheritanceList = enumDeclaration.keyValueAttributes["inherits"] {
			let rawInheritanceArray = inheritanceList.split(withStringSeparator: ", ")
			var inheritanceArray = rawInheritanceArray.map { GRYKotlinTranslator.typeMappings[$0] ?? $0 }
			inheritanceArray[0] = inheritanceArray[0] + "()"

			let inheritanceString = inheritanceArray.joined(separator: ", ")
			
			var result = "\(indentation)\(access) sealed class \(enumName): \(inheritanceString) {\n"
			
			let increasedIndentation = increaseIndentation(indentation)
			
			let enumElementDeclarations = enumDeclaration.subTrees.filter { $0.name == "Enum Element Declaration" }
			for enumElementDeclaration in enumElementDeclarations {
				let elementName = enumElementDeclaration.standaloneAttributes[0]
				
				let capitalizedElementName = elementName.capitalizedAsCamelCase
				
				result += "\(increasedIndentation)class \(capitalizedElementName): \(enumName)()\n"
			}
			
			result += "\(indentation)}\n"
			
			return result
		}
		
		return "\(indentation)<Unknown: non-sealed-class enum>\n"
	}
	
	private func translate(classDeclaration: GRYAst, withIndentation indentation: String) -> String {
		precondition(classDeclaration.name == "Class Declaration")
		
		let className = classDeclaration.standaloneAttributes[0]
	
		let increasedIndentation = increaseIndentation(indentation)
		let classContents = translate(subTrees: classDeclaration.subTrees, withIndentation: increasedIndentation)
		
		return "class \(className) {\n\(classContents)}\n"
	}
	
	private func translate(constructorDeclaration: GRYAst, withIndentation indentation: String) -> String {
		precondition(constructorDeclaration.name == "Constructor Declaration")
		
		guard !constructorDeclaration.standaloneAttributes.contains("implicit") else { return "" }
		
		return "\(indentation)<Unknown: Constructor Declaration>\n"
	}
	
	private func translate(destructorDeclaration: GRYAst, withIndentation indentation: String) -> String {
		precondition(destructorDeclaration.name == "Destructor Declaration")
		
		guard !destructorDeclaration.standaloneAttributes.contains("implicit") else { return "" }
		
		return "\(indentation)<Unknown: Destructor Declaration>\n"
	}
	
	private func translate(functionDeclaration: GRYAst, withIndentation indentation: String) -> String {
		precondition(functionDeclaration.name == "Function Declaration")
		
		let isGetterOrSetter = (functionDeclaration["getter_for"] != nil) || (functionDeclaration["setter_for"] != nil)
		let isImplicit = functionDeclaration.standaloneAttributes.contains("implicit")
		guard !isImplicit && !isGetterOrSetter else { return "" }
		
		let functionName = functionDeclaration.standaloneAttributes[0]
		
		guard !functionName.hasPrefix("GRYInsert(") &&
			!functionName.hasPrefix("GRYAlternative(") &&
			!functionName.hasPrefix("GRYIgnoreNext(") else { return "" }
		
		guard !functionName.hasPrefix("GRYDeclarations(") else {
			let braceStatement = functionDeclaration.subTree(named: "Brace Statement")!
			return translate(subTrees: braceStatement.subTrees, withIndentation: indentation)
		}
		
		guard functionDeclaration.standaloneAttributes.count <= 1 else {
			return "// <Generic function declaration: \(functionName)>"
		}
		
		var indentation = indentation
		var result = ""
		
		result += indentation
		
		if let access = functionDeclaration["access"] {
			result += access + " "
		}
		
		result += "fun "
		
		let functionNamePrefix = functionName.prefix { $0 != "(" }
		
		result += functionNamePrefix + "("
		
		var parameterStrings = [String]()
		
		let parameterList: GRYAst?
		if let list = functionDeclaration.subTree(named: "Parameter List"),
			let parameter = list.subTrees.first,
			let name = parameter.standaloneAttributes.first,
			name != "self"
		{
			parameterList = list
		}
		else if functionDeclaration.subTrees.count > 1,
			functionDeclaration.subTrees[1].name == "Parameter List"
		{
			parameterList = functionDeclaration.subTrees[1]
		}
		else {
			parameterList = nil
		}
		
		if let parameterList = parameterList {
			for parameter in parameterList.subTrees {
				let name = parameter.standaloneAttributes[0]
				guard name != "self" else { continue }
				
				let rawType = parameter["interface type"]!
				let type = translateType(rawType)
				parameterStrings.append(name + ": " + type)
			}
		}
		
		result += parameterStrings.joined(separator: ", ")
		
		result += ")"
		
		// TODO: Doesn't allow to return function types
		let rawType = functionDeclaration["interface type"]!.split(withStringSeparator: " -> ").last!
		let returnType = translateType(rawType)
		if returnType != "()" {
			result += ": " + returnType
		}
		
		result += " {\n"
		
		indentation = increaseIndentation(indentation)
		
		let braceStatement = functionDeclaration.subTree(named: "Brace Statement")!
		result += translate(subTrees: braceStatement.subTrees, withIndentation: indentation)
		
		indentation = decreaseIndentation(indentation)
		
		result += indentation + "}\n"
		
		return result
	}
	
	private func translate(ifStatement: GRYAst,
						   asElseIf isElseIf: Bool = false,
						   asGuard isGuard: Bool = false,
						   withIndentation indentation: String) -> String
	{
		precondition(ifStatement.name == "If Statement" || ifStatement.name == "Guard Statement")

		let (letDeclarationsString, conditionString) = translateDeclarationsAndConditions(forIfStatement: ifStatement,
																						  withIndentation: indentation)
		
		let increasedIndentation = increaseIndentation(indentation)
		
		var elseIfString = ""
		var elseString = ""
		let braceStatement: GRYAst
		
		if ifStatement.subTrees.count > 2,
			let lastAST = ifStatement.subTrees.last,
			lastAST.name == "If Statement"
		{
			braceStatement = ifStatement.subTrees.dropLast().last!

			let elseIfAST = lastAST
			elseIfString = translate(ifStatement: elseIfAST, asElseIf: true, withIndentation: indentation)
		}
		else if ifStatement.subTrees.count > 2,
			let lastAST = ifStatement.subTrees.last,
			lastAST.name == "Brace Statement",
			ifStatement.subTrees.dropLast().last!.name == "Brace Statement"
		{
			braceStatement = ifStatement.subTrees.dropLast().last!

			let elseAST = lastAST
			let statementsString = translate(subTrees: elseAST.subTrees, withIndentation: increasedIndentation)
			elseString = "\(indentation)else {\n\(statementsString)\(indentation)}\n"
		}
		else {
			braceStatement = ifStatement.subTrees.last!
		}
		
		let statements = braceStatement.subTrees
		let statementsString = translate(subTrees: statements, withIndentation: increasedIndentation)
		
		let keyword = isElseIf ? "else if" : "if"
		let parenthesizedCondition = isGuard ? "(!(\(conditionString)))" : "(\(conditionString))"
		
		let ifString = "\(letDeclarationsString)\(indentation)\(keyword) \(parenthesizedCondition) {\n\(statementsString)\(indentation)}\n"
		
		return ifString + elseIfString + elseString
	}
	
	private func translateDeclarationsAndConditions(forIfStatement ifStatement: GRYAst, withIndentation indentation: String)
		-> (letDeclarationsString: String, conditionString: String)
	{
		precondition(ifStatement.name == "If Statement" || ifStatement.name == "Guard Statement")

		var conditionStrings = [String]()
		var letDeclarations = [String]()
		
		let conditions = ifStatement.subTrees.filter { $0.name != "If Statement" && $0.name != "Brace Statement" }
		
		for condition in conditions {
			// If it's an if-let
			if condition.name == "Pattern" {
				let optionalSomeElement = condition.subTree(named: "Optional Some Element")!
				
				let patternNamed: GRYAst
				let varOrValKeyword: String
				if let patternLet = optionalSomeElement.subTree(named: "Pattern Let") {
					patternNamed = patternLet.subTree(named: "Pattern Named")!
					varOrValKeyword = "val"
				}
				else {
					patternNamed = optionalSomeElement.subTree(named: "Pattern Variable")!.subTree(named: "Pattern Named")!
					varOrValKeyword = "var"
				}
				
				let typeString: String
				if let rawType = optionalSomeElement["type"] {
					let type = translateType(rawType)
					typeString = ": \(type)"
				}
				else {
					typeString = ""
				}
				
				let name = patternNamed.standaloneAttributes.first!
				
				let expressionString = translate(expression: condition.subTrees.last!)
				
				letDeclarations.append("\(indentation)\(varOrValKeyword) \(name)\(typeString) = \(expressionString)\n")
				conditionStrings.append("\(name) != null")
			}
			else {
				conditionStrings.append(translate(expression: condition))
			}
		}
		let letDeclarationsString = letDeclarations.joined()
		let conditionString = conditionStrings.joined(separator: " && ")
		
		return (letDeclarationsString, conditionString)
	}
	
	private func translate(throwStatement: GRYAst,
						   withIndentation indentation: String) -> String
	{
		precondition(throwStatement.name == "Throw Statement")
		
		let expression = throwStatement.subTrees.last!
		let expressionString = translate(expression: expression)
		return "\(indentation)throw \(expressionString)\n"
	}
	
	private func translate(returnStatement: GRYAst,
						   withIndentation indentation: String) -> String
	{
		precondition(returnStatement.name == "Return Statement")
		
		if let expression = returnStatement.subTrees.last {
			let expressionString = translate(expression: expression)
			return "\(indentation)return \(expressionString)\n"
		}
		else {
			return "\(indentation)return\n"
		}
	}
	
	/**
	Translates a swift variable declaration into kotlin code.
	
	This function checks the value stored in `danglingPatternBinding`. If a value is present and it's
	consistent with this variable declaration (same identifier and type), we use the expression
	inside it as the initial value for the variable (and the `danglingPatternBinding` is reset to
	`nil`). Otherwise, the variable is declared without an initial value.
	*/
	private func translate(variableDeclaration: GRYAst,
						   withIndentation indentation: String) -> String
	{
		precondition(variableDeclaration.name == "Variable Declaration")
		var result = indentation
		
		let identifier = variableDeclaration.standaloneAttributes[0]
		let rawType = variableDeclaration["interface type"]!
		let type = translateType(rawType)
		
		let hasGetter = variableDeclaration.subTrees.contains(where:
		{ (subTree: GRYAst) -> Bool in
			return subTree.name == "Function Declaration" &&
				!subTree.standaloneAttributes.contains("implicit") &&
				subTree.keyValueAttributes["getter_for"] != nil
		})
		let hasSetter = variableDeclaration.subTrees.contains(where:
		{ (subTree: GRYAst) -> Bool in
			return subTree.name == "Function Declaration" &&
				!subTree.standaloneAttributes.contains("implicit") &&
				subTree.keyValueAttributes["setter_for"] != nil
		})
		
		let keyword: String
		if hasGetter && hasSetter {
			keyword = "var"
		}
		else if hasGetter && !hasSetter {
			keyword = "val"
		}
		else {
			if variableDeclaration.standaloneAttributes.contains("let") {
				keyword = "val"
			}
			else {
				keyword = "var"
			}
		}
		
		let extensionPrefix: String
		if let extensionType = variableDeclaration["extends_type"] {
			extensionPrefix = "\(extensionType)."
		}
		else {
			extensionPrefix = ""
		}
		
		result += "\(keyword) \(extensionPrefix)\(identifier): \(type)"
		
		if let patternBindingExpression = danglingPatternBinding,
			patternBindingExpression.identifier == identifier,
			patternBindingExpression.type == type
		{
			result += " = " + patternBindingExpression.translatedExpression
			danglingPatternBinding = nil
		}
		
		result += "\n"
		
		result += translateGetterAndSetter(forVariableDeclaration: variableDeclaration, withIndentation: indentation)
		
		return result
	}
	
	private func translateGetterAndSetter(forVariableDeclaration variableDeclaration: GRYAst,
										  withIndentation indentation: String) -> String
	{
		var result = ""

		let getSetIndentation = increaseIndentation(indentation)
		for subtree in variableDeclaration.subTrees
			where !subtree.standaloneAttributes.contains("implicit")
		{
			assert(subtree.name == "Function Declaration")
			
			let keyword: String
			
			if subtree["getter_for"] != nil {
				keyword = "get()"
			}
			else {
				keyword = "set(newValue)"
			}
			
			result += "\(getSetIndentation)\(keyword) {\n"
			
			let contentsIndentation = increaseIndentation(getSetIndentation)
			let statements = subtree.subTree(named: "Brace Statement")!.subTrees
			let contentsString = translate(subTrees: statements, withIndentation: contentsIndentation)
			result += contentsString
			
			result += "\(getSetIndentation)}\n"
		}
		
		return result
	}
	
	private func translate(assignExpression: GRYAst, withIndentation indentation: String) -> String {
		precondition(assignExpression.name == "Assign Expression")
		
		let leftExpression = assignExpression.subTrees[0]
		let leftString = translate(expression: leftExpression)
		
		let rightExpression = assignExpression.subTrees[1]
		let rightString = translate(expression: rightExpression)
		
		return "\(indentation)\(leftString) = \(rightString)\n"
	}
	
	private func translate(expression: GRYAst) -> String {
		switch expression.name {
		case "Binary Expression":
			return translate(binaryExpression: expression)
		case "Call Expression":
			return translate(callExpression: expression)
		case "Declaration Reference Expression":
			return translate(declarationReferenceExpression: expression)
		case "Dot Syntax Call Expression":
			return translate(dotSyntaxCallExpression: expression)
		case "String Literal Expression":
			return translate(stringLiteralExpression: expression)
		case "Interpolated String Literal Expression":
			return translate(interpolatedStringLiteralExpression: expression)
		case "Erasure Expression":
			return translate(expression: expression.subTrees.last!)
		case "Prefix Unary Expression":
			return translate(prefixUnaryExpression: expression)
		case "Type Expression":
			return translate(typeExpression: expression)
		case "Member Reference Expression":
			return translate(memberReferenceExpression: expression)
		case "Parentheses Expression":
			return "(" + translate(expression: expression.subTrees[0]) + ")"
		case "Force Value Expression":
			return translate(expression: expression.subTrees[0]) + "!!"
		case "Autoclosure Expression", "Inject Into Optional", "Inout Expression":
			return translate(expression: expression.subTrees.last!)
		case "Load Expression":
			if let innerExpression = expression.subTree(named: "Declaration Reference Expression") {
				return translate(expression: innerExpression)
			}
			else if let innerExpression = expression.subTree(named: "Member Reference Expression") {
				return translate(expression: innerExpression)
			}
			else {
				return "<Unknown expression: \(expression.name)>"
			}
		default:
			return "<Unknown expression: \(expression.name)>"
		}
	}
	
	private func translate(typeExpression: GRYAst) -> String {
		precondition(typeExpression.name == "Type Expression")
		let rawType = typeExpression.keyValueAttributes["typerepr"]!
		return translateType(rawType)
	}
	
	private func translate(dotSyntaxCallExpression: GRYAst) -> String {
		precondition(dotSyntaxCallExpression.name == "Dot Syntax Call Expression")
		let rightHandSide = translate(expression: dotSyntaxCallExpression.subTrees[0])
		
		let leftHandTree = dotSyntaxCallExpression.subTrees[1]
		if leftHandTree.name == "Type Expression" {
			let leftHandSide = translate(typeExpression: leftHandTree)
			
			// Enums become sealed classes, which need parentheses at the end
			if GRYKotlinTranslator.enums.contains(leftHandSide) {
				let capitalizedEnumCase = rightHandSide.capitalizedAsCamelCase
				return "\(leftHandSide).\(capitalizedEnumCase)()"
			}
			else {
				return "\(leftHandSide).\(rightHandSide)"
			}
		}
		else {
			let leftHandSide = translate(expression: leftHandTree)
			return "\(leftHandSide).\(rightHandSide)"
		}
	}
	
	private func translate(binaryExpression: GRYAst) -> String {
		precondition(binaryExpression.name == "Binary Expression")
		
		let operatorIdentifier: String
		
		let dotCallExpression = binaryExpression.subTree(named: "Dot Syntax Call Expression")!
		let declarationReferenceExpression = dotCallExpression.subTree(named: "Declaration Reference Expression")!
		operatorIdentifier = getIdentifierFromDeclaration(declarationReferenceExpression["decl"]!)
		
		let tupleExpression = binaryExpression.subTree(named: "Tuple Expression")!
		let leftHandSide = translate(expression: tupleExpression.subTrees[0])
		let rightHandSide = translate(expression: tupleExpression.subTrees[1])
		
		return "\(leftHandSide) \(operatorIdentifier) \(rightHandSide)"
	}
	
	private func translate(prefixUnaryExpression: GRYAst) -> String {
		precondition(prefixUnaryExpression.name == "Prefix Unary Expression")

		let dotCallExpression = prefixUnaryExpression.subTree(named: "Dot Syntax Call Expression")!
		let declarationReferenceExpression = dotCallExpression.subTree(named: "Declaration Reference Expression")!
		let operatorIdentifier = getIdentifierFromDeclaration(declarationReferenceExpression["decl"]!)
		
		let expression = prefixUnaryExpression.subTrees[1]
		let expressionString = translate(expression: expression)

		return "\(operatorIdentifier)\(expressionString)"
	}

	/**
	Translates a swift call expression into kotlin code.
	
	A call expression is a function call, but it can be explicit (as usual) or implicit (i.e. integer literals).
	Currently, the only implicit calls supported are integer, boolean and nil literals.
	
	As a special case, functions called GRYInsert, GRYAlternative and GRYIgnoreNext are used to directly
	manipulate the resulting kotlin code, and are treated separately below.
	
	As another special case, a call to the `print` function gets renamed to `println` for compatibility with kotlin.
	In the future, this will be done by a more complex system, but for now it allows integration tests to exist.
	
	- Note: If conditions include an "empty" call expression wrapping its real expression. This function handles
	the unwrapping then delegates the translation.
	*/
	private func translate(callExpression: GRYAst) -> String {
		precondition(callExpression.name == "Call Expression")
		
		// If the call expression corresponds to an integer literal
		if let argumentLabels = callExpression["arg_labels"],
			argumentLabels == "_builtinIntegerLiteral:"
		{
			return translate(asNumericLiteral: callExpression)
		}
		// If the call expression corresponds to an boolean literal
		else if let argumentLabels = callExpression["arg_labels"],
			argumentLabels == "_builtinBooleanLiteral:"
		{
			return translate(asBooleanLiteral: callExpression)
		}
		// If the call expression corresponds to `nil`
		else if let argumentLabels = callExpression["arg_labels"],
			argumentLabels == "nilLiteral:"
		{
			return "null"
		}
		else {
			let functionName: String
			
			if callExpression.standaloneAttributes.contains("implicit"),
				let argumentLabels = callExpression["arg_labels"],
				argumentLabels == "",
				let type = callExpression["type"],
				type == "Int1"
			{
				// If it's an empty expression used in an "if" condition
				let containedExpression = callExpression.subTree(named: "Dot Syntax Call Expression")!.subTrees.last!
				return translate(expression: containedExpression)
			}
			if let declarationReferenceExpression = callExpression.subTree(named: "Declaration Reference Expression") {
				functionName = translate(declarationReferenceExpression: declarationReferenceExpression)
			}
			else if let dotSyntaxCallExpression = callExpression.subTree(named: "Dot Syntax Call Expression") {
				let methodName = translate(declarationReferenceExpression: dotSyntaxCallExpression.subTrees[0])
				let methodOwner = translate(expression: dotSyntaxCallExpression.subTrees[1])
				functionName = "\(methodOwner).\(methodName)"
			}
			else if let constructorReferenceCallExpression = callExpression.subTree(named: "Constructor Reference Call Expression") {
				let typeExpression = constructorReferenceCallExpression.subTree(named: "Type Expression")!
				functionName = translate(typeExpression: typeExpression)
			}
			else if let declaration = callExpression["decl"] {
				functionName = getIdentifierFromDeclaration(declaration)
			}
			else {
				return " <Unknown call expression>"
			}
			
			// If we're here, then the call expression corresponds to an explicit function call
			let functionNamePrefix = functionName.prefix(while: { $0 != "(" })
			
			guard functionNamePrefix != "GRYInsert" &&
				functionNamePrefix != "GRYAlternative" else
			{
				return translate(asKotlinLiteral: callExpression,
								 withFunctionNamePrefix: functionNamePrefix)
			}
			
			// A call to `GRYIgnoreNext()` can be used to ignore the next swift statement.
			guard functionNamePrefix != "GRYIgnoreNext" else {
				shouldIgnoreNext = true
				return ""
			}
			
			return translate(asExplicitFunctionCall: callExpression,
							 withFunctionNamePrefix: functionNamePrefix)
		}
	}
	
	/// Translates typical call expressions. The functionNamePrefix is passed as an argument here only
	/// because it has already been calculated by translate(callExpression:).
	private func translate(asExplicitFunctionCall callExpression: GRYAst,
						   withFunctionNamePrefix functionNamePrefix: Substring) -> String
	{
		let functionNamePrefix = (functionNamePrefix == "print") ?
			"println" : String(functionNamePrefix)
		
		let parameters: String
		if let parenthesesExpression = callExpression.subTree(named: "Parentheses Expression") {
			parameters = translate(expression: parenthesesExpression)
		}
		else if let tupleExpression = callExpression.subTree(named: "Tuple Expression") {
			parameters = translate(tupleExpression: tupleExpression)
		}
		else if let tupleShuffleExpression = callExpression.subTree(named: "Tuple Shuffle Expression") {
			if let tupleExpression = tupleShuffleExpression.subTree(named: "Tuple Expression") {
				parameters = translate(tupleExpression: tupleExpression)
			}
			else {
				let parenthesesExpression = tupleShuffleExpression.subTree(named: "Parentheses Expression")!
				parameters = translate(expression: parenthesesExpression)
			}
		}
		else {
			return " <Unknown call expression>"
		}
		
		return "\(functionNamePrefix)\(parameters)"
	}
	
	/// Translates boolean literals, which in swift are modeled as calls to specific builtin functions.
	private func translate(asBooleanLiteral callExpression: GRYAst) -> String {
		precondition(callExpression.name == "Call Expression")
		
		return callExpression.subTree(named: "Tuple Expression")!
			.subTree(named: "Boolean Literal Expression")!["value"]!
	}
	
	/// Translates numeric literals, which in swift are modeled as calls to specific builtin functions.
	private func translate(asNumericLiteral callExpression: GRYAst) -> String {
		precondition(callExpression.name == "Call Expression")

		if let tupleExpression = callExpression.subTree(named: "Tuple Expression"),
		let integerLiteralExpression = tupleExpression.subTree(named: "Integer Literal Expression"),
		let value = integerLiteralExpression["value"],
		
		let constructorReferenceCallExpression = callExpression.subTree(named: "Constructor Reference Call Expression"),
		let typeExpression = constructorReferenceCallExpression.subTree(named: "Type Expression"),
		let type = typeExpression["typerepr"]
		{
			if type == "Double" {
				return value + ".0"
			}
			else {
				return value
			}
		}
		else {
			return "<Unknown literal>"
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
	*/
	private func translate(asKotlinLiteral callExpression: GRYAst,
						   withFunctionNamePrefix functionNamePrefix: Substring) -> String
	{
		precondition(callExpression.name == "Call Expression")
		
		let parameterExpression: GRYAst
		
		if functionNamePrefix == "GRYAlternative" {
			parameterExpression = callExpression.subTree(named: "Tuple Expression")!
		}
		else if functionNamePrefix == "GRYInsert" {
			parameterExpression = callExpression.subTree(named: "Parentheses Expression")!
		}
		else {
			fatalError("Unknown kotlin literal function called.")
		}
		
		let stringExpression = parameterExpression.subTrees.last!
		let string = translate(stringLiteralExpression: stringExpression)
		let unquotedString = String(string.dropLast().dropFirst())
		let unescapedString = removeBackslashEscapes(unquotedString)
		return unescapedString
	}
	
	private func translate(declarationReferenceExpression: GRYAst) -> String {
		precondition(declarationReferenceExpression.name == "Declaration Reference Expression")
		
		if let codeDeclaration = declarationReferenceExpression.standaloneAttributes.first,
			codeDeclaration.hasPrefix("code.")
		{
			return getIdentifierFromDeclaration(codeDeclaration)
		}
		else {
			let declaration = declarationReferenceExpression["decl"]!
			return getIdentifierFromDeclaration(declaration)
		}
	}
	
	private func translate(memberReferenceExpression: GRYAst) -> String {
		precondition(memberReferenceExpression.name == "Member Reference Expression")
		let declaration = memberReferenceExpression["decl"]!
		let member = getIdentifierFromDeclaration(declaration)
		
		let memberOwner = translate(expression: memberReferenceExpression.subTrees[0])
		
		return "\(memberOwner).\(member)"
	}
	
	/**
	Recovers an identifier formatted as a swift AST declaration.
	
	Declaration references are represented in the swift AST Dump in a rather complex format, so a few operations are used to
	extract only the relevant identifier.
	
	For instance: a declaration reference expression referring to the variable `x`, inside the `foo` function,
	in the /Users/Me/Documents/myFile.swift file, will be something like
	`myFile.(file).foo().x@/Users/Me/Documents/MyFile.swift:2:6`, but a declaration reference for the print function
	doesn't have the '@' or anything after it.
	
	Note that this function's job (in the example above) is to extract only the actual `x` identifier.
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
	
	private func translate(tupleExpression: GRYAst) -> String {
		precondition(tupleExpression.name == "Tuple Expression")
		
		// Only empty tuples don't have a list of names
		guard let names = tupleExpression["names"] else {
			return "()"
		}
		
		let namesArray = names.split(separator: ",")
		
		var result = [String]()
		
		for (name, expression) in zip(namesArray, tupleExpression.subTrees) {
			let expressionString = translate(expression: expression)
			
			// Empty names (like the underscore in "foo(_:)") are represented by ''
			if name == "_" {
				result.append("\(expressionString)")
			}
			else {
				result.append("\(name) = \(expressionString)")
			}
		}
		
		return "(" + result.joined(separator: ", ") + ")"
	}

	private func translate(stringLiteralExpression: GRYAst) -> String {
		let value = stringLiteralExpression["value"]!
		return "\"\(value)\""
	}
	
	private func translate(interpolatedStringLiteralExpression: GRYAst) -> String {
		precondition(interpolatedStringLiteralExpression.name == "Interpolated String Literal Expression")
		
		var result = "\""
		
		for expression in interpolatedStringLiteralExpression.subTrees {
			if expression.name == "String Literal Expression" {
				let quotedString = translate(stringLiteralExpression: expression)
				let unquotedString = quotedString.dropLast().dropFirst()
				
				// Empty strings, as a special case, are represented by the swift ast dump
				// as two double quotes with nothing between them, instead of an actual empty string
				guard unquotedString != "\"\"" else { continue }
				
				result += unquotedString
			}
			else {
				let expressionString = translate(expression: expression)
				result += "${\(expressionString)}"
			}
		}
		
		result += "\""
		return result
	}
	
	private func ASTIsExpression(_ ast: GRYAst) -> Bool {
		return ast.name.hasSuffix("Expression") || ast.name == "Inject Into Optional"
	}
	
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

