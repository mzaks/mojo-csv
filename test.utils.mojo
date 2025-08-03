from csv.string_utils import contains_any_of
from csv.csv_builder import escape_quotes_in
from testing import assert_equal

alias CR_CHAR = "\r"
alias CR = ord(CR_CHAR)
alias LF_CHAR = "\n"
alias LF = ord(LF_CHAR)
alias COMMA_CHAR = ","
alias COMMA = ord(COMMA_CHAR)
alias QUOTE_CHAR = '"'
alias QUOTE = UInt8(ord(QUOTE_CHAR))

fn simd_u8_to_string[simd_width: Int](vec: SIMD[DType.uint8, simd_width]) -> String:
    var result = String()
    result.write_bytes(vec.as_bytes())
    return result

def test_simd_u8_to_string():
    var data = SIMD[DType.uint8, 16](72, 101, 108, 108, 111, 44, 32, 87, 111, 114, 108, 100, 33, 0, 0, 0)
    var result = simd_u8_to_string(data)
    _= assert_equal(result, 'Hello, World!\x00\x00\x00')

def test_contains_any_of():
    var s1 = 'Hello World'
    var c1 = contains_any_of(
        s1, CR_CHAR, LF_CHAR, COMMA_CHAR, QUOTE_CHAR
    )
    _= assert_equal(c1, False)

    var s2 = 'Hello "World"'
    var c2 = contains_any_of(
        s2, CR_CHAR, LF_CHAR, COMMA_CHAR, QUOTE_CHAR
    )
    _= assert_equal(c2, True)

def test_escape_quotes_in():
    var eqi = escape_quotes_in('Hello "World"')
    _= assert_equal(eqi, 'Hello ""World""')

def main():
    test_contains_any_of()
    test_escape_quotes_in()
    test_simd_u8_to_string()