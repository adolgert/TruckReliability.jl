using CompetingClocks


function run(experiment::TruckExperiment, observation, days)
    sampler = SingleSampler{FirstToFire{key_type(experiment),Float64},Float64}()
    rng = experiment.rng
    when = zero(Float64)
    initial_events(experiment, sampler, when)

    when, which = next(sampler, experiment.time, rng)
    while isfinite(when) && when < days
        ## We use different observers to record the simulation.
        observe(experiment, observation, when, which)
        @debug "$when $which"
        fire!(when, fired_id, experiment, sampler)
        when, which = sample!(sampler, rng)
    end
end
