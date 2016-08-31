
a=rand(3,2)
b=rand(2,3)

ex = quote
    c[i,j] = a[i,k] * b[k,j]
    d = cos(c)
end

g = ExGraph(;a=a, b=b)
parse!(g, ex)
r = evaluate!(g, g.tape[end])

@test cos(a * b) == r
