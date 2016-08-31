
# core.jl - single place to load all package definitions.
#
# If you are willing to learn the package structure, just go through
# included files one by one, read header notes and other comments

using Iterators
using TensorOperations
using Compat

include("utils.jl")
include("types.jl")
include("rewrite.jl")
include("simplify.jl")
include("ops.jl")
include("funexpr.jl")
include("diff_rules.jl")
include("einstein.jl")
include("exgraph.jl")
include("rdiff.jl")
