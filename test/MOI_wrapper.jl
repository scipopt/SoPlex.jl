import SoPlex
using Test

const MOI = SoPlex.MOI

# ============================ /test/MOI_wrapper.jl ============================
module TestMOISoPlex

import SoPlex
using Test

const MOI = SoPlex.MOI
const MOIU = MOI.Utilities

MOIU.@model(ModelData,
            (),
            (MOI.EqualTo, MOI.GreaterThan, MOI.LessThan, MOI.Interval),
            (MOI.SecondOrderCone,),
            (),
            (),
            (MOI.ScalarAffineFunction,),
            (MOI.VectorOfVariables,),
            (MOI.VectorAffineFunction,))

const CACHE = MOIU.UniversalFallback(ModelData{Float64}())
const CACHED = MOIU.CachingOptimizer(CACHE, SoPlex.Optimizer())

# function test_basic_constraint_tests(model, config)
#     MOI.Test.basic_constraint_tests(
#         model,
#         config,
#         delete = false,
#         get_constraint_function = false,
#         get_constraint_set = false,
#         name = false)
# end

#TODO: almost all functions are using unsupported functions
function test_unittest(model, config)
# Test all the functions included in dictionary `MOI.Test.unittests`,
# except functions that are not supported by SoPlex
    MOI.Test.runtests(
        model,
        config,
        exclude=String[
            # add functions that are not supported by SoPlex
            "number_threads",
            "solve_zero_one_with_bounds_1",
            "solve_singlevariable_obj",
            "solve_affine_greaterthan",
            "solve_affine_deletion_edge_cases",
            "solve_affine_lessthan",
            "solve_result_index",
            "solve_with_lowerbound",
            "delete_nonnegative_variables",
            "add_variable",
            "solve_constant_obj",
            "solve_single_variable_dual_max",
            "solve_single_variable_dual_min",
            "delete_variable",
            "solve_time",
            "solve_duplicate_terms_obj",
            "solve_qcp_edge_cases",
            "modification",
        ],
    )
end

#TODO: there is some invalid variable name x somewhere
# function test_modification(model, config)
#     MOI.Test.modificationtest(model, config)
# end


# function test_contlinear(model, config)
#     MOI.Test.contlineartest(model, config)
# end

# function test_contconic(model, config)
#     MOI.Test.contlineartest(model, config)
# end

# function test_intconic(model, config)
#     MOI.Test.intconictest(model, config)
# end

# function test_emptytest(model, ::Any)
#     MOI.Test.emptytest(model)
# end


#these two need a CACHING_OPTIMIZER
# function test_validtest(model, ::Any)
#     MOI.Test.validtest(model)
# end

# function test_orderedindicestest(model, ::Any)
#     MOI.Test.orderedindicestest(model)
# end

function test_SolverName(model, ::Any)
    @test MOI.get(model, MOI.SolverName()) == "SoPlex"
end

# function test_default_objective_test(model, ::Any)
#     MOI.Test.default_objective_test(model)
# end

# function test_default_status_test(model, ::Any)
#     MOI.Test.default_status_test(model)
# end

#TODO: fix right naming -> I think we need to go back to have the dictionary and nothing
# like in HiGHs
# function test_nametest(model, ::Any)
#     MOI.Test.nametest(model)
# end

# function test_scalar_function_constant_not_zero(model, ::Any)
#     MOI.Test.scalar_function_constant_not_zero(model)
# end

# This function runs all functions in this module starting with `test_`.
function runtests()
    model = SoPlex.Optimizer()
    config = Dict(
        "simplex" => MOI.Test.Config(
            Float64,
            atol=1e-6,
            rtol=1e-6,
            exclude=Any[MOI.DualObjectiveValue, MOI.ConstraintName]
        ),
        "CONFIG" => MOI.Test.Config(
            Float64,
            atol=1e-6,
            rtol=1e-6,
            exclude=Any[MOI.DualObjectiveValue, MOI.ConstraintName]
        ),
        "simplex_rational" => MOI.Test.Config(
            Rational{Clong},
            atol = 1e-6,
            rtol = 1e-6,
            exclude=Any[MOI.DualObjectiveValue, MOI.ConstraintName]
        ),
        "CONFIG_rational" => MOI.Test.Config(
            Rational{Clong},
            atol = 1e-6,
            rtol = 1e-6,
            exclude=Any[MOI.DualObjectiveValue, MOI.ConstraintName]
        ),
    )
    @testset "$(solver)" for solver in ["simplex", "CONFIG", "simplex_rational", "CONFIG_rational"]
        for name in names(@__MODULE__; all = true)
            if startswith("$(name)", "test_")
                # exclude tests that are not yet passing or that are to be called in a different fashion
                if !("$(name)" in ["test_emptytest", "test_orderedindicestest", "test_validtest", "test_modification", "test_contconic", "test_contlinear", "test_intconic", "test_emptytest", "test_validtest", "test_orderedindicestest", "test_nametest"])
                    @testset "$(name)" begin
                        getfield(@__MODULE__, name)(model, config[solver])
                    end
                end
            end
        end
    end
end

end # module TestMOISoPlex

@testset "Empty initialized" begin
    o = SoPlex.Optimizer()
    @test MOI.is_empty(o)
end

TestMOISoPlex.runtests()
