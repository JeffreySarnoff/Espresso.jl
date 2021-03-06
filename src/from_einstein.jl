
# from Einstein to vectorized notation

const FROM_EIN_PHS = [:A, :B, :C, :X, :Y, :V, :W, :Z,
                      :i, :j, :k, :l, :m, :n, :p, :q, :r, :s, :t]

const FROM_EINSTEIN_CALL_RULES =
    OrderedDict(# inner and outer product
                :(Z[i,j] = X[i] * Y[j]) => :(Z = X * Y'),
                :(Z = X[i] * Y[i]) => :(Z = X'Y),
                :(Z[i,j] = X[i] .* Y[j]) => :(Z = X * Y'),
                :(Z = X[i] .* Y[i]) => :(Z = X'Y),
                # matrix-by-vector
                :(Z[j] = X[i] * Y[i,j]) => :(Z = Y' * X),
                :(Z[i] = X[j] * Y[i,j]) => :(Z = Y * X),
                :(Z[i] = X[i,j] * Y[j]) => :(Z = X * Y),
                :(Z = X[i,j] * Y[j]) => :(Z = sum(X * Y)),
                :(Z[j] = X[i,j] * Y[i]) => :(Z = X' * Y),
                :(Z = X[i,j] * Y[i]) => :(Z = sum(X' * Y)),
                :(Z[j] = X[i] .* Y[i,j]) => :(Z = Y' * X),
                :(Z[i] = X[j] .* Y[i,j]) => :(Z = Y * X),
                :(Z[i] = X[i,j] .* Y[j]) => :(Z = X * Y),
                :(Z[j] = X[i,j] .* Y[i]) => :(Z = X' * Y),
                :(Z[i,j] = X[i,j] .* Y[i]) => :(Z = X .* Y),
                :(Z[i,j] = X[i,j] .* Y[j]) => :(Z = X .* Y'),
                # matrix-by-matrix
                :(Z[i,j] = X[i,k] * Y[k,j]) => :(Z = X * Y),
                :(Z[i,j] = Y[k,j] * X[i,k]) => :(Z = X * Y),
                :(Z[i,j] = X[i,k] .* Y[k,j]) => :(Z = X * Y),
                :(Z[i,j] = Y[k,j] .* X[i,k]) => :(Z = X * Y),
                :(Z[i,j] = Y[i,j] .* X[j,i]) => :(Z = X * Y'),
                # matrix-by-matrix: 3-index rule
                :(Z[i,j] = X[i,k] .* Y[j,k]) => :(Z = X * Y'),
                :(Z[i,j] = X[k,i] .* Y[k,j]) => :(Z = X' * Y),
                :(Z[j,i] = X[i,k] .* Y[j,k]) => :(Z = Y * X'),  # same transposed
                :(Z[j,i] = X[k,i] .* Y[k,j]) => :(Z = Y' * X),  # same transposed
                # special .+ and .*
                :(Z[i,j] = X[j] .+ Y[i,j]) => :(Z = X' .+ Y),
                :(Z[i,j] = X .* Y[j]) => :(Z = repmat((X .* Y)', size__(Z)[1])),
                :(Z[j] = X .* Y[i,j]) => :(Z = X .* squeeze(sum(Y,1),1)),                
                # eye
                :(Z[i,j] = 1 * (i == j)) => :(Z = eye(size__(Z))[1]),
                # –> ∑ₖxᵢyⱼₖ == xᵢ∑ₖyⱼₖ   # TODO: seems incorrect, see 2-level rules
                # :(Z[i,j] = X[i] .* Y[j,k]) => :(Z = X .* squeeze(sum(Y,2),2))
                # broadcasting
                :(Z = _f(X)) => :(Z = _f(X)),
                :(Z = _f(X, Y)) => :(Z = _f(X, Y)),
                :(Z[i...] = _f(X[i...])) => :(Z = _f.(X)),
                :(Z[i...] = _f(X[i...], Y[i...])) => :(Z = _f.(X, Y)),
                :(Z[i...] = _f(X[i...], Y)) => :(Z = _f.(X, Y)),
                :(Z[i...] = _f(X, Y[i...])) => :(Z = _f.(X, Y)),
                # broadcasting with module
                :(Z = _M._f(X)) => :(Z = _M._f(X)),
                :(Z = _M._f(X, Y)) => :(Z = _M._f(X, Y)),
                :(Z[i...] = _M._f(X[i...])) => :(Z = _M._f.(X)),
                :(Z[i...] = _M._f(X[i...], Y[i...])) => :(Z = _M._f.(X, Y)),
                :(Z[i...] = _M._f(X[i...], Y)) => :(Z = _M._f.(X, Y)),
                :(Z[i...] = _M._f(X, Y[i...])) => :(Z = _M._f.(X, Y)),                
                # broadcasting + sum
                :(Z = _f(X[i])) => :(Z = sum(_f.(X))),
                :(Z = _f(X[i,j])) => :(Z = sum(_f.(X))),
                :(Z[i] = _f(X[i,j])) => :(Z = squeeze(sum(_f.(X),2),2)),
                :(Z[j] = _f(X[i,j])) => :(Z = squeeze(sum(_f.(X),1),1)),
                :(Z = _f(X[i], Y)) => :(Z = sum(_f.(X, Y))),
                :(Z = _f(X, Y[i])) => :(Z = sum(_f.(X, Y))),
                :(Z = _f(X[i], Y[i])) => :(Z = sum(_f.(X, Y))),
                :(Z = _f(X[i,j], Y[i,j])) => :(Z = sum.(_f(X, Y))),
                # constants
                :(Z[i...] = _f(X, Y)) => :(Z = ones(size__(Z)) .* _f(X, Y)),
                # convolution
                # TODO: test conv rules
                # direct conv
                :(Z[i,j] = X[i+m-1, j+n-1] * W[m,n]) => :(Z = conv2(X, W)),
                :(Z = X[i+m-1, j+n-1] * W[m,n]) => :(Z = sum(conv2(X, W))),
                # reverse conv
                :(Z[i,j] = X[p-i+1, q-j+1] * Y[p, q]) => :(Z = conv2(X, flip(X))),
                :(Z = X[p-i+1, q-j+1] * Y[p, q]) => :(Z = sum(conv2(X, flip(X)))),
                # conv over ones(...)
                :(Z[m,n] = X[i+m-1, j+n-1]) => :(Z = conv2(X, ones(size__(Z)))),
                :(Z[p,q] = X[p-i+1, q-j+1]) => :(Z = conv2(ones(size__(Z)), flip(X))),
                )


const FROM_EINSTEIN_ASSIGN_RULES =
    OrderedDict(# simple assignment
                :(Z = X) => :(Z = X),
                :(Z[i...] = X[i...]) => :(Z = X),
                # summation
                :(Z = X[i]) => :(Z = sum(X)),
                :(Z = X[i,j]) => :(Z = sum(X)),
                :(Z = X[i,j,k]) => :(Z = sum(X)),
                :(Z[i] = X[i,j]) => :(Z = squeeze(sum(X,2),2)),
                :(Z[j] = X[i,j]) => :(Z = squeeze(sum(X,1),1)),                
                :(Z[i,j] = X[i,j,k]) => :(Z = squeeze(sum(X,3),3)),
                :(Z[i,k] = X[i,j,k]) => :(Z = squeeze(sum(X,2),2)),
                :(Z[j,k] = X[i,j,k]) => :(Z = squeeze(sum(X,1),1)),
                # repmat
                :(Z[i,j] = X[j]) => :(Z = repmat(X', size__(Z)[1])),
                :(Z[i,j] = X[i]) => :(Z = repmat(X, 1, size__(Z)[2])),
                # eye
                :(Z[i,j] = 1 * (i == j)) => :(Z = eye(size__(Z))[1]),
                # constant
                :(Z[i...] = X) => :(Z = ones(size__(Z)) * X),
                # other cases
                :(Z[i,j] = X[j,k]) => :(Z = repmat(squeeze(sum(X, 2), 2)', size__(Z)[1])))



const FROM_EINSTEIN_CONST_RULES =
    OrderedDict(:(Z = X) => :(Z = X),
                :(Z[i...] = X) => :(Z = ones(size__(Z)) * X),)



function to_einsum(ex::Expr)
    if ex.head == :block
        return to_block(map(to_einsum, ex.args))
    else
        @assert ex.head == :(=)
        uex = unguarded(ex)
        return :(@einsum $(uex.args[1]) := $(uex.args[2]))
    end
end


function from_einstein(ex::Expr; ctx=Dict(), inputs...)
    g = EinGraph(ex; ctx=ctx, inputs...)
    return from_einstein(g)
end


function from_einstein(g::EinGraph)
    sizes = @get(g.ctx, :sizes, Dict())
    res = :(begin end)
    for nd in g.tape
        if !isa(nd, ExNode{:input})
            vex = from_einstein(g, nd)
            push!(res.args, simplify(subs_size(vex, sizes)))
        end
    end
    # res = remove_unused(res) # can't remove unused because last expression
                               # may not be output var
    res = subs_bcast_with_dot(sanitize(res))
    return res
end

from_einstein(g::EinGraph, nd::ExNode{:input}) = getexpr(nd)

function from_einstein(g::EinGraph, nd::ExNode{:constant})
    ex = to_expr(nd)
    for (pat, rpat) in FROM_EINSTEIN_CONST_RULES
        rex = tryrewrite(ex, pat, rpat; phs=FROM_EIN_PHS, allow_ex=false)
        if !isnull(rex)
            return get(rex)
        end
    end
    throw(ErrorException("Can't convert to vectorized notation constant node: $nd"))
end


iscall(x) = isa(x, Expr) && x.head == :call

function convert_call(g::EinGraph, nd::ExNode{:call})
    new_ex = expand_const(g, getexpr(nd)) |> simplify
    if isa(new_ex, Symbol) || (isa(new_ex, Expr) && new_ex.head == :ref)
        # convert to assignment
        return copy(nd; category=:(=), ex=new_ex)
    elseif isa(new_ex, Number) || isa(new_ex, AbstractArray)
        # convert to constant
        return copy(nd; category=:constant, ex=new_ex)
    else
        error("Call node $nd is simplified to an unknown non-call $new_ex")
    end
end


function from_einstein(g::EinGraph, nd::ExNode{:call})
    ex = expand_const(g, to_expr(nd)) |> simplify
    if !iscall(ex.args[2])
        return from_einstein(g, convert_call(g, nd))
    end
    for (pat, rpat) in FROM_EINSTEIN_CALL_RULES
        # consider tryrewrite
        rex = tryrewrite(ex, pat, rpat; phs=FROM_EIN_PHS, allow_ex=false)
        if !isnull(rex)
            return get(rex)
        end
    end
    # if length(varidxs(nd)) >= 3
    #     error("Can't convert to vectorized notation a tensor of " *
    #           "$(length(varidxs(nd))) dimensions: $(to_expr(nd))")
    # end
    # if no pattern matches, try broadcasting
    is_bcast_old = in(ex.args[2].args[1], Set([:.*, :.+, :.-, :./, :.^]))
    if is_bcast_old
        # nearly deprecated syntax, but still actively used in 0.6
        call = Expr(:call, getexpr(nd).args[1], dependencies(nd)...)
        # TODO: this doesn't cover implicit summation, e.g. `z = x[i] .* y`
        # we can cover it using rules above or track forall indices
        return Expr(:(=), varname(nd), call)
    else
        error("Neither pattern found, nor broadcasting is applicable when transforming from " *
              "Einstein notation, expression: $ex")
    end
end


function from_einstein(g::EinGraph, nd::ExNode{:(=)})
    ex = to_expr(nd)
    for (pat, rpat) in FROM_EINSTEIN_ASSIGN_RULES
        rex = tryrewrite(ex, pat, rpat; phs=FROM_EIN_PHS, allow_ex=false)
        if !isnull(rex)
            return get(rex)
        end
    end
    error("No pattern found for $nd while converting it from Einstein notation")
end


function from_einstein(g::EinGraph, nd::ExNode{:bcast})
    ex = to_expr(nd)
    vars = findex(:(_x[_i...]), ex)
    st = Dict(var => var.args[1] for var in vars)
    return subs(ex, st)
end


function from_einstein(g::EinGraph, nd::ExNode{:tuple})
    return without_indices(to_expr(nd))
end
