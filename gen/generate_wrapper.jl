using Clang

const HEADER_BASE = "/usr/include"

const SOPLEX_SRC = ENV["SOPLEX_SRC_DIR"]
@assert ispath(SOPLEX_SRC)

const SOPLEX_BUILD_DIR = if haskey(ENV, "SOPLEX_BUILD_DIR")
    ENV["SOPLEX_BUILD_DIR"]
else
    p = joinpath(SOPLEX_SRC, "build")
    if ispath(p)
        p
    else
        p = joinpath(SOPLEX_SRC, "debug")
    end
    p
end

@assert ispath(SOPLEX_BUILD_DIR)

soplex_header = joinpath(SOPLEX_SRC, "src", "soplex_interface.h")
@assert isfile(soplex_header)

context = Clang.init(
    headers=[soplex_header],
    common_file="commons.jl",
    output_dir="../src/",
    clang_includes=vcat(Clang.HEADER_BASE, Clang.LLVM_INCLUDE),
    clang_args = ["-I", Clang.HEADER_BASE],
    clang_diagnostics=true,
    header_wrapped=(header, cursorname) -> header == cursorname,
    header_library=header_name -> "libsoplex"
)
Clang.run(context)

rm(joinpath(@__DIR__, "..", "src", "LibTemplate.jl"))
