from math import min
from csv import CsvTable, CsvBuilder
from time import now

fn measure_simd_csv(csv_string: String):
    print("CSV Table with SIMD")
    var min_runtime = 1 << 62
    var column_count = 0
    var row_count = 0
    for _ in range(1):
        let tik = now()
        let t1 = CsvTable(csv_string, True)
        let tok = now()
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
        let tik = now()
        let t1 = CsvTable(csv_string, False)
        let tok = now()
        column_count = t1.column_count
        row_count = t1.row_count()
        min_runtime = min(min_runtime, tok - tik)

    print(len(csv_string), "bytes", column_count, "columns", row_count, "rows", "in", min_runtime / 1_000_000, "ms")

fn measure_build_csv(csv_string: String):
    print("Build CSV no escaping")
    let t1 = CsvTable(csv_string, False)
    var builder = CsvBuilder(t1.column_count)
    var get_time = 0
    var push_time = 0
    
    for row in range(t1.row_count()):
        for column in range(t1.column_count):
            var tik = now()
            let value = t1.get(row, column)
            var tok = now()
            get_time += tok - tik
            tik = now()
            builder.push(value, False)
            tok = now()
            push_time += tok - tik
    let result = builder^.finish()

    print(len(result), "bytes", t1.column_count, "columns", t1.row_count(), "rows", "get in", get_time / 1_000_000, "ms,", "push in", push_time / 1_000_000, "ms")

fn measure_build_csv_consider_escaping(csv_string: String):
    print("Build CSV consider escaping")
    let t1 = CsvTable(csv_string, True)
    var builder = CsvBuilder(t1.column_count)
    var get_time = 0
    var push_time = 0
    
    for row in range(t1.row_count()):
        for column in range(t1.column_count):
            var tik = now()
            let value = t1.get(row, column)
            var tok = now()
            get_time += tok - tik
            tik = now()
            builder.push(value, True)
            tok = now()
            push_time += tok - tik

    let result = builder^.finish()

    print(len(result), "bytes", t1.column_count, "columns", t1.row_count(), "rows", "get in", get_time / 1_000_000, "ms,", "push in", push_time / 1_000_000, "ms")

fn main():
    try:
        with open("example_needs_escaping.csv", "r") as f:
            let csv_string = f.read()
            measure_csv(csv_string)
            measure_simd_csv(csv_string)
            measure_build_csv(csv_string)
            measure_build_csv_consider_escaping(csv_string)
        with open("example_no_escaping.csv", "r") as f:
            let csv_string = f.read()
            measure_csv(csv_string)
            measure_simd_csv(csv_string)
            measure_build_csv(csv_string)
            measure_build_csv_consider_escaping(csv_string)
    except e:
        print("failed to laod file:", e)

    