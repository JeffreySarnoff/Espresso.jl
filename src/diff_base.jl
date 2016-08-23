
# diff_base.jl - common routines for ordinary symbolic and tensor differentiation

abstract DiffRule

immutable SymbolicDiffRule <: DiffRule
    ex::Expr     # pattern of expression to differentiate
    idx::Int     # index of argument to differentiate against
    dex::Expr    # pattern of differentiation expression
end


function extract_symbolic_rule(ex::Expr)
    # TODO
end
