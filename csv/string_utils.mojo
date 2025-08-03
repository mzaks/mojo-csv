from algorithm.functional import vectorize
from sys.info import simdwidthof
from sys.intrinsics import compressed_store
from math import iota
from memory import stack_allocation
from time import now
from .vectorize_and_exit import vectorize_and_exit

alias simd_width_i8 = simdwidthof[DType.int8]()

fn find_indices(s: String, c: String) -> List[UInt64]:
    var size = len(s)
    var result = List[UInt64]()
    var char = UInt8(ord(c))
    var p = UnsafePointer(s.unsafe_ptr())

    @parameter
    fn find[simd_width: Int](offset: Int):
        @parameter
        if simd_width == 1:
            if p.offset(offset).load() == char:
                return result.append(offset)
        else:
            var chunk = p.load[width=simd_width](offset)
            var occurrence = chunk == char
            var offsets = iota[DType.uint64, simd_width]() + offset
            var occurrence_count = occurrence.reduce_bit_count()
            var current_len = len(result)
            result.reserve(current_len + occurrence_count)
            result.resize(current_len + occurrence_count, 0)
            compressed_store(offsets, UnsafePointer[UInt64](to=result[current_len]), occurrence)

    vectorize[find, simd_width_i8](size)
    return result


fn occurrence_count(s: String, *c: String) -> Int:
    var size = len(s)
    var result = 0
    var chars = List[UInt8](capacity=len(c))
    for i in range(len(c)):
        chars.append(UInt8(ord(c[i])))
    var p = UnsafePointer(s.unsafe_ptr())

    @parameter
    fn find[simd_width: Int](offset: Int):
        @parameter
        if simd_width == 1:
            for i in range(len(chars)):
                var char = chars[i]
                if p.offset(offset).load() == char:
                    result += 1
                    return
        else:
            var chunk = p.load[width=simd_width](offset)

            var occurrence = SIMD[DType.bool, simd_width](False)
            for i in range(len(chars)):
                occurrence |= chunk == chars[i]
            var occurrence_count = occurrence.reduce_bit_count()
            result += occurrence_count

    vectorize[find, simd_width_i8](size)
    return result


fn contains_any_of(s: String, *c: String) -> Bool:
    var size = len(s)
    var chars = List[UInt8](capacity=len(c))

    for i in range(len(c)):
        chars.append(UInt8(ord(c[i])))
    var p = UnsafePointer(s.unsafe_ptr())
    var flag = False

    @parameter
    fn find[simd_width: Int](i: Int) -> Bool:
        var chunk = p.load[width=simd_width]()
        p = p.offset(simd_width)
        for i in range(len(chars)):
            var occurrence = chunk == chars[i]
            if occurrence.reduce_or():
                flag = True
                return flag
        return False

    vectorize_and_exit[simd_width_i8, find](size)

    return flag


@always_inline
fn string_from_pointer(p: UnsafePointer[UInt8], length: Int) -> String:
    p.store(length - 1, 0)
    return String(unsafe_from_utf8_ptr=p)


fn print_v(v: List[UInt64]):
    print("(" +  String(len(v)) + ")[")
    for i in range(len(v)):
        var end = ", " if i < len(v) - 1 else "]\n"
        print(v[i], end=end)
