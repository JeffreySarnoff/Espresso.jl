
# einstein.jl - utils for working with expressions in Einstein notation

const IDX_NAMES = [:i, :j, :k, :l, :m, :n, :p, :q, :r, :s]


function isindexed(ex)
    return exprlike(ex) && (ex.head == :ref || any(isindexed, ex.args))
end

isvectorized(ex) = exprlike(ex) && !isindexed(ex)

is_einstein(ex) = !isempty(indexed_vars(ex))


function indexed(ex::Expr, idxs::Vector)
    @assert (ex.head == :ref) "Argument is not a symbol and not indexed already"
    return ex
end

function indexed(var::Symbol, idxs::Vector)
    return Expr(:ref, var, idxs...)
end


function maybe_indexed(var::Symbol, idxs::Vector)
    return length(idxs) > 0 ? Expr(:ref, var, idxs...) : var
end


parse_indexed(var) = (var, Symbol[])

function parse_indexed(ex::Expr)
    @assert ex.head == :ref
    return convert(Symbol, ex.args[1]), convert(Vector{Symbol}, ex.args[2:end])    
end


function call_indices(ex::Expr)
    if ex.head == :call     # e.g. :(x[i] + 1)
        return [parse_indexed(arg)[2] for arg in ex.args[2:end]]
    elseif ex.head == :(=)  # e.g. :(y[i] = x[i] + 1)
        lhs_idxs = parse_indexed(ex.args[1])[2]
        rhs_idxs = call_indices(ex.args[2])
        return vcat([lhs_idxs], rhs_idxs)
    else
        error("Don't know how to extract indices from expression $ex")
    end
end


function add_indices(ex, s2i::Dict)
    st = Dict([(k, maybe_indexed(k, v)) for (k, v) in s2i])
    return subs(ex, st)
end


function with_indices(x::Symbol, start_idx::Int, num_idxs::Int)
    return Expr(:ref, x, IDX_NAMES[start_idx:start_idx+num_idxs-1]...)
end

with_indices(x::Symbol, num_idxs::Int) = with_indices(x, 1, num_idxs)

# special variable

Base.getindex{T}(::UniformScaling{T}, ::Int64) = one(T)
Base.getindex{T}(::UniformScaling{T}, I...) = ones(T, length(I))
# Base.size{T}(::UniformScaling{T}) = ()


## """Collect index names used in expression"""
## function collect_indexes!(idxs::Vector{Symbol}, ex)
##     if isa(ex, Expr)  # otherwise ignore
##         if ex.head == :ref
##             append!(idxs, ex.args[2:end])
##         else
##             for arg in ex.args
##                 collect_indexes!(idxs, arg)
##             end
##         end
##     end
## end

## function collect_indexes(ex)
##     idxs = Array(Symbol, 0)
##     collect_indexes!(idxs, ex)
##     return idxs
## end


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


function get_indices(ex)
    idxs = [ref.args[2:end] for ref in indexed_vars(ex)]
    return convert(Vector{Vector{Symbol}}, idxs)
end


# forall & sum indices rules:
# 1. If there's LHS, everything on LHS is forall, everything else is sum
# 2. If all index tuples are equal, it's elementwise op => all forall
# 3. If all index tuples are equal or [], it's broadcasting => all forall
# 4. Otherwise, all repeating indices are sum, all others - forall

function longest_index(idxs_list::Vector{Vector{Symbol}})
    reduce((idx1, idx2) -> length(idx1) > length(idx2) ? idx1 : idx2, idxs_list)
end


function forall_sum_indices(ex::Expr)
    if ex.head == :(=)
        lhs_idxs = get_indices(ex.args[1])[1]
        rhs_idxs = flatten(Symbol, get_indices(ex.args[2]))
        sum_idxs = setdiff(rhs_idxs, lhs_idxs)
        return unique(lhs_idxs), sum_idxs
    else
        idxs_list = get_indices(ex)
        longest_idx = longest_index(idxs_list)
        elem_wise = all(idx -> idx == longest_idx || isempty(idx), idxs_list)
        if elem_wise
            return longest_idx, Symbol[]
        else
            @assert ex.head == :call
            op = ex.args[1]
            counts = countdict(flatten(idxs_list))
            repeated = collect(Symbol, keys(filter((idx, c) -> c > 1, counts)))
            non_repeated = collect(Symbol,
                                   keys(filter((idx, c) -> c == 1, counts)))
            # wrong!
            return op == :* ? (non_repeated, repeated) : (repeated, non_repeated)
        end
    end
end

forall_sum_indices(x) = (Symbol[], Symbol[])

forall_indices(x) = forall_sum_indices(x)[1]
sum_indices(x) = forall_sum_indices(x)[2]

# function forall_indices{T}(op::Symbolic, depidxs::Vector{Vector{T}})
#     if op == :* || op == :.*
#         counts = countdict(flatten(depidxs))
#         repeated = filter((idx, c) -> c == 1, counts)
#         return collect(Symbol, keys(repeated))
#     else
#         return unique(flatten(Symbol, depidxs))
#     end
# end

# function forall_indices(ex::Expr)
#     if ex.head == :ref
#         # TODO: take only nonrepeating
#         return convert(Vector{Symbol}, ex.args[2:end])
#     elseif ex.head == :call
#         depidxs = [forall_indices(x) for x in ex.args[2:end]]
#         return forall_indices(ex.args[1], depidxs)
#     else
#         return unique(flatten([forall_indices(x) for x in ex.args[2:end]]))
#     end
# end

# forall_indices(x) = Symbol[]

# function sum_indices{T}(op::Symbolic, depidxs::Vector{Vector{T}})    
#     if op == :* || op == .*
#         counts = countdict(flatten(depidxs))
#         repeated = filter((idx, c) -> c > 1, counts)
#         return collect(Symbol, keys(repeated))
#     else
#         return Symbol[]
#     end
# end

# function sum_indices(ex::Expr)
#     if ex.head == :ref
#         # TODO: take repeating indices
#         return Symbol[]
#     elseif ex.head == :call
#         sum_depidxs = unique(flatten([sum_indices(x) for x in ex.args[2:end]]))
#         forall_depidxs = [forall_indices(x) for x in ex.args[2:end]]
#         new_sum_idxs = sum_indices(ex.args[1], forall_depidxs)
#         return unique(flatten([sum_depidxs, new_sum_idxs]))
#     else
#         return Symbol[]
#     end
# end

# sum_indices(x) = Symbol[]


# guards

isequality(ex) = isa(ex, Expr) && ex.head == :call && ex.args[1] == :(==)

function get_guards!(guards::Vector{Expr}, ex::Expr)
    if isequality(ex)
        push!(guards, ex)
    else
        for arg in ex.args
            get_guards!(guards, arg)
        end
    end
    return guards
end

get_guards!(guards::Vector{Expr}, x) = guards
get_guards(ex) = get_guards!(Expr[], ex)


function without_guards(ex)
    return without(ex, :(i == j); phs=[:i, :j])
end


# LHS inference (not used for now)

function infer_lhs(ex::Expr; outvar=:_R)
    idxs = forall_indices(ex)
    return Expr(:ref, outvar, idxs...)
end


function with_lhs(ex::Expr; outvar=:_R)
    lhs = infer_lhs(ex; outvar=outvar)
    return Expr(:(=), lhs, ex)
end


# einsum

"""
Translates guarded expression, e.g. :(Y[i,j] = X[i] * (i == j)),
into the unguarded one, e.g. :(Y[i, i] = X[i])
"""
function unguarded(ex::Expr)    
    st = Dict([(grd.args[3], grd.args[2]) for grd in get_guards(ex)])
    new_ex = without_guards(ex)
    idxs = @view new_ex.args[1].args[2:end]
    for i=1:length(idxs)        
        if haskey(st, idxs[i])
            idxs[i] = st[idxs[i]]
        end
    end
    return new_ex
end

function to_einsum(ex::Expr)
    if ex.head == :block
        return to_block(map(to_einsum, ex.args))
    else
        @assert ex.head == :(=)
        uex = unguarded(ex)
        return :(@einsum $(uex.args[1]) := $(uex.args[2]))
    end        
end

