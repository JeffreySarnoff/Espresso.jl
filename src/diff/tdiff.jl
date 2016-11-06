
function permute_indices(idxs::Vector{Symbol}, orig::Vector{Symbol}, perm::Vector{Symbol})
    d = Dict(zip(orig, idxs))
    return [d[x] for x in perm]
end


function rev_step!(g::ExGraph, nd::ExNode{:(=)}, adj::Dict{Symbol, TensorDeriv})
    # TODO: detect index permutation or inner contraction and handle it properly
    y = nd.var
    x = dependencies(nd)[1]
    dzdx = copy(adj[y])
    dzdx.wrt.args[1] = dname(x)
    wrtidxs = convert(Vector{Symbol}, dzdx.wrt.args[2:end])
    dzdx.wrt.args[2:end] = permute_indices(wrtidxs, nd.idxs[2], nd.idxs[1])
    adj[x] = dzdx
end

function rev_step!(g::ExGraph, nd::ExNode{:constant},
                   adj::Dict{Symbol, TensorDeriv})
    adj[nd.var] = TensorDeriv(0.)
end

function rev_step!(g::ExGraph, nd::ExNode{:input},
                   adj::Dict{Symbol,TensorDeriv})
    # do nothing
end


function rev_step!(g::ExGraph, nd::ExNode{:call}, adj::Dict{Symbol, TensorDeriv})
    y = nd.var
    iex = to_iexpr(nd)
    dzdy = adj[y]
    for (i, x) in enumerate(dependencies(nd))
        dydx = tderivative(iex, x)
        dzdx = dzdy * dydx
        if haskey(adj, x)
            adj[x] += dzdx
        else
            adj[x] = dzdy * dydx
        end
    end
end


# other utils

function expand_adjoints(g::ExGraph, adj::Dict{Symbol, TensorDeriv})
    return Dict([(var, to_expr(td)) for (var, td) in adj])
end


function tdiff(ex::Expr; ctx=Dict(), inputs...)
    ctx = to_context(ctx)
    tex = to_einstein(ex; inputs...)
    g, adj = _rdiff(tex; ctx=ctx, inputs...)
    vars = Set([var for (var, val) in inputs])
    dexs = Dict([(var, dex) for (var, dex) in adj if in(var, vars)])
    return dexs
end


# TODO: refactor rdiff to return single expression with
# expression and derivatives like in 


function main2()
    ex = :(relu(W * x))
    inputs = [:W=>rand(3,4), :x=>rand(4)] #, :b=>rand(3)]
    ctx = Dict()
    tdiff(ex; inputs...)
end
