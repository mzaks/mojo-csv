from csv import CsvTable, CsvBuilder
from random import random_ui64, random_float64
from time import perf_counter_ns

fn measure_simd_csv(csv_string: String):
    print("CSV Table with SIMD")
    var min_runtime = 1 << 62
    var column_count = 0
    var row_count = 0
    for _ in range(1):
        var tik = perf_counter_ns()
        var t1 = CsvTable(csv_string, True)
        var tok = perf_counter_ns()
        column_count = t1.column_count
        row_count = t1.row_count()
        if tok - tik < min_runtime:
            min_runtime = tok - tik

    print(len(csv_string), "bytes", column_count, "columns", row_count, "rows", "in", min_runtime / 1_000_000, "ms")

fn measure_csv(csv_string: String):
    print("CSV Table no SIMD")
    var min_runtime = 1 << 62
    var column_count = 0
    var row_count = 0
    for _ in range(1):
        var tik = perf_counter_ns()
        var t1 = CsvTable(csv_string, False)
        var tok = perf_counter_ns()
        column_count = t1.column_count
        row_count = t1.row_count()
        if tok - tik < min_runtime:
            min_runtime = tok - tik

    print(len(csv_string), "bytes", column_count, "columns", row_count, "rows", "in", min_runtime / 1_000_000, "ms")

fn measure_build_csv(csv_string: String):
    print("Build CSV no escaping")
    var t1 = CsvTable(csv_string, False)
    var builder = CsvBuilder(t1.column_count)
    var get_time = 0
    var push_time = 0

    for row in range(t1.row_count()):
        for column in range(t1.column_count):
            var tik = perf_counter_ns()
            var value = t1.get(row, column)
            var tok = perf_counter_ns()
            get_time += tok - tik
            tik = perf_counter_ns()
            builder.push(value, False)
            tok = perf_counter_ns()
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
            var tik = perf_counter_ns()
            var value = t1.get(row, column)
            var tok = perf_counter_ns()
            get_time += tok - tik
            tik = perf_counter_ns()
            builder.push(value, True)
            tok = perf_counter_ns()
            push_time += tok - tik

    var result = builder^.finish()

    print(len(result), "bytes", t1.column_count, "columns", t1.row_count(), "rows", "get in", get_time / 1_000_000, "ms,", "push in", push_time / 1_000_000, "ms")

fn measure_one_mio_int_table_creation():
    var nums = List[UInt64](capacity=1_000_000)
    for _ in range(1_000_000):
        nums.append(random_ui64(0, 1 << 63))

    var builder = CsvBuilder(10)
    var tik = perf_counter_ns()
    for i in range(len(nums)):
        builder.push(nums[i])
    var s = builder^.finish()
    var tok = perf_counter_ns()
    print("CSV with 10 columns of 1 Mio random ints:", len(s), "bytes", "in", (tok - tik) / 1_000_000, "ms")

fn measure_one_mio_float_table_creation():
    var nums = List[Float64](capacity=1_000_000)
    for _ in range(1_000_000):
        nums.append(random_float64())

    var builder = CsvBuilder(10)
    var tik = perf_counter_ns()
    for i in range(len(nums)):
        builder.push(nums[i])
    var s = builder^.finish()
    var tok = perf_counter_ns()
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
