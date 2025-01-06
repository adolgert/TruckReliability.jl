@enum IndividualState ready working broken

# What I learned:
#
# 1. Enabling transitions is needlessly complicated. We can take the "now, now"
#    arguments and, instead, label a transition as having memory or not having memory.
#
# 2. The transition keys seem to get in the way; could refer to the functions to call.
#    But what happens when you want to cancel a transition?
#
# 3. Maybe the sampler could take care of the time? And the rng?

mutable struct Truck
    ## State for the individual
    state::IndividualState
    work_age::Float64 ## How an individual remembers its total work leading to breaks.
    transition_start::Float64  ## This is bookkeeping.
    ## Parameters for the individual
    done_dist::LogUniform
    break_dist::LogNormal
    repair_dist::Weibull
    Truck(work, fail, repair) = new(
        ready, 0.0, 0.0, work, fail, repair
        )
end


function start_truck(experiment, truck::Truck, sampler)
    now = experiment.time
    rng = experiment.rng
    truck.transition_start = now
    truck.state = working
    enable!(sampler, (truck.id, :done), truck.done_dist, now, now, rng)
    # The failure distribution has memory of being previously enabled.
    past_work = now - individual.work_age
    enable!(sampler, (truck.id, :break), truck.break_dist, past_work, now, rng)
end


function truck_done(experiment, truck, sampler)
    truck.work_age += experiment.time - truck.transition_start
    truck.state = ready
    tell_management(experiment.management, truck.idx, :done)
end


function truck_break(experiment, truck, sampler)
    now = experiment.time
    truck.work_age += now - truck.transition_start
    truck.state = broken
    enable!(sampler, (truck.id, :repair), truck.done_dist, now, now, experiment.rng)
    tell_management(experiment.management, truck.idx, :break)
end


function truck_repaired(experiment, truck)
    truck.state = ready
    tell_management(experiment.management, truck.idx, :repair)
end


mutable struct TruckingManagement
    ## Each day the group tries to start `desired_working` workers.
    desired_working::Int64
    total::Int64
    in_the_field::Int64
    broken::Int64
    TruckingManagement(desired_working, total) = new(desired_working, total, 0, 0)
end


function next_work_time(now, work_day_fraction)
    epsilon = 0.01
    midnight = floor(now)
    day_fraction = now - midnight + epsilon
    if day_fraction < work_day_fraction
        return midnight + day_fraction
    else ## You can't start until tomorrow.
        return midnight + 1.0 + work_day_fraction
    end
end


function start_tomorrow(management, experiment, sampler)
    now = experiment.time
    # Set up the event for tomorrow
    eightam = Dirac(next_work_time(now, work_day_fraction) - now)
    enable!(sampler, (0, :work), eightam, now, now, experiment.rng)
end


function start_the_day(management, experiment, sampler)
    now = experiment.time
    for truck_idx in shuffle(experiment.rng, Vector(1:management.total))
        individual = truck(experiment, truck_idx)
        if individual.state == ready
            start_truck(experiment, truck(experiment, truck_idx), sampler)
            management.in_the_field += 1
            if management.in_the_field == managment.desired_working
                break
            end
        end
    end
    start_tomorrow(management, experiment, sampler)
end


function tell_management(management::TruckingManagement, who, event_kind)
    # Management is unconcerned with `who` broke down.
    if event_kind == :done
        management.in_the_field -= 1
    elseif event_kind == :break
        management.in_the_field -= 1
        management.broken += 1
    elseif event_kind == :repair
        management.broken -= 1
    else
        raise("Cannot recognize event")
    end
end


mutable struct TruckExperiment
    time::Float64
    group::Vector{Truck}
    management::TruckingManagement
    rng::Xoshiro
    Experiment(group::Vector, crew_size::Int, rng) = new(
        0.0,
        group,
        TruckingManagement(crew_size, length(group)),
        rng
        )
end


key_type(::TruckExperiment) = Tuple{Int,Symbol}
worker_cnt(experiment::TruckExperiment) = size(experiment.group, 1);
truck(experiment::TruckExperiment, idx) = experiment.group[idx]

#
# Make a simulation by making individuals.
#
function Experiment(individual_cnt::Int, crew_size::Int, rng)
    done_rate = LogUniform(.8, 0.99) # Gamma(9.0, 0.2)
    break_rate = LogNormal(1.5, 0.4)
    repair_rate = Weibull(1.0, 2.0)
    workers = [Truck(done_rate, break_rate, repair_rate) for _ in 1:individual_cnt]
    Experiment(workers, crew_size, rng)
end


function initial_events(experiment::TruckExperiment, sampler, when)
    start_the_day(experiment.management, experiment, sampler)
end


function fire!(when::Float64, transition_id, experiment::TruckExperiment, sampler)
    experiment.time = when
    who, transition_kind = transition_id
    if who == 0
        start_the_day(experiment.management, experiment, sampler)
    else
        individual = truck(experiment, who)
        if transition_kind == :done
            truck_done(experiment, individual, sampler)
        elseif transition_kind == :break
            truck_break(experiment, individual, sampler)
        elseif transition_kind == :repair
            truck_repair(experiment, individual, sampler)
        end
    end
end
