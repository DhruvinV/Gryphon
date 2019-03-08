func printNumberName(_ x: Int) {
	switch x {
	case 0:
		print("Zero")
	case 1:
		print("One")
	case 2:
		print("Two")
	case 3:
		print("Three")
	case 4...5:
		print("Four or five")
	case 6..<10:
		print("Less than ten")
	default:
		print("Dunno!")
	}
}

printNumberName(0)
printNumberName(1)
printNumberName(2)
printNumberName(3)
printNumberName(4)
printNumberName(7)
printNumberName(10)

// Return switch
func getNumberName(_ x: Int) -> String {
	switch x {
	case 0:
		return "Zero"
	case 1:
		return "One"
	case 2:
		return "Two"
	case 3:
		return "Three"
	default:
		return "Dunno!"
	}
}

print(getNumberName(0))
print(getNumberName(1))
print(getNumberName(2))
print(getNumberName(3))
print(getNumberName(4))


// Variable declaration switch
var y = 0
var x: Int
switch y {
case 0:
	x = 10
default:
	x = 20
}

print(x)

// Assignment switch
switch y {
case 0:
	x = 100
default:
	x = 200
}

print(x)
