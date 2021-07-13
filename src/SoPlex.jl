module SoPlex

const deps_file = joinpath(dirname(@__FILE__),"..","deps","deps.jl")
if isfile(deps_file)
    include(deps_file)
else
    error("SoPlex not properly installed. Please run import Pkg; Pkg.build(\"SoPlex\")")
end

include("commons.jl")
include("ctypes.jl")
include("soplex_interface.jl")
include("MOI_wrapper/MOI_wrapper.jl")

end # module
