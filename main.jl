using Pkg
Pkg.activate(@__DIR__)

include("src/GLSLTranspiler.jl")

using .GLSLTranspiler

plus_one(a) = a + 1

rand_return() = rand() < 0.5 ? "asd" : 2

bx = 2
test_global = 3

@transpile GLSLTranspiler.glsl_pipeline function test_fn(a::Int64, b::Float64)
    am, bm, cm = 1, 2.0, "lol"

    a += test_global

    some_good = rand() < 0.5 ? 3 : (rand() > 0.2 ? 0 : 1)
    # some_wrong = rand() < 0.5 ? "asd" : (rand() > 0.2 ? 0 : 1)
    # some_wrong = rand_return()

    if b - a == -2
        return 0
    elseif a < -3
        return 2
    else
        a <<= 4
    end

    println("hello from fn defined through @transpile macro")
    c = "some text"
    println(c)
    b = 3.5
    epsilon = 0.01
    d = plus_one(b) + epsilon

    i = 1
    acc = 0

    while false
        #for i in 1:5
        #end

        bx = begin
            sg = 2
            "1 + $sg"
        end
        println(bx)
    end

    #arr = [(i, j) for i in 1:4, j in 3:4]

    #map(arr) do x
    #    x
    #end

    #function some_func()
    #end

    some_bool = a < b <= 7 < d > acc >= 9.0

    while i <= 5
        x = 2
        acc += i
        i += 1
    end

    while i < 5
        x = "asd"
        y = 3

        while false
            z = 3.0
        end

        while false
            z = 'c'
        end

        while false
            z = 2
        end
    end

    acc
end

some_global = 2
some_other_global = 3

#@transpile GLSLTranspiler.glsl_pipeline function test_fn(a, b::Float64)
@skip @glsl function test_fn(a::Int, b::Int)
    # global 1
    some_global = 2
    # local 1.1 because of assignment
    some_other_global = 10

    # global 1
    global some_global
    println(some_global)

    # local 1.1
    acc = 0
    j = 3

    # local 1.1
    while acc <= 5
        # local 1.1.1
        i = 1

        # 1.1 += 1.1.1 + 1.1
        # technically 1.1 = 1.1 + 1.1.1 + 1.1 after the preprocessor stage
        acc += i + b
        # local 1.1
        j = 4

        # local 1.1 && 1.1.1
        while j > 3 && i != 10 && false
            # local 1.1.1.1
            local j, acc
            j = 2
            acc = 3

            # local 1.1.1
            i = 10
        end

        # local 1.1.1
        while i < 5 && false
            # local 1.1.1.2
            i = 3
            local i
        end

        # local 1.1
        # j == 4 here
        println(j)
    end

    # local 1.1
    acc
end

println("\nExecuting function:")
println(test_fn(2, 3.5))
