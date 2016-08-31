
# einstein.jl - utils for working with expressions in Einstein notation

function isindexed(ex)
    if exprlike(ex)
        return ex.head == :ref || any(isindexed, ex.args)
    else
        return false
    end
end


"""Transform expression into Einstein notation, infer types from vals"""
to_einstein(ex::Expr, vals...) = to_einstein(to_excall(ex), vals...)

function addindexes(ex, s2i::Dict)
    st = [(k => Expr(:ref, k, v...)) for (k, v) in s2i]
    return subs(ex, st)
end


# TODO: use add_indexes()
function to_einstein(exc::ExCall{:*}, ::AbstractMatrix, ::AbstractMatrix)
    ex = to_expr(exc)
    A, B = ex.args[2:3]
    st = Dict(A => Expr(:ref, A, :i, :k),
              B => Expr(:ref, B, :k, :j))
    return subs(ex, st)
end


function to_einstein(exc::ExCall{:*}, ::AbstractMatrix, ::AbstractVector)
    ex = to_expr(exc)
    A, B = ex.args[2:3]
    st = Dict(A => Expr(:ref, A, :i, :j),
              B => Expr(:ref, B, :j))
    return subs(ex, st)
end


const IDX_NAMES = [:i, :j, :k, :l, :m, :n, :p, :q, :r, :s]

for op in [:+, :-, .+, .-, .*, ./]

    @eval function to_einstein{T,N}(exc::ExCall{Symbol($op)},
                                    ::AbstractArray{T,N}, ::AbstractArray{T,N})
        ex = to_expr(exc)
        A, B = ex.args[2:3]
        if N > length(IDX_NAMES)
            error("Ran out of index names for this tensor!")
        end
        st = Dict(A => Expr(:ref, A, IDX_NAMES[1:N]...),
                  B => Expr(:ref, B, IDX_NAMES[1:N]...))
        return subs(ex, st)
    end

end

## """Check if expression contains indexed elements, e.g. x[i]"""
## function is_indexed(ex)
##     return expr_like(ex) && (ex.head == :ref || any(is_indexed, ex.args))
## end

"""Collect index names used in expression"""
function collect_indexes!(idxs::Vector{Symbol}, ex)
    if isa(ex, Expr)  # otherwise ignore
        if ex.head == :ref
            append!(idxs, ex.args[2:end])
        else
            for arg in ex.args
                collect_indexes!(idxs, arg)
            end
        end
    end
end
    
function collect_indexes(ex)
    idxs = Array(Symbol, 0)
    collect_indexes!(idxs, ex)
    return idxs
end


function indexed_vars!(res::Vector{Expr}, ex)
    if exprlike(ex)
        if ex.head == :ref
            push!(res, ex)
        else
            for arg in ex.args
                indexed_vars!(res, arg)
            end
        end    
    end
end

function indexed_vars(ex)
    res = Array(Expr, 0)
    indexed_vars!(res, ex)
    return res
end

all_indexes(ex) = [ref.args[2:end] for ref in indexed_vars(ex)]


function sum_indexes(ex::Expr)
    @assert ex.head == :call
    # only product of 2 tensors implies that repeating indexes need to be summed
    # e.g. in `c[i] = a[i] + b[i]` index i means "for each", not "sum"
    if ex.args[1] == :*
        idxs = flatten([collect_indexes(arg) for arg in ex.args[2:end]])
        counts = countdict(idxs)
        repeated = filter((idx, c) -> c > 1, counts)
        return collect(Symbol, keys(repeated))
    else
        return Symbol[]
    end
end


"""Accepts single call expressions, e.g. :(A[i,k] * B[k,j]) or :(exp(C[i]))"""
function forall_and_sum_indexes(ex::Expr)
    @assert ex.head == :call
    @assert reduce(&, [isa(arg, Expr) && arg.head == :ref
                       for arg in ex.args[2:end]])
    all_idxs = unique(collect_indexes(ex))
    sum_idxs = sum_indexes(ex)
    forall_idxs = setdiff(all_idxs, sum_idxs)
    return forall_idxs, sum_idxs
end


forall_indexes(ex::Expr) = forall_and_sum_indexes(ex)[1]



function forall_indexes{T}(op::Symbolic, depidxs::Vector{Vector{T}})
    if op == :*
        counts = countdict(flatten(depidxs))
        repeated = filter((idx, c) -> c == 1, counts)
        return collect(Symbol, keys(repeated))
    else
        return unique(flatten(Symbol, depidxs))
    end
end

function sum_indexes(op::Symbolic, depidxs::Vector{Vector})
    if op == :*
        counts = countdict(flatten(depidxs))
        repeated = filter((idx, c) -> c > 1, counts)
        return collect(Symbol, keys(repeated))
    else
        return unique(flatten(Symbol, depidxs))
    end
end




