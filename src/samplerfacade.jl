using CompetingClocks


struct MemoryTrack
    consumed_duration::Float64
    last_started::Float64
end
MemoryTrack() = MemoryTrack(zero(Float64), zero(Float64))


struct SamplerFacade{S,key}
    sampler::S
    memorized::Dict{key,Float64}
end


function enable!(
    facade::SamplerFacade{SingleSampler},
    clock,
    distribution::UnivariateDistribution,
    rng::AbstractRNG;
    memory=false
    )
    te = facade.sampler.when
    if memory
        track = get(facade.memorized, clock, MemoryTrack())
        te -= track.consumed_duration
        facade.memorized[clock] = MemoryTrack(track.consumed_duration, facade.sampler.when)
    else
        if clock ∈ keys(facade.memorized)
            remove!(facade.memorized, clock)
        end
    end
    return enable!(facade.sampler, clock, distribution, te, rng)
end


function disable!(facade::SamplerFacade, clock)
    if clock ∈ keys(facade.memorized)
        track = facade.memorized[clock]
        consumed = track.consumed_duration + facade.sampler.now - track.last_started
        facade.memorized[clock] = MemoryTrack(consumed, Inf64)
    end
    return disable!(facade.sampler.propagator, clock)
end


function sample!(facade::SamplerFacade, rng::AbstractRNG)
    when, transition = sample!(facade.sampler, rng)
    if transition ∈ keys(facade.memorized[clock])
        remove!(facade.memorized, clock)
    end
    return (when, transition)
end
