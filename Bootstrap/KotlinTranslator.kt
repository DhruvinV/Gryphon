open class KotlinTranslator {
    companion object {
        var indentationString: String = "\t"
        val errorTranslation: String = "<<Error>>"
        val lineLimit: Int = 100
        var sealedClasses: MutableList<String> = mutableListOf()

        public fun addSealedClass(className: String) {
            sealedClasses.add(className)
        }

        var enumClasses: MutableList<String> = mutableListOf()

        public fun addEnumClass(className: String) {
            enumClasses.add(className)
        }

        var protocols: MutableList<String> = mutableListOf()

        public fun addProtocol(protocolName: String) {
            protocols.add(protocolName)
        }

        var functionTranslations: MutableList<KotlinTranslator.FunctionTranslation> = mutableListOf()

        public fun addFunctionTranslation(newValue: KotlinTranslator.FunctionTranslation) {
            functionTranslations.add(newValue)
        }

        public fun getFunctionTranslation(
            name: String,
            typeName: String)
            : KotlinTranslator.FunctionTranslation?
        {
            for (functionTranslation in functionTranslations) {
                if (functionTranslation.swiftAPIName.startsWith(name) && functionTranslation.typeName == typeName) {
                    return functionTranslation
                }
            }
            return null
        }

        var pureFunctions: MutableList<FunctionDeclarationData> = mutableListOf()

        public fun recordPureFunction(newValue: FunctionDeclarationData) {
            pureFunctions.add(newValue)
        }

        public fun isReferencingPureFunction(callExpression: CallExpressionData): Boolean {
            var finalCallExpression: Expression = callExpression.function

            while (true) {
                if (finalCallExpression is Expression.DotExpression) {
                    val nextCallExpression: Expression = finalCallExpression.rightExpression
                    finalCallExpression = nextCallExpression
                }
                else {
                    break
                }
            }

            if (finalCallExpression is Expression.DeclarationReferenceExpression) {
                val declarationReferenceExpression: DeclarationReferenceData = finalCallExpression.data
                for (functionDeclaration in pureFunctions) {
                    if (declarationReferenceExpression.identifier.startsWith(functionDeclaration.prefix) && declarationReferenceExpression.typeName == functionDeclaration.functionType) {
                        return true
                    }
                }
            }

            return false
        }
    }

    data class FunctionTranslation(
        val swiftAPIName: String,
        val typeName: String,
        val prefix: String,
        val parameters: MutableList<String>
    )

    constructor() {
    }

    private fun translateType(typeName: String): String {
        val typeName: String = typeName.replace("()", "Unit")
        if (typeName.endsWith("?")) {
            return translateType(typeName.dropLast(1)) + "?"
        }
        else if (typeName.startsWith("[")) {
            if (typeName.contains(":")) {
                val innerType: String = typeName.dropLast(1).drop(1)
                val innerTypes: MutableList<String> = Utilities.splitTypeList(innerType)
                val keyType: String = innerTypes[0]
                val valueType: String = innerTypes[1]
                val translatedKey: String = translateType(keyType)
                val translatedValue: String = translateType(valueType)

                return "MutableMap<${translatedKey}, ${translatedValue}>"
            }
            else {
                val innerType: String = typeName.dropLast(1).drop(1)
                val translatedInnerType: String = translateType(innerType)
                return "MutableList<${translatedInnerType}>"
            }
        }
        else if (typeName.startsWith("ArrayClass<")) {
            val innerType: String = typeName.dropLast(1).drop("ArrayClass<".length)
            val translatedInnerType: String = translateType(innerType)
            return "MutableList<${translatedInnerType}>"
        }
        else if (typeName.startsWith("DictionaryClass<")) {
            val innerTypes: String = typeName.dropLast(1).drop("DictionaryClass<".length)
            val keyValue: MutableList<String> = Utilities.splitTypeList(innerTypes)
            val key: String = keyValue[0]
            val value: String = keyValue[1]
            val translatedKey: String = translateType(key)
            val translatedValue: String = translateType(value)

            return "MutableMap<${translatedKey}, ${translatedValue}>"
        }
        else if (Utilities.isInEnvelopingParentheses(typeName)) {
            val innerTypeString: String = typeName.drop(1).dropLast(1)
            val innerTypes: MutableList<String> = Utilities.splitTypeList(innerTypeString, separators = mutableListOf(", "))
            if (innerTypes.size == 2) {
                return "Pair<${innerTypes.joinToString(separator = ", ")}>"
            }
            else {
                return translateType(typeName.drop(1).dropLast(1))
            }
        }
        else if (typeName.contains(" -> ")) {
            val functionComponents: MutableList<String> = Utilities.splitTypeList(typeName, separators = mutableListOf(" -> "))
            val translatedComponents: MutableList<String> = functionComponents.map { translateFunctionTypeComponent(it) }.toMutableList()
            val firstTypes: MutableList<String> = translatedComponents.dropLast(1).map { "(${it})" }.toMutableList()
            val lastType: String = translatedComponents.lastOrNull()!!
            var allTypes: MutableList<String> = firstTypes

            allTypes.add(lastType)

            return allTypes.joinToString(separator = " -> ")
        }
        else {
            return Utilities.getTypeMapping(typeName = typeName) ?: typeName
        }
    }

    private fun translateFunctionTypeComponent(component: String): String {
        if (Utilities.isInEnvelopingParentheses(component)) {
            val openComponent: String = component.drop(1).dropLast(1)
            val componentParts: MutableList<String> = Utilities.splitTypeList(openComponent, separators = mutableListOf(", "))
            val translatedParts: MutableList<String> = componentParts.map { translateType(it) }.toMutableList()

            return translatedParts.joinToString(separator = ", ")
        }
        else {
            return translateType(component)
        }
    }
}

fun translateExpression(expression: Expression, indentation: String): String {
	return ""
}

private fun KotlinTranslator.increaseIndentation(indentation: String): String {
    return indentation + KotlinTranslator.indentationString
}

private fun KotlinTranslator.decreaseIndentation(indentation: String): String {
    return indentation.dropLast(KotlinTranslator.indentationString.length)
}

data class KotlinTranslatorError(
    val errorMessage: String,
    val ast: Statement
): Exception() {
    override fun toString(): String {
        var nodeDescription: String = ""
        ast.prettyPrint(horizontalLimit = 100, printFunction = { nodeDescription += it })
        return "Error: failed to translate Gryphon AST into Kotlin.\n" + errorMessage + ".\n" + "Thrown when translating the following AST node:\n${nodeDescription}"
    }
}

internal fun unexpectedASTStructureError(errorMessage: String, ast: Statement): String {
    val error: KotlinTranslatorError = KotlinTranslatorError(errorMessage = errorMessage, ast = ast)
    Compiler.handleError(error)
    return KotlinTranslator.errorTranslation
}
