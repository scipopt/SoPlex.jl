import MathOptInterface
const MOI = MathOptInterface
const MOIU = MOI.Utilities
const CleverDicts = MOIU.CleverDicts
const inf = 2^31 - 1
const FloatOrRational = Union{Float64, Rational{Int32}}

# ==============================================================================
#           HELPER FUNCTIONS
# ==============================================================================

@enum(
    _RowType,
    _ROW_TYPE_LESSTHAN,
    _ROW_TYPE_GREATERTHAN,
    _ROW_TYPE_INTERVAL,
    _ROW_TYPE_EQUAL_TO,
)

_row_type(::MOI.GreaterThan{T}) where {T <: FloatOrRational} = _ROW_TYPE_GREATERTHAN
_row_type(::MOI.LessThan{T}) where {T <: FloatOrRational} = _ROW_TYPE_LESSTHAN
_row_type(::MOI.EqualTo{T}) where {T <: FloatOrRational} = _ROW_TYPE_EQUAL_TO
_row_type(::MOI.Interval{T}) where {T <: FloatOrRational} = _ROW_TYPE_INTERVAL

@enum(
    _BoundEnum,
    _BOUND_NONE,
    _BOUND_LESS_THAN,
    _BOUND_GREATER_THAN,
    _BOUND_LESS_AND_GREATER_THAN,
    _BOUND_INTERVAL,
    _BOUND_EQUAL_TO,
)

_bounds(s::MOI.EqualTo{T}) where {T <: FloatOrRational} = s.value, s.value
_bounds(s::MOI.LessThan{T}) where {T <: FloatOrRational}  = T(-Inf), s.upper
_bounds(s::MOI.GreaterThan{T}) where {T <: FloatOrRational} = s.lower, T(Inf)
_bounds(s::MOI.Interval{T}) where {T <: FloatOrRational} = s.lower, s.upper

const _SCALAR_SETS{FloatOrRational} = Union{
    MOI.LessThan{FloatOrRational},
    MOI.GreaterThan{FloatOrRational},
    MOI.EqualTo{FloatOrRational},
    MOI.Interval{FloatOrRational}
}

# =============================================
#      Variables Infos
# =============================================

"""
_VariableInfo
A struct to store information about the variables.
"""
mutable struct _VariableInfo{T}
    # index of variable
    index::MOI.VariableIndex
    # The variable name.
    name::String
    # The zero-indexed column in the SoPlex object.
    column::Cint
    # Storage to keep track of the variable bounds.
    bound::_BoundEnum
    lower::T
    upper::T
    # We can perform an optimization and only store two strings for the
    # constraint names because, at most, there can be two SingleVariable
    # constraints, e.g., LessThan, GreaterThan.
    lessthan_name::String
    greaterthan_interval_or_equalto_name::String

    function _VariableInfo{T}(
        index::MOI.VariableIndex,
        column::Cint,
        bound::_BoundEnum = _BOUND_NONE,
    ) where{T <: FloatOrRational}
        return new{T}(index, "", column, bound, T(-Inf), T(Inf), "", "")
    end
end

function _update_info(info::_VariableInfo, s::MOI.GreaterThan{T}) where{T <: FloatOrRational}
    _throw_if_existing_lower(info, s)
    if info.bound == _BOUND_LESS_THAN
        info.bound = _BOUND_LESS_AND_GREATER_THAN
    else
        info.bound = _BOUND_GREATER_THAN
    end
    info.lower = s.lower
    return
end

function _update_info(info::_VariableInfo, s::MOI.LessThan{T}) where{T <: FloatOrRational}
    _throw_if_existing_upper(info, s)
    if info.bound == _BOUND_GREATER_THAN
        info.bound = _BOUND_LESS_AND_GREATER_THAN
    else
        info.bound = _BOUND_LESS_THAN
    end
    info.upper = s.upper
    return
end

function _update_info(info::_VariableInfo, s::MOI.EqualTo{T}) where{T <: FloatOrRational}
    _throw_if_existing_lower(info, s)
    _throw_if_existing_upper(info, s)
    info.bound = _BOUND_EQUAL_TO
    info.lower = s.value
    info.upper = s.value
    return
end

function _update_info(info::_VariableInfo, s::MOI.Interval{T}) where{T <: FloatOrRational}
    _throw_if_existing_lower(info, s)
    _throw_if_existing_upper(info, s)
    info.bound = _BOUND_INTERVAL
    info.lower = s.lower
    info.upper = s.upper
    return
end

function _variable_info_dict()
    return CleverDicts.CleverDict{MOI.VariableIndex,_VariableInfo}(
        vi -> vi.value,
        x -> MOI.VariableIndex(x),
    )
end

# =============================================
#      Variable Infos
# =============================================

"""
    _ConstraintInfo

A struct to store information about the affine constraints.
"""
mutable struct _ConstraintInfo{T}
    # The constraint name.
    name::String
    # The zero-indexed row in the SoPlex object.
    row::Cint
    # Storage to keep track of the constraint bounds.
    set::_RowType
    lower::T
    upper::T
end

function _ConstraintInfo(set::_SCALAR_SETS{T}) where{T <: FloatOrRational}
    lower, upper = _bounds(set)
    return _ConstraintInfo{T}("", 0, _row_type(set), lower, upper)
end

struct _ConstraintKey
    value::Int
end

function _constraint_info_dict()
    return CleverDicts.CleverDict{_ConstraintKey,_ConstraintInfo}(
        x::_ConstraintKey -> x.value,
        x::Int -> _ConstraintKey(x),
    )
end

"""
    _set(c::_ConstraintInfo)
Return the set associated with a constraint.
"""
function _set(c::_ConstraintInfo)
    if c.set == _ROW_TYPE_LESSTHAN
        return MOI.LessThan(c.upper)
    elseif c.set == _ROW_TYPE_GREATERTHAN
        return MOI.GreaterThan(c.lower)
    elseif c.set == _ROW_TYPE_INTERVAL
        return MOI.Interval(c.lower, c.upper)
    else
        @assert c.set == _ROW_TYPE_EQUAL_TO
        return MOI.EqualTo(c.lower)
    end
end

# ==============================================================================
# ==============================================================================
#
#               S U P P O R T E D    M O I    F E A T U R E S
#
# ==============================================================================
# ==============================================================================

"""
    Optimizer

Wrapper for MathOptInterface.
"""
mutable struct Optimizer{T, VT, CT} <: MOI.AbstractOptimizer
    # A pointer to the underlying SoPlex optimizer.
    inner::Ptr{Cvoid}

    # Storage for `MOI.Name`.
    name::String

    # A flag to keep track of MOI.FEASIBILITY_SENSE, since SoPlex only stores
    # MIN_SENSE or MAX_SENSE. This allows us to differentiate between MIN_SENSE
    # and FEASIBILITY_SENSE.
    is_feasibility::Bool

    # SoPlex doesn't support constants in the objective function.
    objective_constant::T

    variable_info::VT
    affine_constraint_info::CT

    # Mappings from variable and constraint names to their indices. These are
    # lazily built on-demand, so most of the time, they are empty.
    name_to_variable::Dict{String, MOI.VariableIndex}
    name_to_constraint_index::Dict{String, MOI.ConstraintIndex}

    # solution value
    solution_value::Cdouble

    # solution status
    status::Cint

    # primal
    primal::Vector{T}
    
    function Optimizer{T}() where {T <: FloatOrRational}
        ptr = SoPlex_create()
        if ptr == C_NULL
             error("Unable to create an internal model via the C API.")
        end
        vdict = _variable_info_dict()
        cdict = _constraint_info_dict()
        model = new{T, typeof(vdict), typeof(cdict)}(
             ptr,
             "",
             false,
             T(0),
             vdict,
             cdict,
             Dict{String,MOI.VariableIndex}(),
             Dict{String,MOI.ConstraintIndex}(),
             0.0,
             -3,
             Vector{T}(),
        )
        MOI.empty!(model)
        finalizer(SoPlex_free, model)

        if T == Rational{Int}
            SoPlex_setRational(model)
        end

        return model
    end
end

Optimizer() = Optimizer{Float64}()

Base.cconvert(::Type{Ptr{Cvoid}}, model::Optimizer) = model
Base.unsafe_convert(::Type{Ptr{Cvoid}}, model::Optimizer) = model.inner

function MOI.empty!(model::Optimizer)
    SoPlex_clearLPReal(model)
    model.objective_constant = 0.0
    model.is_feasibility = true
    empty!(model.variable_info)
    empty!(model.affine_constraint_info)
    model.name_to_variable = Dict{String,MOI.VariableIndex}()
    model.name_to_constraint_index = Dict{String,MOI.ConstraintIndex}()
    model.solution_value = 0.0
    model.status = -3
    return
end

function MOI.is_empty(model::Optimizer)
    return SoPlex_numRows(model) == 0 &&
           SoPlex_numCols(model) == 0 &&
           iszero(model.objective_constant) &&
           model.is_feasibility &&
           isempty(model.variable_info) &&
           isempty(model.affine_constraint_info) &&
           isempty(model.name_to_variable) &&
           isempty(model.name_to_constraint_index) &&
           iszero(model.solution_value) &&
           model.status == -3
end

MOI.get(::Optimizer, ::MOI.SolverName) = "SoPlex"
MOI.get(model::Optimizer, ::MOI.RawSolver) = model

function MOI.get(model::Optimizer, ::MOI.ListOfModelAttributesSet)
    attributes = [
        MOI.ObjectiveSense(),
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
    ]
    if MOI.get(model, MOI.Name()) != ""
        push!(attributes, MOI.Name())
    end
    return attributes
end

function MOI.get(::Optimizer, ::MOI.ListOfVariableAttributesSet)
    return MOI.AbstractVariableAttribute[MOI.VariableName()]
end

function MOI.get(::Optimizer, ::MOI.ListOfConstraintAttributesSet)
    return MOI.AbstractConstraintAttribute[MOI.ConstraintName()]
end


MOI.supports(::Optimizer, ::MOI.Name) = true

MOI.supports(::Optimizer, ::MOI.ObjectiveSense) = true

MOI.get(model::Optimizer, ::MOI.Name) = model.name

MOI.set(model::Optimizer, ::MOI.Name, name::String) = (model.name = name)

function _store_primal(model::Optimizer{T}) where{T <: FloatOrRational}
    nvars = SoPlex_numCols(model)
    primalptr = ones(Cdouble, nvars)
    primal = ones(T, nvars)

    SoPlex_getPrimalReal(model, primalptr, nvars)
    
    for i in 1:nvars
        primal[i] = T(primalptr[i])
    end
    model.primal = primal
    #println("Julia primal:", primal)
    return
end

function MOI.optimize!(model::Optimizer)
    # optimize model and surpress SoPlex output
    mktemp() do path, io
        redirect_stdout(io) do
            model.status = SoPlex_optimize(model)
            Base.Libc.flush_cstdio()
        end
        readline(path) 
    end
    #SoPlex_writeFileReal(model, "/scratch/opt/bzfchmie/test.lp")
    #model.status = SoPlex_optimize(model)
    #if model.status == 2
    #    SoPlex_writeFileReal(model, "/scratch/opt/bzfchmie/test2.lp")
    #end
    ub = zeros(Cdouble, SoPlex_numCols(model))
    #SoPlex_getUpperReal(model, ub, length(ub))
    #println(ub)
    _store_primal(model)
    #_store_solution(model)
    return
end

function MOI.get(model::Optimizer, ::MOI.TerminationStatus)
    status = model.status
    if status == -15 # an error occured
        return MOI.OTHER_ERROR
    elseif status == -14 # No ratiotester loaded
        return MOI.INVALID_MODEL
    elseif status == -13 # No pricer loaded
        return MOI.INVALID_MODEL
    elseif status == -12 # No linear solver loaded
        return MOI.INVALID_MODEL
    elseif status == -11 # not initialised error
        return MOI.OTHER_ERROR
    elseif status == -10 # solve() aborted to exit decomposition simplex
        return MOI.OTHER_ERROR
    elseif status == -9  # solve() aborted due to commence decomposition simplex
        return MOI.OTHER_ERROR
    elseif status == -8  # solve() aborted due to detection of cycling
        return MOI.OTHER_ERROR
    elseif status == -7  # solve() aborted due to time limit
        return MOI.TIME_LIMIT
    elseif status == -6  # solve() aborted due to iteration limit
        return MOI.ITERATION_LIMIT
    elseif status == -5  # solve() aborted due to objective limit
        return MOI.OBJECTIVE_LIMIT
    elseif status == -4  # Basis is singular, numerical troubles?
        return MOI.OTHER_ERROR
    elseif status == -3  # No Problem has been loaded
        return MOI.OPTIMIZE_NOT_CALLED
    elseif status == -2  # LP has a usable Basis (maybe LP is changed)
        return MOI.OTHER_ERROR
    elseif status == -1  # algorithm is running
        return MOI.OTHER_ERROR
    elseif status == 0   # nothing known on loaded problem
        return MOI.OTHER_ERROR
    elseif status == 1   # LP has been solved to optimality
        return MOI.OPTIMAL
    elseif status == 2   # LP has been proven to be primal unbounded
        return MOI.DUAL_INFEASIBLE
    elseif status == 3   # LP has been proven to be primal infeasible
        return MOI.INFEASIBLE
    elseif status == 4   # LP is primal infeasible or unbounded
        return MOI.OTHER_ERROR
    else                 # LP has beed solved to optimality but unscaled solution contains violations
        return MOI.OTHER_ERROR
    end
end

function MOI.get(
    model::Optimizer,
    attr::MOI.VariablePrimal,
    x::MOI.VariableIndex,
)
    MOI.check_result_index_bounds(model, attr)
    return model.primal[column(model, x)+1]
end

function MOI.get(model::Optimizer, ::MOI.ResultCount)
    if model.status == 1
        return 1
    else
        return 0
    end
end

function MOI.get(model::Optimizer, attr::MOI.PrimalStatus)
    if attr.N != 1
        return MOI.NO_SOLUTION
    elseif model.status == 1 || model.status == 2
        return MOI.FEASIBLE_POINT
    elseif model.status == 3
        return MOI.INFEASIBILITY_CERTIFICATE
    end
    return MOI.NO_SOLUTION
end

function MOI.get(model::Optimizer, attr::MOI.DualStatus)
    if attr.N != 1
        return MOI.NO_SOLUTION
    elseif model.status == 1 || model.status == 3
        return MOI.FEASIBLE_POINT
    elseif model.status == 2
        return MOI.INFEASIBILITY_CERTIFICATE
    end
    return MOI.NO_SOLUTION
end

function MOI.get(
    model::Optimizer,
    ::MOI.ConstraintFunction,
    c::MOI.ConstraintIndex{MOI.SingleVariable,<:Any},
)
    MOI.throw_if_not_valid(model, c)
    return MOI.SingleVariable(MOI.VariableIndex(c.value))
end

function MOI.get(
    model::Optimizer,
    ::MOI.ConstraintFunction,
    c::MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}},
)
    MOI.throw_if_not_valid(model, c)
    return MOI.ScalarAffineFunction(MOI.VariableIndex(c.value))
end

function MOI.get(model::Optimizer, attr::MOI.ObjectiveValue)
    MOI.check_result_index_bounds(model, attr)
    return SoPlex_objValueReal(model)
end

###
### MOI.copy_to
###

function _add_bounds(::Vector{T}, ub, i, s::MOI.LessThan{T}) where {T <: FloatOrRational}
    ub[i] = s.upper
    return
end

function _add_bounds(lb, ::Vector{T}, i, s::MOI.GreaterThan{T}) where {T <: FloatOrRational}
    lb[i] = s.lower
    return
end

function _add_bounds(lb, ub, i, s::MOI.EqualTo{T}) where {T <: FloatOrRational}
    lb[i], ub[i] = s.value, s.value
    return
end

function _add_bounds(lb, ub, i, s::MOI.Interval{T}) where {T <: FloatOrRational}
    lb[i], ub[i] = s.lower, s.upper
    return
end

function _extract_bound_data(
    dest::Optimizer{T},
    src::MOI.ModelLike,
    mapping,
    collower::Vector{T},
    colupper::Vector{T},
    ::Type{S},
) where {T <: FloatOrRational, S}
    for c_index in
        MOI.get(src, MOI.ListOfConstraintIndices{MOI.SingleVariable{T},S}())
        f = MOI.get(src, MOI.ConstraintFunction(), c_index)
        s = MOI.get(src, MOI.ConstraintSet(), c_index)
        new_f = mapping.varmap[f.variable]
        info = _info(dest, new_f)
        _add_bounds(collower, colupper, info.column + 1, s)
        _update_info(info, s)
        mapping.conmap[c_index] =
            MOI.ConstraintIndex{MOI.SingleVariable,S}(new_f.value)
    end
    return
end

function _copy_to_columns(dest::Optimizer{T}, src::MOI.ModelLike, mapping) where {T <: FloatOrRational}
    x_src = MOI.get(src, MOI.ListOfVariableIndices())
    numcols = Cint(length(x_src))
    for i in 1:numcols
        index = CleverDicts.add_item(
            dest.variable_info,
            _VariableInfo(MOI.VariableIndex(0), Cint(0)),
        )
        info = _info(dest, index)
        info.name = MOI.get(dest, MOI.VariableName(), x_src[i])
        info.index = index
        info.column = Cint(i - 1)
        mapping.varmap[x_src[i]] = index
    end
    fobj =
        MOI.get(src, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{T}}())
    c = fill(T(0.0), numcols)
    for term in fobj.terms
        i = mapping.varmap[term.variable_index].value
        c[i] += term.coefficient
    end
    dest.objective_constant = fobj.constant
    return numcols, c
end

add_sizehint!(vec, n) = sizehint!(vec, length(vec) + n)

function _extract_row_data(
    dest::Optimizer{T},
    src::MOI.ModelLike,
    mapping,
    rowlower::Vector{T},
    rowupper::Vector{T},
    I::Vector{Cint},
    J::Vector{Cint},
    V::Vector{T},
    ::Type{S},
) where {T <: FloatOrRational, S}
    row = length(I) == 0 ? 1 : I[end] + 1
    list = MOI.get(
        src,
        MOI.ListOfConstraintIndices{MOI.ScalarAffineFunction{T},S}(),
    )
    numrows = length(list)
    add_sizehint!(rowlower, numrows)
    add_sizehint!(rowupper, numrows)
    n_terms = 0
    fs = Array{MOI.ScalarAffineFunction{T}}(undef, numrows)
    for (i, c_index) in enumerate(list)
        f = MOI.get(src, MOI.ConstraintFunction(), c_index)
        fs[i] = f
        set = MOI.get(src, MOI.ConstraintSet(), c_index)
        l, u = _bounds(set)
        push!(rowlower, l - f.constant)
        push!(rowupper, u - f.constant)
        n_terms += length(f.terms)
        key = CleverDicts.add_item(
            dest.affine_constraint_info,
            _ConstraintInfo(set),
        )
        dest.affine_constraint_info[key].row =
            Cint(length(dest.affine_constraint_info) - 1)
        mapping.conmap[c_index] =
            MOI.ConstraintIndex{MOI.ScalarAffineFunction{T},S}(key.value)
    end
    add_sizehint!(I, n_terms)
    add_sizehint!(J, n_terms)
    add_sizehint!(V, n_terms)
    for (i, c_index) in enumerate(list)
        for term in fs[i].terms
            push!(I, row)
            push!(J, Cint(mapping.varmap[term.variable_index].value))
            push!(V, term.coefficient)
        end
        row += 1
    end
    return
end

function _check_input_data(dest::Optimizer, src::MOI.ModelLike)
    for (F, S) in MOI.get(src, MOI.ListOfConstraints())
        if !MOI.supports_constraint(dest, F, S)
            throw(
                MOI.UnsupportedConstraint{F,S}(
                    "SoPlex does not support constraints of type $F-in-$S.",
                ),
            )
        end
    end
    fobj_type = MOI.get(src, MOI.ObjectiveFunctionType())
    if !MOI.supports(dest, MOI.ObjectiveFunction{fobj_type}())
        throw(MOI.UnsupportedAttribute(MOI.ObjectiveFunction(fobj_type)))
    end
    return
end

MOIU.supports_default_copy_to(::Optimizer, copy_names::Bool) = !copy_names

function MOI.copy_to(
    dest::Optimizer{T},
    src::MOI.ModelLike;
    copy_names::Bool = false,
    kwargs...,
)  where {T <: FloatOrRational}
    if copy_names
        return MOIU.automatic_copy_to(
            dest,
            src;
            copy_names = true,
            kwargs...,
        )
    end
    @assert MOI.is_empty(dest)
    _check_input_data(dest, src)
    mapping = MOIU.IndexMap()
    numcol, colcost = _copy_to_columns(dest{T}, src, mapping)
    collower, colupper = fill(T(-Inf), numcol), fill(T(Inf), numcol)
    rowlower, rowupper = T[], T[]
    I, J, V = Cint[], Cint[], T[]
    for S in (
        MOI.GreaterThan{T},
        MOI.LessThan{T},
        MOI.EqualTo{T},
        MOI.Interval{T},
    )
        _extract_bound_data(dest, src, mapping, collower, colupper, S)
        _extract_row_data(dest, src, mapping, rowlower, rowupper, I, J, V, S)
    end
    numrow = Cint(length(rowlower))
    A = SparseArrays.sparse(I, J, V, numrow, numcol)
    Highs_passLp(
        dest,
        numcol,
        numrow,
        length(V),
        0,  # The A matrix is given is column-wise.
        MOI.get(src, MOI.ObjectiveSense()) == MOI.MAX_SENSE ? Cint(-1) :
        Cint(1),
        dest.objective_constant,
        colcost,
        collower,
        colupper,
        rowlower,
        rowupper,
        A.colptr .- Cint(1),
        A.rowval .- Cint(1),
        A.nzval,
    )
    return mapping
end

# ==============================================================================
#           Variables
# ==============================================================================
include("./variables.jl")

# ==============================================================================
#           Constraints
# ==============================================================================
include("./constraints.jl")

# ==============================================================================
#           Objective
# ==============================================================================
include("./objective.jl")
