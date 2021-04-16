# =============================================
#      Supported objectives
# =============================================

MOI.supports(::Optimizer, ::MOI.ObjectiveSense) = true

function MOI.supports(
    ::Optimizer{T},
    ::MOI.ObjectiveFunction{MOI.ScalarAffineFunction{T}},
) where{T}
    return true
end

# =============================================
#      Get/set objective function
# =============================================

function MOI.set(
    model::Optimizer,
    ::MOI.ObjectiveFunction{MOI.ScalarAffineFunction{T}},
    f::MOI.ScalarAffineFunction{T},
) where{T}
    num_vars = length(model.variable_info)
    
    if model.is_rational == true
        obj = zeros(Rational{Int64}, num_vars)
    else
        obj = zeros(Float64, num_vars)
    end
    
    for term in f.terms
        col = column(model, term.variable_index)
        obj[col+1] += term.coefficient
    end
    
    # set real/rational objective, depending on is_rational
    if model.is_rational == true
        SoPlex_changeObjRational(
        model,
        [numerator(x) for x in obj],
        [denominator(x) for x in obj],
        num_vars)
    else
        SoPlex_changeObjReal(model, obj, num_vars)
    end
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
) where{T}
    model.objective_constant = chg.new_constant
    return
end
