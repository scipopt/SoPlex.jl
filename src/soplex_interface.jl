# Julia wrapper for header: soplex_interface.h
# Automatically generated using Clang.jl


function SoPlex_create()
    ccall((:SoPlex_create, libsoplex), Ptr{Cvoid}, ())
end

function SoPlex_free(soplex)
    ccall((:SoPlex_free, libsoplex), Cvoid, (Ptr{Cvoid},), soplex)
end

function SoPlex_clearLPReal(soplex)
    ccall((:SoPlex_clearLPReal, libsoplex), Cvoid, (Ptr{Cvoid},), soplex)
end

function SoPlex_numRows(soplex)
    ccall((:SoPlex_numRows, libsoplex), Cint, (Ptr{Cvoid},), soplex)
end

function SoPlex_numCols(soplex)
    ccall((:SoPlex_numCols, libsoplex), Cint, (Ptr{Cvoid},), soplex)
end

function SoPlex_setRational(soplex)
    ccall((:SoPlex_setRational, libsoplex), Cvoid, (Ptr{Cvoid},), soplex)
end

function SoPlex_setIntParam(soplex, paramcode, paramvalue)
    ccall((:SoPlex_setIntParam, libsoplex), Cvoid, (Ptr{Cvoid}, Cint, Cint), soplex, paramcode, paramvalue)
end

function SoPlex_getIntParam(soplex, paramcode)
    ccall((:SoPlex_getIntParam, libsoplex), Cint, (Ptr{Cvoid}, Cint), soplex, paramcode)
end

function SoPlex_addColReal(soplex, colentries, colsize, nnonzeros, objval, lb, ub)
    ccall((:SoPlex_addColReal, libsoplex), Cvoid, (Ptr{Cvoid}, Ptr{Cdouble}, Cint, Cint, Cdouble, Cdouble, Cdouble), soplex, colentries, colsize, nnonzeros, objval, lb, ub)
end

function SoPlex_addColRational(soplex, colnums, coldenoms, colsize, nnonzeros, objvalnum, objvaldenom, lbnum, lbdenom, ubnum, ubdenom)
    ccall((:SoPlex_addColRational, libsoplex), Cvoid, (Ptr{Cvoid}, Ptr{Clong}, Ptr{Clong}, Cint, Cint, Clong, Clong, Clong, Clong, Clong, Clong), soplex, colnums, coldenoms, colsize, nnonzeros, objvalnum, objvaldenom, lbnum, lbdenom, ubnum, ubdenom)
end

function SoPlex_addRowReal(soplex, rowentries, rowsize, nnonzeros, lb, ub)
    ccall((:SoPlex_addRowReal, libsoplex), Cvoid, (Ptr{Cvoid}, Ptr{Cdouble}, Cint, Cint, Cdouble, Cdouble), soplex, rowentries, rowsize, nnonzeros, lb, ub)
end

function SoPlex_addRowRational(soplex, rownums, rowdenoms, rowsize, nnonzeros, lbnum, lbdenom, ubnum, ubdenom)
    ccall((:SoPlex_addRowRational, libsoplex), Cvoid, (Ptr{Cvoid}, Ptr{Clong}, Ptr{Clong}, Cint, Cint, Clong, Clong, Clong, Clong), soplex, rownums, rowdenoms, rowsize, nnonzeros, lbnum, lbdenom, ubnum, ubdenom)
end

function SoPlex_getPrimalReal(soplex, primal, dim)
    ccall((:SoPlex_getPrimalReal, libsoplex), Cvoid, (Ptr{Cvoid}, Ptr{Cdouble}, Cint), soplex, primal, dim)
end

function SoPlex_getPrimalRationalString(soplex, dim)
    ccall((:SoPlex_getPrimalRationalString, libsoplex), Cstring, (Ptr{Cvoid}, Cint), soplex, dim)
end

function SoPlex_getDualReal(soplex, dual, dim)
    ccall((:SoPlex_getDualReal, libsoplex), Cvoid, (Ptr{Cvoid}, Ptr{Cdouble}, Cint), soplex, dual, dim)
end

function SoPlex_optimize(soplex)
    ccall((:SoPlex_optimize, libsoplex), Cint, (Ptr{Cvoid},), soplex)
end

function SoPlex_changeObjReal(soplex, obj, dim)
    ccall((:SoPlex_changeObjReal, libsoplex), Cvoid, (Ptr{Cvoid}, Ptr{Cdouble}, Cint), soplex, obj, dim)
end

function SoPlex_changeObjRational(soplex, objnums, objdenoms, dim)
    ccall((:SoPlex_changeObjRational, libsoplex), Cvoid, (Ptr{Cvoid}, Ptr{Clong}, Ptr{Clong}, Cint), soplex, objnums, objdenoms, dim)
end

function SoPlex_changeLhsReal(soplex, lhs, dim)
    ccall((:SoPlex_changeLhsReal, libsoplex), Cvoid, (Ptr{Cvoid}, Ptr{Cdouble}, Cint), soplex, lhs, dim)
end

function SoPlex_changeLhsRational(soplex, lhsnums, lhsdenoms, dim)
    ccall((:SoPlex_changeLhsRational, libsoplex), Cvoid, (Ptr{Cvoid}, Ptr{Clong}, Ptr{Clong}, Cint), soplex, lhsnums, lhsdenoms, dim)
end

function SoPlex_changeRhsReal(soplex, rhs, dim)
    ccall((:SoPlex_changeRhsReal, libsoplex), Cvoid, (Ptr{Cvoid}, Ptr{Cdouble}, Cint), soplex, rhs, dim)
end

function SoPlex_changeRhsRational(soplex, rhsnums, rhsdenoms, dim)
    ccall((:SoPlex_changeRhsRational, libsoplex), Cvoid, (Ptr{Cvoid}, Ptr{Clong}, Ptr{Clong}, Cint), soplex, rhsnums, rhsdenoms, dim)
end

function SoPlex_writeFileReal(soplex, filename)
    ccall((:SoPlex_writeFileReal, libsoplex), Cvoid, (Ptr{Cvoid}, Cstring), soplex, filename)
end

function SoPlex_objValueReal(soplex)
    ccall((:SoPlex_objValueReal, libsoplex), Cdouble, (Ptr{Cvoid},), soplex)
end

function SoPlex_objValueRationalString(soplex)
    ccall((:SoPlex_objValueRationalString, libsoplex), Cstring, (Ptr{Cvoid},), soplex)
end

function SoPlex_changeBoundsReal(soplex, lb, ub, dim)
    ccall((:SoPlex_changeBoundsReal, libsoplex), Cvoid, (Ptr{Cvoid}, Ptr{Cdouble}, Ptr{Cdouble}, Cint), soplex, lb, ub, dim)
end

function SoPlex_changeVarBoundsReal(soplex, colidx, lb, ub)
    ccall((:SoPlex_changeVarBoundsReal, libsoplex), Cvoid, (Ptr{Cvoid}, Cint, Cdouble, Cdouble), soplex, colidx, lb, ub)
end

function SoPlex_changeVarBoundsRational(soplex, colidx, lbnum, lbdenom, ubnum, ubdenom)
    ccall((:SoPlex_changeVarBoundsRational, libsoplex), Cvoid, (Ptr{Cvoid}, Cint, Clong, Clong, Clong, Clong), soplex, colidx, lbnum, lbdenom, ubnum, ubdenom)
end

function SoPlex_changeVarUpperReal(soplex, colidx, ub)
    ccall((:SoPlex_changeVarUpperReal, libsoplex), Cvoid, (Ptr{Cvoid}, Cint, Cdouble), soplex, colidx, ub)
end

function SoPlex_getUpperReal(soplex, ub, dim)
    ccall((:SoPlex_getUpperReal, libsoplex), Cvoid, (Ptr{Cvoid}, Ptr{Cdouble}, Cint), soplex, ub, dim)
end

function SoPlex_basisRowStatus(soplex, rowidx)
    ccall((:SoPlex_basisRowStatus, libsoplex), Cint, (Ptr{Cvoid}, Cint), soplex, rowidx)
end

function SoPlex_basisColStatus(soplex, colidx)
    ccall((:SoPlex_basisColStatus, libsoplex), Cint, (Ptr{Cvoid}, Cint), soplex, colidx)
end
