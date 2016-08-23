
# (op, [types]) => (orig, tformed)
const EINSTEIN_EXPAND_RULES =
    Dict{Tuple{Symbolic, Vector{Type}}, Tuple{Expr, Expr}}()


function op_and_types(pat::Expr)
    op = opname(current_module(), pat.args[1])
    types = [eval(exa.args[2]) for exa in pat.args[2:end]]
    return op, types
end


function add_einstein_expand_rule(pat::Expr, tformed::Expr)
    op, types = op_and_types(pat)
    EINSTEIN_EXPAND_RULES[(op, types)] = (pat, tformed)
end

macro einstein_expand_rule(pat::Expr, tformed::Expr)
    add_einstein_expand_rule(pat, tformed)
end




@einstein_expand_rule (W::AbstractMatrix * x::AbstractVector) :(W[i, j] * x[i])



# consider ExCall{:op} type instead

function to_einstein(ex::Expr, types::Vector{Type})
    op, types = ex.head
    # TODO
end

function to_vectorized(ex::Expr)
    
end



function main()   
    pat = :(W::AbstractMatrix * x::AbstractVector)
    tformed = :(W[i, j] * x[i])
end
