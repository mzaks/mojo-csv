from csv import CsvBuilder, CsvTable
from testing import assert_equal
from time import now

fn test_csv_builder() raises:
    var csv = CsvBuilder("a", "b", "c")
    csv.push(1)
    csv.push(2)
    csv.push(3)
    csv.push(4)
    csv.push(5)
    csv.push(6)
    csv.push("Hello world", False)
    csv.push("Hello \"world\"", True)
    var actual = csv^.finish()
    var expected = "a,b,c\r\n1,2,3\r\n4,5,6\r\nHello world,\"Hello \"\"world\"\"\",\r\n"
    _= assert_equal(actual, expected)

fn test_csv_builder_no_header() raises:
    var csv = CsvBuilder(3)
    csv.push(1)
    csv.push(2)
    csv.push(3)
    csv.push(4)
    csv.push(5)
    csv.push(6)
    csv.push("Hello world", False)
    csv.push("Hello \"world\"", True)
    var actual = csv^.finish()
    var expected = "1,2,3\r\n4,5,6\r\nHello world,\"Hello \"\"world\"\"\",\r\n"
    _= assert_equal(actual, expected)

fn test_csv_extend_buffer() raises:
    var csv = CsvBuilder(1)
    var expected = String("")
    for i in range(2000):
        csv.push(i, False)
        expected += String(i)
        expected += "\r\n"
    var actual = csv^.finish()
    _= assert_equal(actual, expected)

fn test_csv_float_values() raises:
    var csv = CsvBuilder(2)
    csv.push(1)
    csv.push(1.0)
    csv.push[DType.float32](1)
    csv.push(1.1)
    csv.push[DType.float16](1.1)
    csv.push[DType.float32](1.1)
    csv.push[DType.float64](1.1)
    var actual = csv^.finish()
    var expected = "1,1.000000\r\n1.0,1.100000\r\n1.099609375,1.1000000238418579\r\n1.1000000000000001,\r\n"
    _= assert_equal(actual, expected)


@value
@register_passable
struct Range(Stringable):
    var start: Int
    var end: Int

    fn __str__(self) -> String:
        return String(self.start) + ":" + String(self.end)

fn test_csv_custom_values() raises:
    var csv = CsvBuilder(2)
    var r1 = Range(1, 13)
    csv.push_stringabel[Range](r1)
    csv.push(1.0)
    csv.push[DType.float32](1)
    csv.push(1.1)
    csv.push[DType.float16](1.1)
    csv.push[DType.float32](1.1)
    csv.push[DType.float64](1.1)
    var actual = csv^.finish()
    var expected = "1:13,1.000000\r\n1.0,1.100000\r\n1.099609375,1.1000000238418579\r\n1.1000000000000001,\r\n"
    _= assert_equal(actual, expected)

fn test_csv_table() raises:
    var csv = CsvBuilder(3)
    csv.push("Hello")
    csv.push("World")
    csv.push("I am here", True)
    csv.push("What about you, or them?", True)
    csv.push("What about \"you\", or \"them\"?", True)
    var csv_text = csv^.finish()
    var t = CsvTable(csv_text, False)
    _= assert_equal(len(t._starts), 6)
    _= assert_equal(len(t._ends), 6)
    _= assert_equal(t.column_count, 3)
    _= assert_equal(t.row_count(), 2)
    _= assert_equal(t.get(0, 0), "Hello")
    _= assert_equal(t.get(0, 1), "World")
    _= assert_equal(t.get(0, 2), "I am here")
    _= assert_equal(t.get(1, 0), "What about you, or them?")
    _= assert_equal(t.get(1, 1), "What about \"you\", or \"them\"?")
    _= assert_equal(t.get(1, 2), "")

fn test_simd_csv_table() raises:
    var csv = CsvBuilder(3)
    csv.push("Hello")
    csv.push("World")
    csv.push("I am here", True)
    csv.push("What about you, or them?", True)
    csv.push("What about \"you\", or \"them\"?", True)
    var csv_text = csv^.finish()
    var t = CsvTable(csv_text, True)
    _= assert_equal(len(t._starts), 6)
    _= assert_equal(len(t._ends), 6)
    _= assert_equal(t.column_count, 3)
    _= assert_equal(t.row_count(), 2)
    _= assert_equal(t.get(0, 0), "Hello")
    _= assert_equal(t.get(0, 1), "World")
    _= assert_equal(t.get(0, 2), "I am here")
    _= assert_equal(t.get(1, 0), "What about you, or them?")
    _= assert_equal(t.get(1, 1), "What about \"you\", or \"them\"?")
    _= assert_equal(t.get(1, 2), "")


fn main() raises:
    var tik = now()
    test_csv_builder()
    test_csv_builder_no_header()
    test_csv_extend_buffer()
    test_csv_float_values()
    test_csv_custom_values()
    test_csv_table()
    test_simd_csv_table()
    var tok = now()
    print("DONE in", (tok - tik) / 1_000_000, "ms")