# =============================================
#     Supported constraints and attributes
# =============================================

function MOI.supports(
    ::Optimizer,
    ::MOI.ConstraintName,
    ::Type{<:MOI.ConstraintIndex{MOI.SingleVariable,<:_SCALAR_SETS}},
)
    return true
end

function MOI.supports(
    ::Optimizer,
    ::MOI.ConstraintName,
    ::Type{
        <:MOI.ConstraintIndex{MOI.ScalarAffineFunction{T},<:_SCALAR_SETS},
    },
) where {T <: FloatOrRational}
    return true
end

# Variable bounds
function MOI.supports_constraint(
    ::Optimizer{T},
    ::Type{MOI.SingleVariable},
    ::Type{<:_SCALAR_SETS{T}},
) where { T <: FloatOrRational}
    return true
end

function MOI.supports_constraint(
    ::Optimizer{T},
    ::Type{MOI.VectorOfVariables},
    ::Type{<:MOI.Nonnegatives},
) where { T <: FloatOrRational}
    return true
end

# Linear constraints
function MOI.supports_constraint(
    ::Optimizer,
    ::Type{MOI.ScalarAffineFunction{T}},
    ::Type{<:_SCALAR_SETS{T}},
) where{T <: FloatOrRational}
    return true
end

function MOI.is_valid(
    model::Optimizer,
    c::MOI.ConstraintIndex{MOI.ScalarAffineFunction{T},S},
) where { T <: FloatOrRational, S<:_SCALAR_SETS}
    key = _ConstraintKey(c.value)
    info = get(model.affine_constraint_info, key, nothing)
    if info === nothing
        return false
    end 
    return _set(info) isa S
end

function MOI.is_valid(
    model::Optimizer,
    c::MOI.ConstraintIndex{MOI.SingleVariable, MOI.LessThan{T}},
) where{T <: FloatOrRational}
    if haskey(model.variable_info, MOI.VariableIndex(c.value))
        info = _info(model, c)
        return info.bound == _BOUND_LESS_THAN ||
               info.bound == _BOUND_LESS_AND_GREATER_THAN
    end
    return false
end

function MOI.is_valid(
    model::Optimizer,
    c::MOI.ConstraintIndex{MOI.SingleVariable, MOI.GreaterThan{T}},
) where{T <: FloatOrRational}
    if haskey(model.variable_info, MOI.VariableIndex(c.value))
        info = _info(model, c)
        return info.bound == _BOUND_GREATER_THAN ||
               info.bound == _BOUND_LESS_AND_GREATER_THAN
    end
    return false
end

function MOI.is_valid(
    model::Optimizer,
    c::MOI.ConstraintIndex{MOI.SingleVariable, MOI.Interval{T}},
) where{T <: FloatOrRational}
    return haskey(model.variable_info, MOI.VariableIndex(c.value)) &&
           _info(model, c).bound == _BOUND_INTERVAL
end

function MOI.is_valid(
    model::Optimizer,
    c::MOI.ConstraintIndex{MOI.SingleVariable, MOI.EqualTo{T}},
) where{T <: FloatOrRational}
    return haskey(model.variable_info, MOI.VariableIndex(c.value)) &&
           _info(model, c).bound == _BOUND_EQUAL_TO
end

function MOI.get(model::Optimizer, ::MOI.NumberOfConstraints{F,S}) where {F,S}
    return length(MOI.get(model, MOI.ListOfConstraintIndices{F,S}()))
end

# =============================================
#      Helper functions
# =============================================

function _bound_enums(::Type{MOI.LessThan{T}}) where{T <: FloatOrRational}
    return (_BOUND_LESS_THAN, _BOUND_LESS_AND_GREATER_THAN)
end

function _bound_enums(::Type{MOI.GreaterThan{T}}) where{T <: FloatOrRational}
    return (_BOUND_GREATER_THAN, _BOUND_LESS_AND_GREATER_THAN)
end

_bound_enums(::Type{MOI.Interval{T}}) where{T <: FloatOrRational} = (_BOUND_INTERVAL,)

_bound_enums(::Type{MOI.EqualTo{T}}) where{T <: FloatOrRational} = (_BOUND_EQUAL_TO,)

function MOI.get(
    model::Optimizer,
    ::MOI.ConstraintName,
    c::MOI.ConstraintIndex{MOI.SingleVariable,S},
) where {S<:_SCALAR_SETS}
    MOI.throw_if_not_valid(model, c)
    info = _info(model, c)
    if S <: MOI.LessThan
        return info.lessthan_name
    else
        return info.greaterthan_interval_or_equalto_name
    end
end

function MOI.set(
    model::Optimizer,
    ::MOI.ConstraintName,
    c::MOI.ConstraintIndex{MOI.SingleVariable,S},
    name::String,
) where {S<:_SCALAR_SETS}
    MOI.throw_if_not_valid(model, c)
    info = _info(model, c)
    if S <: MOI.LessThan
        info.lessthan_name = name
    else
        info.greaterthan_interval_or_equalto_name = name
    end
    model.name_to_constraint_index = Dict{String,MOI.ConstraintIndex}()
    return
end

function MOI.get(
    model::Optimizer,
    ::MOI.ConstraintName,
    ::MOI.ListOfConstraintIndices{MOI.SingleVariable,S},
) where { T <: FloatOrRational, S<:_SCALAR_SETS{T}}
    indices = MOI.ConstraintIndex{MOI.SingleVariable,S}[
        MOI.ConstraintIndex{MOI.SingleVariable,S}(key.value) for
        (key, info) in model.variable_info if info.bound in _bound_enums(S)
    ]
    return sort!(indices, by = x -> x.value)
end

function MOI.set(
    model::Optimizer{T},
    ::MOI.ConstraintName,
    c::MOI.ConstraintIndex{MOI.ScalarAffineFunction{T},<:Any},
    name::String,
) where {T <: FloatOrRational}
    info = _info(model, c)
    info.name = name
    model.name_to_constraint_index = Dict{String,MOI.ConstraintIndex}()
    return
end

function MOI.get(model::Optimizer, ::Type{MOI.ConstraintIndex}, name::String)
    if model.name_to_constraint_index == Dict{String,MOI.ConstraintIndex}()
        _rebuild_name_to_constraint_index(model)
    end
    if haskey(model.name_to_constraint_index, name)
        constr = model.name_to_constraint_index[name]
        if constr == Dict{String,MOI.ConstraintIndex}()
            error("Duplicate constraint name detected: $(name)")
        end
        return constr
    end
    return nothing
end

function MOI.get(
    model::Optimizer,
    C::Type{MOI.ConstraintIndex{F,S}},
    name::String,
) where {F,S}
    index = MOI.get(model, MOI.ConstraintIndex, name)
    if index isa C
        return index::MOI.ConstraintIndex{F,S}
    end
    return Dict{String,MOI.ConstraintIndex}()
end

function _rebuild_name_to_constraint_index(model::Optimizer{T}) where {T <: FloatOrRational}
    model.name_to_constraint_index = Dict{String,MOI.ConstraintIndex}()
    for (key, info) in model.affine_constraint_info
        if isempty(info.name)
            continue
        end
        S = typeof(_set(info))
        _set_name_to_constraint_index(
            model,
            info.name,
            MOI.ConstraintIndex{MOI.ScalarAffineFunction{T},S}(key.value),
        )
    end
    for (key, info) in model.variable_info
        if !isempty(info.lessthan_name)
            _set_name_to_constraint_index(
                model,
                info.lessthan_name,
                MOI.ConstraintIndex{MOI.SingleVariable,MOI.LessThan{T}}(
                    key.value,
                ),
            )
        end
        if !isempty(info.greaterthan_interval_or_equalto_name)
            S = if info.bound == _BOUND_GREATER_THAN
                MOI.GreaterThan{T}
            elseif info.bound == _BOUND_LESS_AND_GREATER_THAN
                MOI.GreaterThan{T}
            elseif info.bound == _BOUND_EQUAL_TO
                MOI.EqualTo{T}
            else
                @assert info.bound == _BOUND_INTERVAL
                MOI.Interval{T}
            end
            _set_name_to_constraint_index(
                model,
                info.greaterthan_interval_or_equalto_name,
                MOI.ConstraintIndex{MOI.SingleVariable,S}(key.value),
            )
        end
    end
    return
end

function _set_name_to_constraint_index(
    model::Optimizer,
    name::String,
    index::MOI.ConstraintIndex,
)
    if haskey(model.name_to_constraint_index, name)
        model.name_to_constraint_index[name] = Dict{String,MOI.ConstraintIndex}()
    else
        model.name_to_constraint_index[name] = index
    end
    return
end

function _info(
    model::Optimizer,
    c::MOI.ConstraintIndex{MOI.SingleVariable, <:Any},
)
    var_index = MOI.VariableIndex(c.value)
    if haskey(model.variable_info, var_index)
        return _info(model, var_index)
    end
    return throw(MOI.InvalidIndex(c))
end

"""
    column(
        model::Optimizer,
        c::MOI.ConstraintIndex{MOI.SingleVariable,<:Any},
    )
Return the 0-indexed column associated with the variable bounds `c` in `model`.
"""
function column(
    model::Optimizer,
    c::MOI.ConstraintIndex{MOI.SingleVariable, <:Any},
)
    return _info(model, c).column
end

function MOI.get(
    model::Optimizer,
    ::MOI.ListOfConstraintIndices{MOI.ScalarAffineFunction{Float64},S},
) where {S<:_SCALAR_SETS}
    indices = MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64},S}[
        MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64},S}(key.value)
        for (key, info) in model.affine_constraint_info if _set(info) isa S
    ]
    return sort!(indices; by = x -> x.value)
end

function MOI.get(
    model::Optimizer,
    ::MOI.ListOfConstraintIndices{MOI.ScalarAffineFunction{T},S},
) where { T <: FloatOrRational, S<:_SCALAR_SETS}
    indices = MOI.ConstraintIndex{MOI.ScalarAffineFunction{T},S}[
        MOI.ConstraintIndex{MOI.ScalarAffineFunction{T},S}(key.value)
        for (key, info) in model.affine_constraint_info if _set(info) isa S
    ]
    return sort!(indices; by = x -> x.value)
end

function _info(
    model::Optimizer,
    c::MOI.ConstraintIndex{MOI.ScalarAffineFunction{T},<:_SCALAR_SETS},
) where{T <: FloatOrRational}
    key = _ConstraintKey(c.value)
    if haskey(model.affine_constraint_info, key)
        return model.affine_constraint_info[key]
    end
    return throw(MOI.InvalidIndex(c))
end

function row(
    model::Optimizer,
    c::MOI.ConstraintIndex{MOI.ScalarAffineFunction{T},<:_SCALAR_SETS},
) where{T <: FloatOrRational}
    return _info(model, c).row
end

function _coefficients(
    model::Optimizer,
    f::MOI.ScalarAffineFunction{T},
) where{T <: Float64}
    size = SoPlex_numCols(model)

    coefficients = zeros(Cdouble, size)

    for term in f.terms
        idx = column(model, term.variable_index)
        coefficients[idx + 1] = term.coefficient
    end
    return coefficients
end 

function _coefficients(
    model::Optimizer,
    f::MOI.ScalarAffineFunction{T},
) where{T <: Rational{Int64}}
    size = SoPlex_numCols(model)
    
    coefficients = zeros(Rational{Int64}, size)
    
    for term in f.terms
        idx = column(model, term.variable_index)
        coefficients[idx + 1] = term.coefficient
    end 
    return coefficients
end

function _throw_if_existing_lower(
    info::_VariableInfo{T},
    ::S,
) where { T <: FloatOrRational,S<:MOI.AbstractSet}
    if info.bound == _BOUND_LESS_AND_GREATER_THAN
        throw(MOI.LowerBoundAlreadySet{MOI.GreaterThan{T},S}(info.index))
    elseif info.bound == _BOUND_GREATER_THAN
        throw(MOI.LowerBoundAlreadySet{MOI.GreaterThan{T},S}(info.index))
    elseif info.bound == _BOUND_INTERVAL
        throw(MOI.LowerBoundAlreadySet{MOI.Interval{T},S}(info.index))
    elseif info.bound == _BOUND_EQUAL_TO
        throw(MOI.LowerBoundAlreadySet{MOI.EqualTo{T},S}(info.index))
    end
    return
end

function _throw_if_existing_upper(
    info::_VariableInfo{T},
    ::S,
) where {T<:FloatOrRational, S<:MOI.AbstractSet}
    if info.bound == _BOUND_LESS_AND_GREATER_THAN
        throw(MOI.UpperBoundAlreadySet{MOI.LessThan{T},S}(info.index))
    elseif info.bound == _BOUND_LESS_THAN
        throw(MOI.UpperBoundAlreadySet{MOI.LessThan{T},S}(info.index))
    elseif info.bound == _BOUND_INTERVAL
        throw(MOI.UpperBoundAlreadySet{MOI.Interval{T},S}(info.index))
    elseif info.bound == _BOUND_EQUAL_TO
        throw(MOI.UpperBoundAlreadySet{MOI.EqualTo{T},S}(info.index))
    end
    return
end

# =============================================
#      Add constraints
# =============================================

function MOI.add_constraint(
    model::Optimizer,
    f::MOI.SingleVariable,
    s::_SCALAR_SETS{T},
) where{T <: FloatOrRational}
    info = _info(model, f.variable)
    _update_info(info, s)
    index = MOI.ConstraintIndex{MOI.SingleVariable,typeof(s)}(f.variable.value)
    MOI.set(model, MOI.ConstraintSet(), index, s)
    return index
end

function MOI.set(
    model::Optimizer{T},
    ::MOI.ConstraintSet,
    c::MOI.ConstraintIndex{MOI.SingleVariable,S},
    s::S,
) where { T <: Float64, S<:_SCALAR_SETS{T}}
    MOI.throw_if_not_valid(model, c)
    lower, upper = _bounds(s)
    info = _info(model, c)

    lb = zeros(Cdouble, SoPlex_numCols(model))
    ub = zeros(Cdouble, SoPlex_numCols(model))

    if S == MOI.LessThan{T}
         SoPlex_changeVarBoundsReal(model, info.column, info.lower, upper)
         info.upper = upper
    elseif S == MOI.GreaterThan{T}
         SoPlex_changeVarBoundsReal(model, info.column, lower, info.upper)
         info.lower = lower
    else
         SoPlex_changeVarBoundsReal(model, info.column, lower, upper)
         info.lower = lower
         info.upper = upper
    end
    return
end

function MOI.set(
    model::Optimizer,
    ::MOI.ConstraintSet,
    c::MOI.ConstraintIndex{MOI.SingleVariable,S},
    s::S,
) where { T <: Rational{Int64}, S<:_SCALAR_SETS{T}}
    MOI.throw_if_not_valid(model, c)
    lower, upper = _bounds(s)
    info = _info(model, c)

    lb = zeros(Cdouble, SoPlex_numCols(model))
    ub = zeros(Cdouble, SoPlex_numCols(model))

    if S == MOI.LessThan{T}
         SoPlex_changeVarBoundsRational(model, info.column, info.lower, upper)
         info.upper = upper
    elseif S == MOI.GreaterThan{T}
         SoPlex_changeVarBoundsRational(model, info.column, lower, info.upper)
         info.lower = lower
    else
         SoPlex_changeVarBoundsRational(model, info.column, lower, upper)
         info.lower = lower
         info.upper = upper
    end
    return
end

function MOI.add_constraint(
    model::Optimizer{T},
    f::MOI.ScalarAffineFunction{T},
    s::_SCALAR_SETS,
) where{T <: Float64}
    if !iszero(f.constant)
        throw(MOI.ScalarFunctionConstantNotZero{T,typeof(f),typeof(s)}(f.constant,),)
    end

    key = CleverDicts.add_item(model.affine_constraint_info, _ConstraintInfo(s))
    model.affine_constraint_info[key].row = Cint(length(model.affine_constraint_info) - 1)
    coefficients = _coefficients(model, f)
    lower, upper = _bounds(s)
    f_canon = MOI.Utilities.canonical(f)
    nnz = length(f_canon.terms)

    SoPlex_addRowReal(model, coefficients, length(f.terms), nnz, lower, upper)

    return MOI.ConstraintIndex{typeof(f),typeof(s)}(key.value)
end

function MOI.add_constraint(
    model::Optimizer{T},
    f::MOI.ScalarAffineFunction{T},
    s::_SCALAR_SETS,
) where{T <: Rational{Int64}}
    if !iszero(f.constant)
        throw(MOI.ScalarFunctionConstantNotZero{T,typeof(f),typeof(s)}(f.constant,),)
    end
    
    key = CleverDicts.add_item(model.affine_constraint_info, _ConstraintInfo(s))
    model.affine_constraint_info[key].row = Cint(length(model.affine_constraint_info) - 1)
    coefficients = _coefficients(model, f)
    lower, upper = _bounds(s)
    f_canon = MOI.Utilities.canonical(f)
    nnz = length(f_canon.terms)
    
    # SoPlex does not allow 1//0 = Inf
    if denominator(upper) == 0
         upper = inf // 1
    end
    if denominator(lower) == 0
         lower = -inf // 1
    end
    
    SoPlex_addRowRational(
         model,
         [numerator(coef) for coef in coefficients],
         [denominator(coef) for coef in coefficients],
         length(f.terms),
         nnz,
         numerator(lower),
         denominator(lower),
         numerator(upper),
         denominator(upper)
         )

    return MOI.ConstraintIndex{typeof(f),typeof(s)}(key.value)
end
