class Box {
	var a: Int = 5
	var b: String
		get() {
			return "get b"
		}
		set(newValue) {
			println("set b")
		}
	internal fun returnFive(): Int {
		return this.a
	}
	internal fun returnInt(a: Int): Int {
		return a
	}
}

fun main(args: Array<String>) {
	val box1: Box = Box()
	println(box1.a)
	println(box1.returnFive())
	println(box1.returnInt(a = 10))
	println(box1.b)
	box1.b = "whatever"
}
