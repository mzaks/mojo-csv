from memory.memory import memcpy
from buffer import Buffer, Dim
from .string_utils import find_indices, contains_any_of, string_from_pointer

alias BufferType = Buffer[DType.int8]
alias CR_CHAR = "\r"
alias CR = ord(CR_CHAR)
alias LF_CHAR = "\n"
alias LF = ord(LF_CHAR)
alias COMMA_CHAR = ","
alias COMMA = ord(COMMA_CHAR)
alias QUOTE_CHAR = '"'
alias QUOTE = UInt8(ord(QUOTE_CHAR))


struct CsvBuilder:
    var _buffer: UnsafePointer[UInt8]
    var _capacity: Int
    var num_bytes: Int
    var _column_count: Int
    var _elements_count: Int
    var _finished: Bool

    fn __init__(out self, column_count: Int):
        self._capacity = 1024
        self._buffer = UnsafePointer[UInt8].alloc(self._capacity)
        self._column_count = column_count
        self._elements_count = 0
        self._finished = False
        self.num_bytes = 0

    fn __init__(out self, *coulmn_names: StaticString):
        self._capacity = 1024
        self._buffer = UnsafePointer[UInt8].alloc(self._capacity)
        self._elements_count = 0
        self._finished = False
        self.num_bytes = 0

        var column_name_list: VariadicList[StaticString] = coulmn_names
        self._column_count = len(column_name_list)
        for i in range(len(column_name_list)):
            self.push(coulmn_names[i])

    fn __del__(owned self):
        if not self._finished:
            self._buffer.free()

    fn push[S: Stringable](mut self, value: S, consider_escaping: Bool = False):
        self.push(String(value), consider_escaping)

    fn push_empty(mut self):
        self.push("", False)

    fn fill_up_row(mut self):
        var num_empty = self._column_count - (self._elements_count % self._column_count)
        if num_empty < self._column_count:
            for _ in range(num_empty):
                self.push_empty()

    fn push(mut self, s: String, consider_escaping: Bool = True):
        if consider_escaping and contains_any_of(
            s, CR_CHAR, LF_CHAR, COMMA_CHAR, QUOTE_CHAR
        ):
            return self.push(QUOTE_CHAR + escape_quotes_in(s) + QUOTE_CHAR, False)

        var size = len(s)
        self._extend_buffer_if_needed(size + 2)
        if self._elements_count > 0:
            if self._elements_count % self._column_count == 0:
                self._buffer.offset(self.num_bytes).store(CR)
                self._buffer.offset(self.num_bytes + 1).store(LF)
                self.num_bytes += 2
            else:
                self._buffer.offset(self.num_bytes).store(COMMA)
                self.num_bytes += 1

        memcpy(self._buffer.offset(self.num_bytes), s.unsafe_ptr(), size)

        self.num_bytes += size
        self._elements_count += 1

    @always_inline
    fn _extend_buffer_if_needed(mut self, size: Int):
        if self.num_bytes + size < self._capacity:
            return
        var new_size = self._capacity
        while new_size < self.num_bytes + size:
            new_size *= 2
        var p = UnsafePointer[UInt8].alloc(new_size)
        memcpy(p, self._buffer, self.num_bytes)
        self._buffer.free()
        self._capacity = new_size
        self._buffer = p

    fn finish(owned self) -> String:
        self._finished = True
        self.fill_up_row()
        self._buffer.offset(self.num_bytes).store(CR)
        self._buffer.offset(self.num_bytes + 1).store(LF)
        self.num_bytes += 3
        return string_from_pointer(self._buffer, self.num_bytes)


fn escape_quotes_in(s: String) -> String:
    var indices = find_indices(s, QUOTE_CHAR)
    var i_size = len(indices)
    if i_size == 0:
        return s

    var size = len(s)
    var p_current = UnsafePointer(s.unsafe_ptr())
    var p_result = UnsafePointer[UInt8].alloc(size + i_size)
    var first_index = Int(indices[0])
    memcpy(p_result, p_current, first_index)
    p_result.offset(first_index).store(QUOTE)
    var offset = first_index + 1
    for i in range(1, len(indices)):
        var c_offset = Int(indices[i - 1])
        var length = Int(indices[i]) - c_offset
        memcpy(p_result.offset(offset), p_current.offset(c_offset), length)
        offset += length
        p_result.offset(offset).store(QUOTE)
        offset += 1

    var last_index = Int(indices[i_size - 1])
    memcpy(p_result.offset(offset), p_current.offset(last_index), size - last_index)
    return string_from_pointer(p_result, size + i_size + 1)
