using Distributions
using Random
import Distributions: params, partype, mean, median, mode, var, skewness, kurtosis
import Distributions: pdf, logpdf, cdf, ccdf, quantile, mgf, cf
import Base: rand
import Random: rand!

struct DiracDelta{T<:Real} <: ContinuousUnivariateDistribution
    value::T
    DiracDelta{T}(value) where {T <: Real} = new{T}(value)
end

DiracDelta(value) = DiracDelta{Float64}(value)

params(d::DiracDelta) = d.value
partype(d::DiracDelta{T}) where {T<:Real} = T
mean(d::DiracDelta{T}) where {T} = d.value
median(d::DiracDelta{T}) where {T}= d.value
mode(d::DiracDelta{T}) where {T} = d.value
var(d::DiracDelta{T}) where {T} = zero(T)
skewness(d::DiracDelta{T}) where {T<:Real} = zero(T)
kurtosis(d::DiracDelta{T}) where {T<:Real} = zero(T)
pdf(d::DiracDelta{T}, x::Real) where {T<:Real} = zero(T)
logpdf(d::DiracDelta{T}, x::Real) where {T<:Real} = typemin(T)
cdf(d::DiracDelta{T}, x::Real) where {T<:Real} = (x < d.value) ? zero(T) : one(T)
ccdf(d::DiracDelta{T}, x::Real) where {T<:Real} = (x < d.value) ? one(T) : zero(T)
quantile(d::DiracDelta{T}, q::Real) where {T<:Real} = typemax(T)
mgf(d::DiracDelta{T}, x::Real) where {T<:Real} = zero(x)
cf(d::DiracDelta{T}, x::Real) where {T<:Real} = zero(x)
rand(rng::Random.AbstractRNG, d::DiracDelta) = d.value

function rand!(rng::Random.AbstractRNG, d::DiracDelta, arr::AbstractArray)
    arr .= d.value
end
