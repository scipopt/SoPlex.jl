import MathOptInterface
const MOI = MathOptInterface
const CleverDicts = MOI.Utilities.CleverDicts
global inf = 2^31 - 1

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

_row_type(::MOI.GreaterThan{T}) where{T} = _ROW_TYPE_GREATERTHAN
_row_type(::MOI.LessThan{T}) where{T} = _ROW_TYPE_LESSTHAN
_row_type(::MOI.EqualTo{T}) where{T} = _ROW_TYPE_EQUAL_TO
_row_type(::MOI.Interval{T}) where{T} = _ROW_TYPE_INTERVAL

@enum(
    _BoundEnum,
    _BOUND_NONE,
    _BOUND_LESS_THAN,
    _BOUND_GREATER_THAN,
    _BOUND_LESS_AND_GREATER_THAN,
    _BOUND_INTERVAL,
    _BOUND_EQUAL_TO,
)

_bounds(s::MOI.EqualTo{T}) where{T} = s.value, s.value
_bounds(s::MOI.LessThan{T}) where{T}  = T(-Inf), s.upper
_bounds(s::MOI.GreaterThan{T}) where{T}  = s.lower, T(Inf)
_bounds(s::MOI.Interval{T}) where{T}  = s.lower, s.upper

const _SCALAR_SETS{T} = Union{
    MOI.LessThan{T},
    MOI.GreaterThan{T},
    MOI.EqualTo{T},
    MOI.Interval{T}
} where{T}

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
    ) where{T}
        return new{T}(index, "", column, bound, T(-Inf), T(Inf), "", "")
    end
end

function _update_info(info::_VariableInfo, s::MOI.GreaterThan{T}) where{T}
    _throw_if_existing_lower(info, s)
    if info.bound == _BOUND_LESS_THAN
        info.bound = _BOUND_LESS_AND_GREATER_THAN
    else
        info.bound = _BOUND_GREATER_THAN
    end
    info.lower = s.lower
    return
end

function _update_info(info::_VariableInfo, s::MOI.LessThan{T}) where{T}
    _throw_if_existing_upper(info, s)
    if info.bound == _BOUND_GREATER_THAN
        info.bound = _BOUND_LESS_AND_GREATER_THAN
    else
        info.bound = _BOUND_LESS_THAN
    end
    info.upper = s.upper
    return
end

function _update_info(info::_VariableInfo, s::MOI.EqualTo{T}) where{T}
    _throw_if_existing_lower(info, s)
    _throw_if_existing_upper(info, s)
    info.bound = _BOUND_EQUAL_TO
    info.lower = s.value
    info.upper = s.value
    return
end

function _update_info(info::_VariableInfo, s::MOI.Interval{T}) where{T}
    _throw_if_existing_lower(info, s)
    _throw_if_existing_upper(info, s)
    info.bound = _BOUND_INTERVAL
    info.lower = s.lower
    info.upper = s.upper
    return
end

function _variable_info_dict()
    return CleverDicts.CleverDict{MOI.VariableIndex,_VariableInfo}(
        x::MOI.VariableIndex -> x.value,
        x::Int64 -> MOI.VariableIndex(x),)
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

function _ConstraintInfo(set::_SCALAR_SETS{T}) where{T}
    lower, upper = _bounds(set)
    return _ConstraintInfo{T}("", 0, _row_type(set), lower, upper)
end

struct _ConstraintKey
    value::Int64
end

function _constraint_info_dict()
    return CleverDicts.CleverDict{_ConstraintKey,_ConstraintInfo}(
        x::_ConstraintKey -> x.value,
        x::Int64 -> _ConstraintKey(x),
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

Wrapper for MOI.
"""

mutable struct Optimizer{T} <: MOI.AbstractOptimizer
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

    variable_info::typeof(_variable_info_dict())
    affine_constraint_info::typeof(_constraint_info_dict())

    # Mappings from variable and constraint names to their indices. These are
    # lazily built on-demand, so most of the time, they are `nothing`.
    name_to_variable::Union{
        Nothing,
        Dict{String,Union{Nothing,MOI.VariableIndex}},
    }
    name_to_constraint_index::Union{
        Nothing,
        Dict{String,Union{Nothing,MOI.ConstraintIndex}},
    }

    # solution struct
    solution::Cdouble

    # solution status
    status::Cint

    # primal
    primal::Vector{T}
    
    # do we solve with rational numbers?
    is_rational::Bool

    """
    Optimizer()
    Create a new Optimizer object.
    """

    function Optimizer{T}() where{T}
        ptr = SoPlex_create()
        if ptr == C_NULL
             error("Unable to create an internal model via the C API.")
         end
         model = new{T}(
             ptr,
             "",
             false,
             T(0),
             _variable_info_dict(),
             _constraint_info_dict(),
             nothing,
             nothing,
             0.0,
             -3,
             Vector{T}(undef, 0),
             false,)
         MOI.empty!(model)
         finalizer(SoPlex_free, model)
         return model
    end
end

Base.cconvert(::Type{Ptr{Cvoid}}, model::Optimizer) = model
Base.unsafe_convert(::Type{Ptr{Cvoid}}, model::Optimizer) = model.inner

function MOI.empty!(model::Optimizer)
    SoPlex_clearLPReal(model)
    model.objective_constant = 0.0
    model.is_feasibility = true
    empty!(model.variable_info)
    empty!(model.affine_constraint_info)
    model.name_to_variable = nothing
    model.name_to_constraint_index = nothing
    model.solution = 0.0
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
           model.name_to_variable === nothing &&
           model.name_to_constraint_index === nothing &&
           model.solution == 0.0 &&
           model.status == -3
end

MOI.get(::Optimizer, ::MOI.SolverName) = "SoPlex"
MOI.get(model::Optimizer, ::MOI.RawSolver) = model

function MOI.get(model::Optimizer, ::MOI.ListOfModelAttributesSet)
    attributes = [
        MOI.ObjectiveSense(),
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{T}}(),
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

struct RationalSolve <: MOI.AbstractOptimizerAttribute end
function MOI.set(model::Optimizer, ::RationalSolve)
   # use rational SoPlex
   SoPlex_setRational(model)
   model.is_rational = true
end


"""
    MOI.Name

"""

MOI.supports(::Optimizer, ::MOI.Name) = true

MOI.get(model::Optimizer, ::MOI.Name) = model.name

MOI.set(model::Optimizer, ::MOI.Name, name::String) = (model.name = name)

"""
   Optimize Methods

"""

function _store_solution(model::Optimizer)
    x = model.solution
    
    x.optimize_called = true
    x.has_solution = false
    
    numcols = SoPlex_numCols(model)
    numrows = SoPlex_numRows(model)
    
    resize!(x.colvalue, numcols)
    resize!(x.coldual, numcols)
    resize!(x.colstatus, numcols)
    resize!(x.rowvalue, numrows)
    resize!(x.rowdual, numrows)
    resize!(x.rowstatus, numrows)
    
    # Load the solution if optimal.
    if Highs_getModelStatus(model.inner, Cint(0)) == 9
        Highs_getSolution(model, x.colvalue, x.coldual, x.rowvalue, x.rowdual)
        Highs_getBasis(model, x.colstatus, x.rowstatus) 
        x.has_solution = true 
        return
    end 
end

function _store_primal(model::Optimizer{T}) where{T}
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
    end;
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
    #if !model.solution.optimize_called
    #    return MOI.OPTIMIZE_NOT_CALLED
    #end
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
        return MOI.INVALID_MODEL
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
