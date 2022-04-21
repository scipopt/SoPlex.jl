get(ENV, "SOPLEX_DIR", "")
const libsoplex = joinpath(soplex_location, "build", "lib", "libsoplexc.so")

if !isfile(libsoplex)
    using SCIP_jll: libsoplex
end

const depsfile = joinpath(@__DIR__, "deps.jl")
open(depsfile, "w") do f
    print(f, "const libsoplex = \"")
    print(f, libsoplex)
    print(f, "\"")
    println(f)
end
