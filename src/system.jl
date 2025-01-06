
function handle_event(when, fired_id, experiment, sampler)
    disable!(sampler, fired_id, when)
    fire!(when, fired_id, experiment, sampler)
end


function run(experiment::TruckExperiment, observation, days)
    sampler = FirstToFire{key_type(experiment),Float64}()
    rng = experiment.rng
    when = zero(Float64)
    initial_events(experiment, sampler, when)

    when, which = next(sampler, experiment.time, rng)
    while isfinite(when) && when < days
        ## We use different observers to record the simulation.
        observe(experiment, observation, when, which)
        @debug "$when $which"
        handle_event(when, which, experiment, sampler)
        when, which = next(sampler, experiment.time, rng)
    end
end
