const TENSOR_DIFF_PHS = Set([:A, :B, :C, :X, :Y, :Z, :i, :j, :k, :op])


indexes(ex::Expr) = (ex.head == :ref
                     ? map(Symbol, ex.args[2:end])
                     : throw(ArgumentError(":($ex) is not a :ref expression")))


immutable TensorDiffRule <: DiffRule
    ex::Expr     # pattern of expression to differentiate
    idx::Int     # index of argument to differentiate against
    dex::Expr    # pattern of differentiation expression
end


is_tensor_expr(x) = false
is_tensor_expr(ex::Expr) = ex.head == :ref || any(map(is_tensor_expr, ex.args))


expr_to_tensor_type(ex::Expr) = AbstractArray{Float64, length(indexes(ex))}



function extract_tensor_rule(ex::Expr)
    nullable_m = matchex(:(C = op(A, B)), ex; phs=TENSOR_DIFF_PHS)
    if isnull(nullable_m) throw(ArgumentError("$ex")) end
    m = get(nullable_m)
    CT = expr_to_tensor_type(m[:C])
    AT = expr_to_tensor_type(m[:A])
    BT = expr_to_tensor_type(m[:B])
    # TODO: and what?
end





function add_diff_rule(ex::Expr, idx::Int, dex::Expr)
    rule = (is_tensor_expr(ex)
            ? extract_tensor_rule(ex)
            : extract_symbolic_rule(ex))
end


function add_tensor_diff_rule(ex::Expr, idx::Int, dex::Any)



end


# @tensor_diff_rule (C[i,j] = A[i,k] * B[k,j]) 1 B[k,j]

function main()
    pat = :(C[i,j] = A[i,k] * B[k,j])
    dpat = :(B[k, j])
    ex = :(Z[i1, i2] = X[i1, k1] * Y[k1, i2])
    rewrite(ex, pat, dpat; phs=TENSOR_DIFF_PHS)
end


function main2()
    ex = quote
        z[i] = W[i,j] * x[j] + b[i]
    end

    tnz1[i] = W[i,j] * x[j]
    tnz2[i] = tnz1[i] + b[i]
    sum(tnz2[i])
end
