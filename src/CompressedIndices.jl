module CompressedIndices

import Base: length, size, getindex, start, next, done
export Indices, length, size, getindex, start, next, done

type Indices <: AbstractVector{Int}
    indices::Vector{Union{Int, AbstractVector{Int}}}
end

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

end
