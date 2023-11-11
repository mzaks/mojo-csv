from csv.string_utils import find_indices, occurrence_count, contains_any_of, print_v

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
