# ============================ /test/MOI_wrapper.jl ============================
module TestMOISoPlex

import SoPlex
using Test

const MOI = SoPlex.MOI

println.(keys(MOI.Test.unittests))

function test_basic_constraint_tests(model, config)
    return MOI.Test.basic_constraint_tests(model, config)
end

function test_unittest(model, config)
    # Test all the functions included in dictionary `MOI.Test.unittests`,
    # except functions that are not supported by SoPlex
    MOI.Test.unittest(
        model,
        config,
        String[
            # add functions that are not supported by SoPlex
            "number_threads",
            "solve_qcp_edge_cases"
        ],
    )
end

function test_modification(model, config)
    MOI.Test.modificationtest(model, config)
end

function test_contlinear(model, config)
    MOI.Test.contlineartest(model, config)
end

function test_contquadratictest(model, config)
    MOI.Test.contquadratictest(model, config)
end

function test_contconic(model, config)
    MOI.Test.contlineartest(model, config)
end

function test_intconic(model, config)
    MOI.Test.intconictest(model, config)
end

function test_SolverName(model, ::Any)
    @test MOI.get(model, MOI.SolverName()) == "SoPlex"
end

function test_default_objective_test(model, ::Any)
    MOI.Test.default_objective_test(model)
end

function test_default_status_test(model, ::Any)
    MOI.Test.default_status_test(model)
end

function test_nametest(model, ::Any)
    MOI.Test.nametest(model)
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

function test_scalar_function_constant_not_zero(model, ::Any)
    MOI.Test.scalar_function_constant_not_zero(model)
end

# This function runs all functions in this module starting with `test_`.
function runtests()
    for name in names(@__MODULE__; all = true)
        if startswith("$(name)", "test_")
            @testset "$(name)" begin
                getfield(@__MODULE__, name)()
            end
        end
    end
end

end # module TestMOISoPlex

TestMOISoPlex.runtests()
