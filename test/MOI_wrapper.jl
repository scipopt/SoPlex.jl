# ============================ /test/MOI_wrapper.jl ============================
module TestMOISoPlex

import SoPlex
using Test

const MOI = SoPlex.MOI


function test_basic_constraint_tests(model, config)
    MOI.Test.basic_constraint_tests(
        model,
        config,
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
function test_modification(model, config)
    MOI.Test.modificationtest(model, config)
end

#TODO: add MOIU.supports_default_copy_to for the following six tests
function test_contlinear(model, config)
    MOI.Test.contlineartest(model, config)
end

function test_contconic(model, config)
    MOI.Test.contlineartest(model, config)
end

function test_intconic(model, config)
    MOI.Test.intconictest(model, config)
end

function test_validtest(model, ::Any)
    MOI.Test.validtest(model)
end

function test_emptytest(model, ::Any)
    MOI.Test.emptytest(model)
end

function test_orderedindicestest(model, ::Any)
    MOI.Test.orderedindicestest(model)
end
#end of list of tests requiring MOIU.supports_default_copy_to


function test_SolverName(model, ::Any)
    @test MOI.get(model, MOI.SolverName()) == "SoPlex"
end

function test_default_objective_test(model, ::Any)
    MOI.Test.default_objective_test(model)
end

function test_default_status_test(model, ::Any)
    MOI.Test.default_status_test(model)
end

#TODO: fix right naming -> I think we need to go back to have the dictionary and nothing
# like in HiGHs
function test_nametest(model, ::Any)
    MOI.Test.nametest(model)
end

function test_scalar_function_constant_not_zero(model, ::Any)
    MOI.Test.scalar_function_constant_not_zero(model)
end

# This function runs all functions in this module starting with `test_`.
function runtests()
    model = SoPlex.Optimizer()
    config = Dict(
        "simplex" => MOI.Test.TestConfig(basis = true),
        "CONFIG" => MOI.Test.TestConfig(
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
            ),
    )
    @testset "$(solver)" for solver in ["simplex", "CONFIG"]
        for name in names(@__MODULE__; all = true)
            if startswith("$(name)", "test_")
                if !("$(name)" in ["test_modification", "test_contlinear", "test_contconic", "test_intconic", "test_validtest", "test_emptytest", "test_orderedindicestest", "test_nametest"])
                    @testset "$(name)" begin
                        getfield(@__MODULE__, name)(model, config[solver])
                    end
                end
            end
        end
    end
end

end # module TestMOISoPlex

TestMOISoPlex.runtests()
