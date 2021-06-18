# ============================ /test/MOI_wrapper.jl ============================
module TestMOISoPlex

import SoPlex
using Test

const MOI = SoPlex.MOI

const CONFIG = MOI.Test.TestConfig(
    # Modify tolerances as necessary.
    atol = 1e-6,
    rtol = 1e-6,
    # Set false if dual solutions are not generated
    duals = false,
    # Set false if infeasibility certificates are not generated
    infeas_certificates = false,
    # Use MOI.LOCALLY_SOLVED for local solvers.
    optimal_status = MOI.OPTIMAL,
    # Set true if basis information is available
    basis = false,
)

function test_basic_constraint_tests(model)
    MOI.Test.basic_constraint_tests(
        model,
        CONFIG,
        delete = false,
        get_constraint_function = false,
        get_constraint_set = false,
        name = false)
end

#TODO: almost all functions are using unsupported functions
#function test_unittest(model)
#    # Test all the functions included in dictionary `MOI.Test.unittests`,
#    # except functions that are not supported by SoPlex
#    MOI.Test.unittest(
#        model,
#        CONFIG,
#        String[
#            # add functions that are not supported by SoPlex
#            "number_threads",
#            "solve_zero_one_with_bounds_1",
#            "solve_singlevariable_obj",
#            "solve_affine_greaterthan",
#            "solve_affine_deletion_edge_cases",
#            "solve_affine_lessthan",
#            "solve_result_index",
#            "solve_with_lowerbound",
#            "delete_nonnegative_variables",
#            "add_variable",
#            "solve_constant_obj",
#            "solve_single_variable_dual_max",
#            "solve_single_variable_dual_min",
#            "delete_variable",
#            "solve_time",
#            "solve_duplicate_terms_obj",
#            "solve_qcp_edge_cases"
#        ],
#    )
#end

#TODO: there is some invalid variable name x somewhere
#function test_modification(model)
#    MOI.Test.modificationtest(model, CONFIG)
#end

#TODO: add MOIU.supports_default_copy_to
#function test_contlinear(model)
#    MOI.Test.contlineartest(model, CONFIG)
#end

#TODO: add MOIU.supports_default_copy_to
#function test_contconic(model)
#    MOI.Test.contlineartest(model, CONFIG)
#end

#TODO: MOIU.supports_default_copy_to
#function test_intconic(model)
#    MOI.Test.intconictest(model, CONFIG)
#end

function test_SolverName(model)
    @test MOI.get(model, MOI.SolverName()) == "SoPlex"
end

function test_default_objective_test(model)
    MOI.Test.default_objective_test(model)
end

function test_default_status_test(model)
    MOI.Test.default_status_test(model)
end

#TODO: fix right naming -> I think we need to go back to have the dictionary and nothing
# like in HiGHs
#function test_nametest(model)
#    MOI.Test.nametest(model)
#end

#TODO: MOIU.supports_default_copy_to
#function test_validtest(model)
#    MOI.Test.validtest(model)
#end

#TODO: MOIU.supports_default_copy_to
#function test_emptytest(model)
#    MOI.Test.emptytest(model)
#end

#TODO: MOIU.supports_default_copy_to
#function test_orderedindicestest(model)
#    MOI.Test.orderedindicestest(model)
#end

function test_scalar_function_constant_not_zero(model)
    MOI.Test.scalar_function_constant_not_zero(model)
end

# This function runs all functions in this module starting with `test_`.
function runtests()
   model = SoPlex.Optimizer{Float64}()
   for name in names(@__MODULE__; all = true)
        if startswith("$(name)", "test_")
            @testset "$(name)" begin
                getfield(@__MODULE__, name)(model)
            end
        end
    end
end

end # module TestMOISoPlex

TestMOISoPlex.runtests()
