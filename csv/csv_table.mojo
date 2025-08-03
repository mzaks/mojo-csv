from .string_utils import find_indices, string_from_pointer
from algorithm.functional import vectorize
from sys.info import simdwidthof
from sys.intrinsics import compressed_store
from math import iota
from memory import stack_allocation
from memory.memory import memcpy


alias QUOTE = ord('"')
alias COMMA = ord(",")
alias LF = ord("\n")
alias CR = ord("\r")
alias simd_width_u8 = simdwidthof[DType.uint8]()

struct CsvTable[sep: Int = COMMA]:
    var _inner_string: String
    var _starts: List[Int]
    var _ends: List[Int]
    var column_count: Int

    fn __init__(out self, owned s: String, with_simd: Bool = True):
        self._inner_string = s
        self._starts = List[Int](capacity=10)
        self._ends = List[Int](capacity=10)
        self.column_count = -1
        if with_simd:
            self._simd_parse()
        else:
            self._parse()

    @always_inline
    fn _parse(mut self):
        var length = len(self._inner_string)
        if(length == 0):
            return
        var offset = 0
        var in_double_quotes = False
        self._starts.append(offset)
        while offset < length:
            var c = Int(self._inner_string.unsafe_ptr().load[width=1](offset))
            if c == QUOTE:
                in_double_quotes = not in_double_quotes
                offset += 1
            elif not in_double_quotes and c == sep:
                self._ends.append(offset)
                offset += 1
                self._starts.append(offset)
            elif not in_double_quotes and c == LF:
                self._ends.append(offset)
                if self.column_count == -1:
                    self.column_count = len(self._ends)
                offset += 1
                self._starts.append(offset)
            elif (
                not in_double_quotes
                and c == CR
                and length > offset + 1
                and Int(self._inner_string.unsafe_ptr().load[width=1](offset + 1)) == LF
            ):
                self._ends.append(offset)
                if self.column_count == -1:
                    self.column_count = len(self._ends)
                offset += 2
                self._starts.append(offset)
            else:
                offset += 1

        if self._inner_string[length - 1] == "\n":
            _ = self._starts.pop()
        else:
            self._ends.append(length)

    @always_inline
    fn _simd_parse(mut self):
        var p = UnsafePointer(self._inner_string.unsafe_ptr())
        var string_byte_length = len(self._inner_string)
        if(string_byte_length == 0):
            return
        var in_quotes = False
        var last_chunk__ends_on_cr = False
        self._starts.append(0)

        @always_inline
        @parameter
        fn find_indicies[simd_width: Int](offset: Int):
            var chars = p.load[width=simd_width](offset)
            var quotes = chars == QUOTE
            var separators = chars == sep
            var lfs = chars == LF
            var all_bits = quotes | separators | lfs
            var crs = chars == CR

            var offsets = iota[DType.uint8, simd_width]()
            var sp: UnsafePointer[UInt8] = UnsafePointer[UInt8].alloc(simd_width)
            compressed_store[DType.uint8, simd_width](offsets, sp, all_bits)
            var all_len = all_bits.reduce_bit_count()

            for i in range(all_len):
                var index = Int(sp.load(i))
                if quotes[index]:
                    in_quotes = not in_quotes
                    continue
                if in_quotes:
                    continue
                var current_offset = index + offset
                var rs_compensation: Int
                if index > 0:
                    rs_compensation = Int(lfs[index] & crs[index - 1])
                else:
                    rs_compensation = Int(lfs[index] & last_chunk__ends_on_cr)
                self._ends.append(current_offset - rs_compensation)
                self._starts.append(current_offset + 1)
                if self.column_count == -1 and lfs[index]:
                    self.column_count = len(self._ends)
            last_chunk__ends_on_cr = crs[simd_width - 1]

        vectorize[find_indicies, simd_width_u8](string_byte_length)
        if self._inner_string[string_byte_length - 1] == "\n":
            _ = self._starts.pop()
        else:
            self._ends.append(string_byte_length)

    fn get(self, row: Int, column: Int) -> String:
        if column >= self.column_count:
            return ""

        var index = self.column_count * row + column
        if index >= len(self._ends):
            return ""

        if (
            self._inner_string[self._starts[index]] == '"'
            and self._inner_string[self._ends[index] - 1] == '"'
        ):
            var start = self._starts[index] + 1
            var length = (self._ends[index] - 1) - start
            var p1 = UnsafePointer[UInt8].alloc(length + 1)
            memcpy(p1, UnsafePointer(self._inner_string.unsafe_ptr()).offset(start), length)
            var _inner_string = string_from_pointer(p1, length + 1)
            var quote_indices = find_indices(_inner_string, '"')
            var quotes_count = len(quote_indices)
            if quotes_count == 0 or quotes_count & 1 == 1:
                return _inner_string

            var p = UnsafePointer(_inner_string.unsafe_ptr())
            var length2 = length - (quotes_count >> 1)
            var p2 = UnsafePointer[UInt8].alloc(length2 + 1)
            var offset2 = 0
            memcpy(p2, p, Int(quote_indices[0]))
            offset2 += Int(quote_indices[0])

            for i in range(2, quotes_count, 2):
                var start = Int(quote_indices[i - 1])
                var size = Int(quote_indices[i]) - start
                memcpy(p2.offset(offset2), p.offset(start), size)
                offset2 += size
            var last = Int(quote_indices[quotes_count - 1])
            memcpy(p2.offset(offset2), p.offset(last), length - last)
            return string_from_pointer(p2, length - (quotes_count >> 1) + 1)

        return self._inner_string[self._starts[index] : self._ends[index]]

    fn row_count(self) -> Int:
        return len(self._starts) // self.column_count
