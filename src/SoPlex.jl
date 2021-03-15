module SoPlex

const deps_file = joinpath(dirname(@__FILE__),"..","deps","deps.jl")
if isfile(deps_file)
    include(deps_file)
else
    error("SoPlex not properly installed. Please run import Pkg; Pkg.build(\"SoPlex\")")
end

function create()
    return ccall((:SoPlex_create, libsoplex), Ptr{Cvoid}, ())
end

function free(soplex::Ptr{Cvoid})
    return ccall((:SoPlex_free, libsoplex), Cvoid, (Ptr{Cvoid},), soplex)
end

function numRows(soplex::Ptr{Cvoid})
    return ccall((:SoPlex_numRows, libsoplex), Cint, (Ptr{Cvoid},), soplex)
end

function numCols(soplex::Ptr{Cvoid})
    return ccall((:SoPlex_numCols, libsoplex), Cint, (Ptr{Cvoid},), soplex)
end

function setRational(soplex::Ptr{Cvoid})
    return ccall((:SoPlex_setRational, libsoplex), Cvoid, (Ptr{Cvoid},), soplex)
end

function setIntParam(soplex::Ptr{Cvoid}, paramcode::Cint, paramvalue::Cint)
    return ccall((:SoPlex_setIntParam, libsoplex), Cvoid, (Ptr{Cvoid}, Cint, Cint), soplex, paramcode, paramvalue)
end

function addColReal(soplex::Ptr{Cvoid}, colentries::Ptr{Cdouble}, colsize::Cint, nnonzeros::Cint, objval::Cdouble, lb::Cdouble, ub::Cdouble)
    result = ccall((:SoPlex_addColReal, libsoplex), Cvoid,
         (Ptr{Cvoid}, Ptr{Cdouble}, Cint, Cint, Cdouble, Cdouble, Cdouble),
         soplex, colentries, colsize, nnonzeros, objval, lb, ub)
    return result
end

function addColRational(soplex::Ptr{Cvoid}, colnums::Ptr{Cint}, coldenoms::Ptr{Cint}, colsize::Cint, nnonzeros::Cint, objvalnum::Cint, objvaldenom::Cint, lbnum::Cint, lbdenom::Cint, ubnum::Cint, ubdenom::Cint)
    result = ccall((:SoPlex_addColRational, libsoplex), Cvoid,
         (Ptr{Cvoid}, Ptr{Cint}, Ptr{Cint}, Cint, Cint, Cint, Cint, Cint, Cint, Cint, Cint),
         soplex, colnums, coldenoms, colsize, nnonzeros, objnum, objdenom, lbnum, lbdenom, ubnum, ubdenom)
    return result
end

function addRowReal(soplex::Ptr{Cvoid}, rowentries::Ptr{Cdouble}, rowsize::Cint, nnonzeros::Cint, lb::Cdouble, ub::Cdouble)
    result = ccall((:SoPlex_addRowReal, libsoplex), Cvoid,
         (Ptr{Cvoid}, Ptr{Cdouble}, Cint, Cint, Cdouble, Cdouble),
         soplex, rowentries, rowsize, nnonzeros, lb, ub)
    return result
end

function addRowRational(soplex::Ptr{Cvoid}, rownums::Ptr{Cint}, rowdenoms::Ptr{Cint}, rowsize::Cint, nnonzeros::Cint, lbnum::Cint, lbdenom::Cint, ubnum::Cint, ubdenom::Cint)
    result = ccall((:SoPlex_addRowRational, libsoplex), Cvoid,
         (Ptr{Cvoid}, Ptr{Cint}, Ptr{Cint}, Cint, Cint, Cint, Cint, Cint, Cint),
         soplex, rownums, rowdenoms, rowsize, nnonzeros, lbnum, lbdenom, ubnum, ubdenom)
    return result
end

function getPrimalReal(soplex::Ptr{Cvoid}, primal::Ptr{Cdouble}, dim::Cint)
    return ccall((:SoPlex_getPrimalReal, libsoplex), Cvoid, (Ptr{Cvoid}, Ptr{Cdouble}, Cint), soplex, primal, dim)
end

function getDualReal(soplex::Ptr{Cvoid}, dual::Ptr{Cdouble}, dim::Cint)
    return ccall((:SoPlex_getDualReal, libsoplex), Cvoid, (Ptr{Cvoid}, Ptr{Cdouble}, Cint), soplex, dual, dim)
end

function optimizeLP(soplex::Ptr{Cvoid})
    return ccall((:SoPlex_optimize, libsoplex), Cvoid, (Ptr{Cvoid},), soplex)
end

end # module
