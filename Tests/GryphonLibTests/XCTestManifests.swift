import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
	return [
		testCase(GRYExtensionTest.allTests),
		testCase(GRYKotlinTranslatorTest.allTests),
		testCase(GRYPrintableAsTreeTest.allTests),
		testCase(GRYSExpressionParserTest.allTests),
		testCase(GRYShellTest.allTests),
		testCase(GRYUtilsTest.allTests),
		testCase(IntegrationTest.allTests),
		testCase(AcceptanceTest.allTests)
	]
}
#endif

