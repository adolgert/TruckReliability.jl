import CompetingClocks: FirstToFire, SingleSampler

export run_experiment

mutable struct NullObserver
    called::Int64
    NullObserver() = new(0)
end

observe(experiment, observer::NullObserver, when, which) = (observer.called += 1; nothing)


function run_experiment(experiment, observation, days)
    first_to_fire = FirstToFire{key_type(experiment),Float64}()
    sampler = SingleSampler(first_to_fire)
    facade = SamplerFacade{typeof(sampler),key_type(experiment)}(sampler)
    rng = experiment.rng
    when = zero(Float64)
    initial_events(experiment, facade)

    when, which = sample!(facade, rng)
    while isfinite(when) && when < days
        ## We use different observers to record the simulation.
        observe(experiment, observation, when, which)
        @debug "$when $which"
        action, who = which
        action(experiment, facade, who)
        when, which = sample!(facade, rng)
    end
end
