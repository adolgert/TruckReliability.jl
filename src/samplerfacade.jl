import CompetingClocks


struct MemoryTrack
    consumed_duration::Float64
    last_started::Float64
end
MemoryTrack() = MemoryTrack(zero(Float64), zero(Float64))


struct SamplerFacade{S,key}
    sampler::S
    memorized::Dict{key,MemoryTrack}
    SamplerFacade{S,key}(sampler) where {S,key} = new(sampler, Dict{key,MemoryTrack}())
end


current_time(s::SamplerFacade) = s.sampler.when


function enable!(
    facade::SamplerFacade,
    clock,
    distribution,
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
            delete!(facade.memorized, clock)
        end
    end
    return CompetingClocks.enable!(facade.sampler, clock, distribution, te, rng)
end


function disable!(facade::SamplerFacade, clock)
    if clock ∈ keys(facade.memorized)
        track = facade.memorized[clock]
        consumed = track.consumed_duration + facade.sampler.when - track.last_started
        facade.memorized[clock] = MemoryTrack(consumed, Inf64)
    end
    return CompetingClocks.disable!(facade.sampler, clock)
end


function sample!(facade::SamplerFacade, rng::AbstractRNG)
    when, transition = CompetingClocks.sample!(facade.sampler, rng)
    if transition ∈ keys(facade.memorized)
        delete!(facade.memorized, transition)
    end
    return (when, transition)
end
