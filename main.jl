using Pkg
Pkg.activate(@__DIR__)

include("src/GLSLTranspiler.jl")

using .GLSLTranspiler

plus_one(a) = a + 1

rand_return() = rand() < 0.5 ? "asd" : 2

test_global = 3

@build_tast function test_fn(a::Int64, b::Float64)
    a += test_global

    some_good = rand() < 0.5 ? 3 : (rand() > 0.2 ? 0 : 1)
    #some_wrong = rand() < 0.5 ? "asd" : (rand() > 0.2 ? 0 : 1)

    if b - a == -2
        return 0
    elseif a < -3
        return 2
    else
        a <<= 4
    end

    println("hello from fn defined through @build_tast macro")
    c = "some text"
    println(c)
    b = 3.5
    epsilon = 0.01
    d = plus_one(b) + epsilon

    i = 1
    acc = 0

    while false
        bx = begin
            sg = 2
            "1 + $sg"
        end
    end

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

println("\nExecuting function:")
println(test_fn(2, 3.5))
