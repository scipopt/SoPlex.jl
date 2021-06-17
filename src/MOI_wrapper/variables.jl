# =============================================
#      Supported variable attributes
# =============================================

function MOI.supports(
    ::Optimizer,
    ::MOI.VariableName,
    ::Type{MOI.VariableIndex},
)
    return true
end

# =============================================
#      Helper functions
# =============================================

function MOI.get(model::Optimizer, ::Type{MOI.VariableIndex}, name::String)
    if model.name_to_variable === nothing
        _rebuild_name_to_variable(model)
    end
    if haskey(model.name_to_variable, name)
        variable = model.name_to_variable[name]
        if variable === nothing
            error("Duplicate name detected: $(name)")
        end
        return variable
    end
    return nothing
end

function MOI.get(model::Optimizer, ::MOI.VariableName, v::MOI.VariableIndex)
    return _info(model, v).name
end

function MOI.set(
    model::Optimizer,
    ::MOI.VariableName,
    v::MOI.VariableIndex,
    name::String,
)
    info = _info(model, v)
    info.name = name
    model.name_to_variable = Dict{String,MOI.VariableIndex}()
    return
end

function _rebuild_name_to_variable(model::Optimizer)
    model.name_to_variable = Dict{String,Union{Nothing,MOI.VariableIndex}}()
    for (index, info) in model.variable_info
        if isempty(info.name)
            continue
        end
        if haskey(model.name_to_variable, info.name)
            model.name_to_variable[info.name] = nothing
        else
            model.name_to_variable[info.name] = index
        end
    end
    return
end

function MOI.get(model::Optimizer, ::MOI.NumberOfVariables)
    return length(model.variable_info)
end

function MOI.get(model::Optimizer, ::MOI.ListOfVariableIndices)
    return sort!(collect(keys(model.variable_info)), by = x -> x.value)
end

function _info(model::Optimizer, key::MOI.VariableIndex)
    if haskey(model.variable_info, key)
        return model.variable_info[key]
    end
    return throw(MOI.InvalidIndex(key))
end

"""
     column(model::Optimizer, x::MOI.VariableIndex)

Return the 0-indexed column associated with `x` in `model`.
"""
column(model::Optimizer, x::MOI.VariableIndex) = _info(model, x).column

# =============================================
#      Add variables
# =============================================

function MOI.is_valid(model::Optimizer, v::MOI.VariableIndex)
    return haskey(model.variable_info, v)
end

function MOI.add_variable(model::Optimizer{Float64})
    # Initialize `_VariableInfo` with a dummy `VariableIndex` and a column,
    # because we need `add_item` to tell us what the `VariableIndex` is.
    index = CleverDicts.add_item(
        model.variable_info,
        _VariableInfo{Float64}(MOI.VariableIndex(0), Cint(0)),)

    info = _info(model, index)
    # Now, set `.index` and `.column`.
    info.index = index
    info.column = Cint(length(model.variable_info) - 1)

    SoPlex_addColReal(model, C_NULL, 0, 0, 0, -Inf, Inf)

    return index
end

function MOI.add_variable(model::Optimizer{Rational{Int64}})
    # Initialize `_VariableInfo` with a dummy `VariableIndex` and a column,
    # because we need `add_item` to tell us what the `VariableIndex` is. 
    index = CleverDicts.add_item(
        model.variable_info,
        _VariableInfo{Rational{Int64}}(MOI.VariableIndex(0), Cint(0)),)

    info = _info(model, index)
    # Now, set `.index` and `.column`.
    info.index = index
    info.column = Cint(length(model.variable_info) - 1)

    SoPlex_addColRational(model, C_NULL, C_NULL, 0, 0, 0, 0, -inf, 1, inf, 1)

    return index
end
