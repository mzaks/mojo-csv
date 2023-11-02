from algorithm.functional import vectorize
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
    let c_list: VariadicListMem[String] = c
    var chars = UnsafeFixedVector[Int8](len(c_list))
    for i in range(len(c_list)):
        let temp = __get_address_as_lvalue(c[i])
        chars.append(Int8(ord(temp)))
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
        let temp = __get_address_as_lvalue(c[i])
        chars.append(Int8(ord(temp)))
    let p = DTypePointer[DType.int8](s._buffer.data)

    var rest = size
    while rest > 64:
        let chunk = p.offset(size - rest).simd_load[64]()
        for i in range(len(chars)):
            let occurrence = chunk == chars[i]
            if any_true(occurrence):
                return True
        rest -= 64

    if rest >= 32:
        let chunk = p.offset(size - rest).simd_load[32]()
        for i in range(len(chars)):
            let occurrence = chunk == chars[i]
            if any_true(occurrence):
                return True
        rest -= 32

    if rest >= 16:
        let chunk = p.offset(size - rest).simd_load[16]()
        for i in range(len(chars)):
            let occurrence = chunk == chars[i]
            if any_true(occurrence):
                return True
        rest -= 16

    if rest >= 8:
        let chunk = p.offset(size - rest).simd_load[8]()
        for i in range(len(chars)):
            let occurrence = chunk == chars[i]
            if any_true(occurrence):
                return True
        rest -= 8

    if rest >= 4:
        let chunk = p.offset(size - rest).simd_load[4]()
        for i in range(len(chars)):
            let occurrence = chunk == chars[i]
            if any_true(occurrence):
                return True
        rest -= 4

    if rest >= 2:
        let chunk = p.offset(size - rest).simd_load[2]()
        for i in range(len(chars)):
            let occurrence = chunk == chars[i]
            if any_true(occurrence):
                return True
        rest -= 2

    if rest == 1:
        let last = s[size - 1]
        for i in range(len(c_list)):
            let temp = __get_address_as_lvalue(c[i])
            if last == temp:
                return True

    return False


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
