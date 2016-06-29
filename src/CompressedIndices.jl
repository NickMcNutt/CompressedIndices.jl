module CompressedIndices

import Base: length, size, getindex, start, next, done, push!, append!
export Indices

typealias AbstractIndices Union{Int, AbstractVector{Int}}

immutable Indices <: AbstractVector{Int}
    indices::Vector{AbstractIndices}
end

Indices(indices::AbstractIndices...) = Indices(AbstractIndices[i for i in indices])

length(a::Indices) = sum(length, a.indices)
size(a::Indices) = (length(a),)

function getindex(a::Indices, index::Int)
    1 <= index <= length(a) || throw(BoundsError(a, index))
    
    n = 0
    for indices in a.indices
        l = length(indices)
        n + l >= index && return indices[index - n]
        n += l
    end
end

start(a::Indices) = (0, 1, 1)

function next(a::Indices, state)
    n, i, index = state
    item = a.indices[i][index - n]
    
    l = length(a.indices[i])
    index += 1
    
    if index > n + l
        n += l
        i += 1
    end
    
    return item, (n, i, index)
end

done(a::Indices, state) = state[2] > length(a.indices)

function push!(b::Vector{Int}, a::Indices, index::Int)
    c = index - 1
    l = endof(b)
    i = l
    while b[i] == c
        c -= 1
        i -= 1
        i == 0 && break
    end

    if i == l
        push!(b, index)
    elseif i > 1
        deleteat!(b, (i + 1):l)
        push!(a.indices, (c + 1):index)
    elseif i == 1
        f = b[1]

        pop!(a.indices)
        if length(a.indices) > 0
            push!(a, f)
        else
            push!(a.indices, f)
        end

        append!(a, (c + 1):index)
    else
        a.indices[end] = (c + 1):index
    end

    return a
end

function push!(b::Int, a::Indices, index::Int)
    if b == index - 1
        a.indices[end] = b:index
    else
        a.indices[end] = Int[b, index]
    end

    return a
end

function push!(b::UnitRange{Int}, a::Indices, index::Int)
    l::Int = b[end]
    if l == index - 1
        a.indices[end] = b[1]:index
    else
        push!(a.indices, index)
    end

    return a
end

push!(a::Indices, index::Int) = push!(last(a.indices), a, index)

# Optimize this:
append!(a::Indices, ind::AbstractVector{Int}) = push!(a.indices, ind)

end
