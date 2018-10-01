# Compile gyb files
find . -name '*.gyb' | \
while read file; do \
./gyb --line-directive '' -o "${file%.gyb}" "$file"; \
done

# Update AST dumps
perl dump-ast.pl Example\ ASTs/*.swift
perl dump-ast.pl Test\ Files/*.swift

# Lint swift files
if which swiftlint >/dev/null; then
  swiftlint autocorrect
else
  echo "warning: SwiftLint not installed."
fi
