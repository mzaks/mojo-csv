from algorithm.functional import vectorize, tile
from sys.info import simdwidthof
from sys.intrinsics import compressed_store
from math import iota, reduce_bit_count, any_true
from memory import stack_allocation
from time import now

alias simd_width_i8 = simdwidthof[DType.int8]()


fn find_indices(s: String, c: String) -> DynamicVector[UInt64]:
    let size = len(s)
    var result = DynamicVector[UInt64]()
    let char = Int8(ord(c))
    let p = DTypePointer[DType.int8](s._buffer.data)
    # result.reserve(size)

    @parameter
    fn find[simd_width: Int](offset: Int):
        @parameter
        if simd_width == 1:
            if p.offset(offset).load() == char:
                return result.push_back(offset)
        else:
            let chunk = p.simd_load[simd_width](offset)
            let occurrence = chunk == char
            let offsets = iota[DType.uint64, simd_width]() + offset
            let occurrence_count = reduce_bit_count(occurrence)
            let current_len = len(result)
            result.reserve(current_len + occurrence_count)
            result.resize(current_len + occurrence_count)
            compressed_store(offsets, result.data.offset(current_len), occurrence)

    vectorize[simd_width_i8, find](size)
    return result


fn occurrence_count(s: String, *c: String) -> Int:
    let size = len(s)
    var result = 0
    var chars = UnsafeFixedVector[Int8](len(c))
    for i in range(len(c)):
        chars.append(Int8(ord(__get_address_as_lvalue(c[i]))))
    let p = DTypePointer[DType.int8](s._buffer.data)

    @parameter
    fn find[simd_width: Int](offset: Int):
        @parameter
        if simd_width == 1:
            for i in range(len(chars)):
                let char = chars[i]
                if p.offset(offset).load() == char:
                    result += 1
                    return
        else:
            let chunk = p.simd_load[simd_width](offset)

            var occurrence = SIMD[DType.bool, simd_width](False)
            for i in range(len(chars)):
                occurrence |= chunk == chars[i]
            let occurrence_count = reduce_bit_count(occurrence)
            result += occurrence_count

    vectorize[simd_width_i8, find](size)
    return result


fn contains_any_of(s: String, *c: String) -> Bool:
    let size = len(s)
    let c_list: VariadicListMem[String] = c
    var chars = UnsafeFixedVector[Int8](len(c_list))
    for i in range(len(c_list)):
        chars.append(Int8(ord(__get_address_as_lvalue(c[i]))))
    let p = DTypePointer[DType.int8](s._buffer.data)

    var flag = False
    var rest = size

    alias tiles = VariadicList(64, 32, 16, 8, 4, 2, 1)

    @parameter
    fn find[simd_width: Int](i: Int):
        let chunk = p.offset(size - rest).simd_load[simd_width]()
        for i in range(len(chars)):
            let occurrence = chunk == chars[i]
            if any_true(occurrence):
                flag = True
                return
        rest -= simd_width

    tile[find, tiles](0, size)

    return flag


@always_inline
fn string_from_pointer(p: DTypePointer[DType.int8], length: Int) -> String:
    # Since Mojo 0.5.0 the pointer needs to provide a 0 terminated byte string
    p.store(length - 1, 0)
    return String(p, length)


fn print_v(v: DynamicVector[UInt64]):
    print_no_newline("(", len(v), ")", "[")
    for i in range(len(v)):
        print_no_newline(v[i], ",")
    print("]")


fn main():
    let r = find_indices(
        "hello world oh my god, this is some great news tight here on the sport", "o"
    )
    print_v(r)
    let c = occurrence_count(
        "hello world oh my god, this is some great news tight here on the sport",
        "o",
        "d",
    )
    print(c)
    let b = contains_any_of(
        "hello world oh my god, this is some great news tight here on the sport!",
        "?",
        "!",
    )
    print(b)
