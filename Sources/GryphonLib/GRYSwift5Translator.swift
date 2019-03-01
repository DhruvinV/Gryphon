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

public class GRYSwift5Translator: GRYSwift4Translator {
	override internal func translate(expression: GRYSwiftAST) throws -> GRYExpression {
		switch expression.name {
		case "Interpolated String Literal Expression":
			if let tapExpression = expression.subtree(named: "Tap Expression"),
				let braceStatement = tapExpression.subtree(named: "Brace Statement")
			{
				return try translate(interpolatedStringLiteralExpression: braceStatement)
			}
			else {
				return try unexpectedExpressionStructureError(
					"Expected the Interpolated String Literal Expression to contain a Tap" +
					"Expression containing a Brace Statement containing the String " +
					"interpolation contents",
					AST: expression)
			}
		default:
			return try super.translate(expression: expression)
		}
	}

	override func translate(interpolatedStringLiteralExpression: GRYSwiftAST)
		throws -> GRYExpression
	{
		guard interpolatedStringLiteralExpression.name == "Brace Statement" else {
			return try unexpectedExpressionStructureError(
				"Trying to translate \(interpolatedStringLiteralExpression.name) as " +
				"'Brace Statement'",
				AST: interpolatedStringLiteralExpression)
		}

		var expressions = [GRYExpression]()

		for callExpression in interpolatedStringLiteralExpression.subtrees.dropFirst() {
			guard callExpression.name == "Call Expression",
				let parenthesesExpression = callExpression.subtree(named: "Parentheses Expression"),
				let expression = parenthesesExpression.subtrees.first else
			{
				return try unexpectedExpressionStructureError(
					"Expected the brace statement to contain only Call Expressions containing " +
					"Parentheses Expressions containing the relevant expressions.",
					AST: interpolatedStringLiteralExpression)
			}

			let translatedExpression = try translate(expression: expression)
			expressions.append(translatedExpression)
		}

		return .interpolatedStringLiteralExpression(expressions: expressions)
	}

	override func translate(arrayExpression: GRYSwiftAST) throws -> GRYExpression {
		guard arrayExpression.name == "Array Expression" else {
			return try unexpectedExpressionStructureError(
				"Trying to translate \(arrayExpression.name) as 'Array Expression'",
				AST: arrayExpression)
		}

		// Drop the "Semantic Expression" at the end
		let expressionsToTranslate = arrayExpression.subtrees.dropLast()

		let expressionsArray = try expressionsToTranslate.map(translate(expression:))

		guard let rawType = arrayExpression["type"] else {
			return try unexpectedExpressionStructureError(
				"Failed to get type", AST: arrayExpression)
		}
		let type = cleanUpType(rawType)

		return .arrayExpression(elements: expressionsArray, type: type)
	}
}
