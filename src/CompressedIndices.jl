module CompressedIndices

import Base: eltype, length, endof, size, checkbounds, eachindex, getindex, start, next, done, push!, append!, intersect, intersect!, +, -
export Indices

AbstractIndices = Union{Int, UnitRange{Int}, Vector{Int}}

immutable Indices <: AbstractVector{Int}
    vectors::Vector{Int}
    ranges::Vector{Int}
    length::Vector{Int}
    isrange::BitVector
end

eltype(I::Indices) = Int
length(I::Indices) = sum(I.length)
endof(I::Indices) = length(I)
size(I::Indices) = (length(I),)
eachindex(I::Indices) = 1:length(I)

start(I::Indices) = (1, 0, 0, 1)
function next(I::Indices, state::NTuple{4, Int})
    @inbounds l = state[1]
    @inbounds vi = state[2]
    @inbounds ri = state[3]
    @inbounds li = state[4]
    @inbounds isrange = I.isrange[li]

    item = 0
    if isrange
        @inbounds item = I.ranges[ri + 1] + l - 1
    else
        @inbounds item = I.vectors[vi + l]
    end

    l += 1
    @inbounds l_li = I.length[li]
    if l > l_li
        if isrange
            ri += 1
        else
            vi += l - 1
        end

        l = 1
        li += 1
    end

    return item, (l, vi, ri, li)
end

done(I::Indices, state::NTuple{4, Int}) = (@inbounds s = state[4] ; s > length(I.length))

function push!(I::Indices, index::Int)
    if length(I.length) == 0
        push!(I.ranges, index)
        push!(I.length, 1)
        push!(I.isrange, true)

        return I
    end

    li = endof(I.length)
    @inbounds isrange = I.isrange[li]

    if isrange
        @inbounds rs = I.ranges[end]
        @inbounds rl = I.length[li]
        if index == rs + rl
            @inbounds I.length[li] += 1
        else
            push!(I.vectors, index)
            push!(I.length, 1)
            push!(I.isrange, false)
        end
    else
        @inbounds vl = I.vectors[end]
        if index == vl + 1
            pop!(I.vectors)
            @inbounds l_li = I.length[li]
            if l_li > 1
                @inbounds I.length[li] -= 1
                push!(I.length, 2)
                push!(I.isrange, true)
            else
                @inbounds I.length[li] += 1
                @inbounds I.isrange[li] = true
            end
            push!(I.ranges, vl)
        else
            push!(I.vectors, index)
            @inbounds I.length[li] += 1
        end
    end

    return I
end

function getindex(I::Indices, index::Int)
    n = 0
    ri = 0
    vi = 0

    for (i, l) in enumerate(I.length)
        @inbounds isrange = I.isrange[i]
        if n + l >= index
            if isrange
                return I.ranges[ri + 1] + (index - n - 1)
            else
                return I.vectors[vi + index - n]
            end
        end

        n += l
        if isrange
            ri += 1
        else
            vi += l
        end
    end

    return 0
end

@generated function Indices(ind::AbstractIndices...)
    length(ind) == 0 && return :(Indices(Vector{Int}(), Vector{Int}(), Vector{Int}(), BitVector()))
    num_ranges = count(x -> x == UnitRange{Int}, ind)
    
    isrange = BitVector([ind[1] == UnitRange{Int}])
    
    for i in 2:endof(ind)
        b = ind[i] == UnitRange{Int}
        if last(isrange) || b
            push!(isrange, b)
        end
    end
    
    ex = Expr[
        :(vectors = Vector{Int}())
        :(ranges = Vector{Int}($num_ranges))
        :(len = Vector{Int}($(length(isrange))))
        :(isrange = BitVector($isrange))
    ]
    
    ri = 0
    oi = 0
    last_isrange = true
    for (i, i_type) in enumerate(ind)
        if i_type == UnitRange{Int}
            ri += 1
            push!(ex, :(ranges[$ri] = first(ind[$i])))
            
            oi += 1
            push!(ex, :(len[$oi] = length(ind[$i])))
            
            last_isrange = true
        elseif i_type == Int
            if last_isrange
                oi += 1
                push!(ex, :(len[$oi] = 1))
                last_isrange = false
            else
                push!(ex, :(len[$oi] += 1))
            end
            
            push!(ex, :(push!(vectors, ind[$i])))
        elseif i_type == Vector{Int}
            if last_isrange
                oi += 1
                push!(ex, :(len[$oi] = length(ind[$i])))
                last_isrange = false
            else
                push!(ex, :(len[$oi] += length(ind[$i])))
            end
            
            push!(ex, :(append!(vectors, ind[$i])))
        else
            throw(ArgumentError("Invalid types in constructor Indices()"))
        end
    end
    
    push!(ex, :(Indices(vectors, ranges, len, isrange)))
    
    return Expr(:block, ex...)
end

end
