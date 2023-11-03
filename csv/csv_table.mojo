from .string_utils import find_indices, string_from_pointer
from algorithm.functional import vectorize
from sys.info import simdwidthof
from sys.intrinsics import compressed_store
from math import iota, reduce_bit_count
from memory import stack_allocation


alias QUOTE = ord('"')
alias COMMA = ord(",")
alias LF = ord("\n")
alias CR = ord("\r")
alias simd_width_u8 = simdwidthof[DType.uint8]()


struct CsvTable:
    var _inner_string: String
    var _starts: DynamicVector[Int]
    var _ends: DynamicVector[Int]
    var column_count: Int

    fn __init__(inout self, owned s: String, with_simd: Bool = True):
        self._inner_string = s
        self._starts = DynamicVector[Int](10)
        self._ends = DynamicVector[Int](10)
        self.column_count = -1
        if with_simd:
            self._simd_parse()
        else:
            self._parse()

    @always_inline
    fn _parse(inout self):
        let length = len(self._inner_string)
        var offset = 0
        var in_double_quotes = False
        self._starts.push_back(offset)
        while offset < length:
            let c = self._inner_string._buffer[offset]
            if c == QUOTE:
                in_double_quotes = not in_double_quotes
                offset += 1
            elif not in_double_quotes and c == COMMA:
                self._ends.push_back(offset)
                offset += 1
                self._starts.push_back(offset)
            elif not in_double_quotes and c == LF:
                self._ends.push_back(offset)
                if self.column_count == -1:
                    self.column_count = len(self._ends)
                offset += 1
                self._starts.push_back(offset)
            elif (
                not in_double_quotes
                and c == CR
                and length > offset + 1
                and self._inner_string._buffer[offset + 1] == LF
            ):
                self._ends.push_back(offset)
                if self.column_count == -1:
                    self.column_count = len(self._ends)
                offset += 2
                self._starts.push_back(offset)
            else:
                offset += 1

        if self._inner_string[length - 1] == "\n":
            _ = self._starts.pop_back()
        else:
            self._ends.push_back(length)

    @always_inline
    fn _simd_parse(inout self):
        let p = DTypePointer[DType.int8](self._inner_string._buffer.data)
        let string_byte_length = len(self._inner_string)
        var in_quotes = False
        var last_chunk__ends_on_cr = False
        self._starts.push_back(0)

        @always_inline
        @parameter
        fn find_indicies[simd_width: Int](offset: Int):
            let chars = p.simd_load[simd_width](offset)
            let quotes = chars == QUOTE
            let commas = chars == COMMA
            let lfs = chars == LF
            let all_bits = quotes | commas | lfs
            let crs = chars == CR

            let offsets = iota[DType.uint8, simd_width]()
            let sp: DTypePointer[DType.uint8] = stack_allocation[
                simd_width, UInt8, simd_width
            ]()
            compressed_store(offsets, sp, all_bits)
            let all_len = reduce_bit_count(all_bits)

            for i in range(all_len):
                let index = sp.load(i).to_int()
                if quotes[index]:
                    in_quotes = not in_quotes
                    continue
                if in_quotes:
                    continue
                let current_offset = index + offset
                let rs_compensation: Int
                if index > 0:
                    rs_compensation = (lfs[index] & crs[index - 1]).to_int()
                else:
                    rs_compensation = (lfs[index] & last_chunk__ends_on_cr).to_int()
                self._ends.push_back(current_offset - rs_compensation)
                self._starts.push_back(current_offset + 1)
                if self.column_count == -1 and lfs[index]:
                    self.column_count = len(self._ends)
            last_chunk__ends_on_cr = crs[simd_width - 1]

        vectorize[simd_width_u8, find_indicies](string_byte_length)
        if self._inner_string[string_byte_length - 1] == "\n":
            _ = self._starts.pop_back()
        else:
            self._ends.push_back(string_byte_length)

    fn get(self, row: Int, column: Int) -> String:
        if column >= self.column_count:
            return ""

        let index = self.column_count * row + column
        if index >= len(self._ends):
            return ""

        if (
            self._inner_string[self._starts[index]] == '"'
            and self._inner_string[self._ends[index] - 1] == '"'
        ):
            let start = self._starts[index] + 1
            let length = (self._ends[index] - 1) - start
            let p1 = Pointer[Int8].alloc(length + 1)
            memcpy(p1, self._inner_string._buffer.data.offset(start), length)
            let _inner_string = string_from_pointer(p1, length + 1)
            let quote_indices = find_indices(_inner_string, '"')
            let quotes_count = len(quote_indices)
            if quotes_count == 0 or quotes_count & 1 == 1:
                return _inner_string

            let p = _inner_string._buffer.data
            let length2 = length - (quotes_count >> 1)
            let p2 = Pointer[Int8].alloc(length2 + 1)
            var offset2 = 0
            memcpy(p2, p, quote_indices[0].to_int())
            offset2 += quote_indices[0].to_int()

            for i in range(2, quotes_count, 2):
                let start = quote_indices[i - 1].to_int()
                let size = quote_indices[i].to_int() - start
                memcpy(p2.offset(offset2), p.offset(start), size)
                offset2 += size
            let last = quote_indices[quotes_count - 1].to_int()
            memcpy(p2.offset(offset2), p.offset(last), length - last)
            _inner_string._strref_keepalive()
            return string_from_pointer(p2, length - (quotes_count >> 1) + 1)

        return self._inner_string[self._starts[index] : self._ends[index]]

    fn row_count(self) -> Int:
        return len(self._starts) // self.column_count
