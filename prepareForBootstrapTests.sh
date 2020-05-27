echo "➡️ [1/4] Building Gryphon..."

if swift build
then
	echo "✅ Done."
	echo ""
else
	echo "🚨 Failed to build Gryphon."
	exit -1
fi


echo "➡️ [2/4] Transpiling the Gryphon source files to Kotlin..."

if bash transpileGryphonSources.sh
then
	echo "✅ Done."
	echo ""
else
	echo "🚨 Failed to transpile the Gryphon source files."
	exit -1
fi


echo "➡️ [3/4] Compiling Kotlin files..."

if bash buildBootstrappedTranspiler.sh 2> .gryphon/kotlinErrors.errors
then
	swift .gryphon/scripts/mapKotlinErrorsToSwift.swift < .gryphon/kotlinErrors.errors
	echo "✅ Done."
	echo ""
else
	swift .gryphon/scripts/mapKotlinErrorsToSwift.swift < .gryphon/kotlinErrors.errors
	echo "🚨 Failed to compile Kotlin files."
	exit -1
fi


echo "➡️ [4/4] Updating the bootstrap outputs..."

for file in Test\ cases/*.swift
do
    if [[ $file == *"errors.swift" ]]; then
        echo "    ↪️ Skipping $file..."
    else
        echo "    ↪️ Updating $file..."

		defaultFinal="";
		if [[ $file == *"-default-final.swift" ]]; then
			defaultFinal="--default-final";
		fi

        if java -jar Bootstrap/kotlin.jar --indentation=t -avoid-unicode -skip-AST-dumps \
            --quiet -emit-swiftAST -emit-rawAST -emit-AST -emit-kotlin $defaultFinal \
            "$file"
        then
            echo "      ✅ Done."
        else
            echo "🚨 Failed!"
            exit -1
        fi
    fi
done

echo "✅ Done."
