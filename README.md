# MOJO-CSV

This library provides facilities to read and write data in CSV format according to [RFC-4180](https://www.rfc-editor.org/rfc/rfc4180)

## Writing data to CSV format
To convert data into CSV format user needs to crete an instance of `CsvBuilder`.

The `CsvBuilder` has two instantiation options:
1. Instantiate the builder with column count `CsvBuilder(3)`
2. Instantiate the builder with column names `CsvBuilder("a", "b", "c")`

After the builder is instantiated, it is possible to push values through the following API:

- `fn push[D: DType](inout self, value: SIMD[D, 1]):` Allows to push numeric value
- `fn push(inout self, s: String, consider_escaping: Bool = True):` Allows to push string value, by default, the value will be examined for special characters in order to identify if it needs to be escaped
- `fn push[T: AnyType, to_str: fn(v:T) -> String](inout self, value: T, consider_escaping: Bool = False):` Allows to push any type, given that a function to transform the type into a `String` is provided as compile time parameter, the `consider_escaping` argument acts as described above, the default is set to False
- `fn push_empty(inout self):` functionally same as `push("")`

Based on the provided number of columns, the pushed values will be escaped, if needed and desired and concatenated by `,` or `\r\n` according to RFC-4180. `fn fill_up_row(inout self):` allows to fillup current row with empty values if needed.

To get the CSV formated data, user needs to call `fn finish(owned self) -> String:` which will return the desired string and destroy the builder. The `finish` method internally calls `fill_up_row` and appends `\r\n` to the end of the file, making sure that the resulting string is valid, according to RFC-4180.

### Note:
Pushing string values with `consider_escaping` set to `True` is up to 10x slower, but makes sure that the resulting CSV is valid. In case the user is certain that provided string does not contain special characters, they should set `consider_escaping` parameter to `False`

## Reading CSV formated data
To read a CSV string, the user needs to instantiate a `CsvTable` with the string. By default `CsvTable` will use SIMD based tokenization which is about 20% faster then the non SIMD one. However user can decide to not use the SIMD based tokenization by setting the instantiation argument `with_simd` to `False`.

After the `CsvTable` is instantiated user can examine the number of columns and number fo rows by accessing `column_count` field and calling `fn row_count(self) -> Int:` method.

To get values from the table user can call `fn get(self, row: Int, column: Int) -> String:` method, which returns already unescaped string value.


## Benchmarks
In order, to evaluate the performance characteristics of the library, we provide two CSV examples (downloaded from https://www.stats.govt.nz/large-datasets/csv-files-for-download/, file names `Subnational-period-life-tables-2017-2019-CSV.csv` and `balance-of-payments-and-international-investment-position-june-2023-quarter.csv`)
Based on these files and the benchmark test we run on Apple M1 Mac mini, we expect the library to be able to parse/tokenize 1 GiB under 3 seconds. Iterating over all values as strings should take under 3.5 seconds.
Writing 1 GiB of data without escaping consideration should take under 4 seconds and with escaping considerations under 35 seconds.
