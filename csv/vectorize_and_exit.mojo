fn vectorize_and_exit[simd_width: Int, workgroup_function: fn[i: Int](Int) capturing [_] -> Bool](size: Int):
    var loops = size // simd_width
    for i in range(loops):
        if workgroup_function[simd_width](i * simd_width):
            return

    var rest = size & (simd_width - 1)
    @parameter
    if simd_width >= 64:
        if rest >= 32:
            if workgroup_function[32](size - rest):
                return
            rest -= 32
    @parameter
    if simd_width >= 32:
        if rest >= 16:
            if workgroup_function[16](size - rest):
                return
            rest -= 16
    @parameter
    if simd_width >= 16:
        if rest >= 8:
            if workgroup_function[8](size - rest):
                return
            rest -= 8
    @parameter
    if simd_width >= 8:
        if rest >= 4:
            if workgroup_function[4](size - rest):
                return
            rest -= 4
    @parameter
    if simd_width >= 4:
        if rest >= 2:
            if workgroup_function[2](size - rest):
                return
            rest -= 2

    if rest == 1:
        _= workgroup_function[1](size - rest)
