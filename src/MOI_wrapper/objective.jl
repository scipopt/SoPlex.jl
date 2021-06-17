# =============================================
#      Supported objectives
# =============================================

MOI.supports(::Optimizer, ::MOI.ObjectiveSense) = false

function MOI.set(
    model::Optimizer{T},
    ::MOI.ObjectiveSense,
    sense::MOI.OptimizationSense,
) where {T <: FloatOrRational}
    x = sense == MOI.MAX_SENSE ? Cint(1) : Cint(-1)
    SoPlex_setIntParam(model, Cint(0), x)
    if sense == MOI.FEASIBILITY_SENSE
        model.is_feasibility = true
        model.objective_constant = T(0.0)
    else
        model.is_feasibility = false
    end
    return
end

#function MOI.get(model::Optimizer, ::MOI.ObjectiveSense)
#    if model.is_feasibility
#        return MOI.FEASIBILITY_SENSE
#    end
#    senseP = Ref{Cint}()
#    ret = Highs_getObjectiveSense(model, senseP)
#    _check_ret(ret)
#    return senseP[] == 1 ? MOI.MIN_SENSE : MOI.MAX_SENSE
#end

function MOI.supports(
    ::Optimizer{T},
    ::MOI.ObjectiveFunction{MOI.ScalarAffineFunction{T}},
) where{T <: FloatOrRational}
    return true
end

# =============================================
#      Get/set objective function
# =============================================

function MOI.set(
    model::Optimizer,
    ::MOI.ObjectiveFunction{MOI.ScalarAffineFunction{T}},
    f::MOI.ScalarAffineFunction{T},
) where{T <: Float64}
    num_vars = length(model.variable_info)
    obj = zeros(Float64, num_vars)

    for term in f.terms
        col = column(model, term.variable_index)
        obj[col+1] += term.coefficient
    end

    SoPlex_changeObjReal(model, obj, num_vars)
    model.objective_constant = f.constant
    return
end

function MOI.set(
    model::Optimizer,
    ::MOI.ObjectiveFunction{MOI.ScalarAffineFunction{T}},
    f::MOI.ScalarAffineFunction{T},
) where{T <: Rational{Int64}}
    num_vars = length(model.variable_info)
    obj = zeros(Rational{Int64}, num_vars)
    
    for term in f.terms
        col = column(model, term.variable_index)
        obj[col+1] += term.coefficient
    end
    
    SoPlex_changeObjRational(
        model,
        [numerator(x) for x in obj],
        [denominator(x) for x in obj],
        num_vars
        )
    model.objective_constant = f.constant
    return
end

function MOI.set(
    model::Optimizer,
    ::MOI.ObjectiveSense,
    sense::MOI.OptimizationSense,
)
    x = sense == MOI.MAX_SENSE ? Cint(1) : Cint(-1)
    SoPlex_setIntParam(model, 0, x);

    # TODO: fix that
    if sense == MOI.FEASIBILITY_SENSE
        model.is_feasibility = true
        model.objective_constant = 0.0
    else
        model.is_feasibility = false
    end
    return
end

function MOI.get(::Optimizer, ::MOI.ObjectiveFunctionType)
    return MOI.ScalarAffineFunction{T}
end

# =============================================
#      Modify objective
# ============================================= 

function MOI.modify(
    model::Optimizer,
    ::MOI.ObjectiveFunction{MOI.ScalarAffineFunction{T}},
    chg::MOI.ScalarConstantChange{T},
) where{T <: FloatOrRational}
    model.objective_constant = chg.new_constant
    return
end
