using SoPlex
using Test

@testset "SoPlex instance creation and free" begin
    soplex = SoPlex.SoPlex_create()
    @test SoPlex.SoPlex_numRows(soplex) == 0
    @test SoPlex.SoPlex_numCols(soplex) == 0
    SoPlex.SoPlex_free(soplex)
end

# add tests for MOI wrapper
include("MOI_wrapper.jl")

# add tests for SoPlex
include("SoPlex.jl")