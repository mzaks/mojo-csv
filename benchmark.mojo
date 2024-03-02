from csv import CsvTable, CsvBuilder
from math import min
from random import random_ui64, random_float64
from time import now

fn measure_simd_csv(csv_string: String):
    print("CSV Table with SIMD")
    var min_runtime = 1 << 62
    var column_count = 0
    var row_count = 0
    for _ in range(1):
        var tik = now()
        var t1 = CsvTable(csv_string, True)
        var tok = now()
        column_count = t1.column_count
        row_count = t1.row_count()
        min_runtime = min(min_runtime, tok - tik)

    print(len(csv_string), "bytes", column_count, "columns", row_count, "rows", "in", min_runtime / 1_000_000, "ms")

fn measure_csv(csv_string: String):
    print("CSV Table no SIMD")
    var min_runtime = 1 << 62
    var column_count = 0
    var row_count = 0
    for _ in range(1):
        var tik = now()
        var t1 = CsvTable(csv_string, False)
        var tok = now()
        column_count = t1.column_count
        row_count = t1.row_count()
        min_runtime = min(min_runtime, tok - tik)

    print(len(csv_string), "bytes", column_count, "columns", row_count, "rows", "in", min_runtime / 1_000_000, "ms")

fn measure_build_csv(csv_string: String):
    print("Build CSV no escaping")
    var t1 = CsvTable(csv_string, False)
    var builder = CsvBuilder(t1.column_count)
    var get_time = 0
    var push_time = 0
    
    for row in range(t1.row_count()):
        for column in range(t1.column_count):
            var tik = now()
            var value = t1.get(row, column)
            var tok = now()
            get_time += tok - tik
            tik = now()
            builder.push(value, False)
            tok = now()
            push_time += tok - tik
    var result = builder^.finish()

    print(len(result), "bytes", t1.column_count, "columns", t1.row_count(), "rows", "get in", get_time / 1_000_000, "ms,", "push in", push_time / 1_000_000, "ms")

fn measure_build_csv_consider_escaping(csv_string: String):
    print("Build CSV consider escaping")
    var t1 = CsvTable(csv_string, True)
    var builder = CsvBuilder(t1.column_count)
    var get_time = 0
    var push_time = 0
    
    for row in range(t1.row_count()):
        for column in range(t1.column_count):
            var tik = now()
            var value = t1.get(row, column)
            var tok = now()
            get_time += tok - tik
            tik = now()
            builder.push(value, True)
            tok = now()
            push_time += tok - tik

    var result = builder^.finish()

    print(len(result), "bytes", t1.column_count, "columns", t1.row_count(), "rows", "get in", get_time / 1_000_000, "ms,", "push in", push_time / 1_000_000, "ms")

fn measure_one_mio_int_table_creation():
    var nums = DynamicVector[UInt64](capacity=1_000_000)
    for _ in range(1_000_000):
        nums.push_back(random_ui64(0, 1 << 63))
    
    var builder = CsvBuilder(10)
    var tik = now()
    for i in range(len(nums)):
        builder.push[DType.uint64](nums[i])
    var s = builder^.finish()
    var tok = now()
    print("CSV with 10 columns of 1 Mio random ints:", len(s), "bytes", "in", (tok - tik) / 1_000_000, "ms")

fn measure_one_mio_float_table_creation():
    var nums = DynamicVector[Float64](capacity=1_000_000)
    for _ in range(1_000_000):
        nums.push_back(random_float64())
    
    var builder = CsvBuilder(10)
    var tik = now()
    for i in range(len(nums)):
        builder.push[DType.float64](nums[i])
    var s = builder^.finish()
    var tok = now()
    print("CSV with 10 columns of 1 Mio radom floats:", len(s), "bytes", "in", (tok - tik) / 1_000_000, "ms")

fn main():
    measure_one_mio_int_table_creation()
    measure_one_mio_float_table_creation()
    try:
        with open("example_needs_escaping.csv", "r") as f:
            var csv_string = f.read()
            measure_csv(csv_string)
            measure_simd_csv(csv_string)
            measure_build_csv(csv_string)
            measure_build_csv_consider_escaping(csv_string)
        with open("example_no_escaping.csv", "r") as f:
            var csv_string = f.read()
            measure_csv(csv_string)
            measure_simd_csv(csv_string)
            measure_build_csv(csv_string)
            measure_build_csv_consider_escaping(csv_string)
    except e:
        print("failed to laod file:", e)

    