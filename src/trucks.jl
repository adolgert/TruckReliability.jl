export TruckExperiment, Truck, TruckingManagement

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
    idx::Int64
    ## State for the individual
    state::IndividualState
    ## Parameters for the individual
    done_dist::LogUniform
    break_dist::LogNormal
    repair_dist::Weibull
    Truck(idx, work, fail, repair) = new(
        idx, ready, work, fail, repair
        )
end


function start_truck(experiment, truck::Truck, sampler)
    rng = experiment.rng
    truck.state = working
    # Start the :done and :break transitions at the same time.
    enable!(sampler, (truck_done, truck.idx), truck.done_dist, rng)
    # The failure distribution has memory of being previously enabled.
    enable!(sampler, (truck_break, truck.idx), truck.break_dist, rng; memory=true)
end


function truck_done(experiment, sampler, truck_idx)
    truck = gettruck(experiment, truck_idx)
    truck.state = ready
    # If the truck is done, then it can't break.
    disable!(sampler, (truck_break, truck.idx))
    tell_management(experiment.management, truck.idx, :done)
end


function truck_break(experiment, sampler, truck_idx)
    truck = gettruck(experiment, truck_idx)
    truck.state = broken
    # If the truck :break-ed, then it can't become :done.
    disable!(sampler, (truck_done, truck.idx))
    enable!(sampler, (truck_repair, truck.idx), truck.done_dist, experiment.rng)
    tell_management(experiment.management, truck.idx, :break)
end


function truck_repair(experiment, sampler, truck_idx)
    truck = gettruck(experiment, truck_idx)
    truck.state = ready
    tell_management(experiment.management, truck.idx, :repair)
end


mutable struct TruckingManagement
    ## Each day the group tries to start `desired_working` workers.
    desired_working::Int64
    total::Int64
    in_the_field::Int64
    broken::Int64
    work_day_fraction::Float64
    TruckingManagement(desired_working, total) = new(desired_working, total, 0, 0, 8.0/24.0)
end


function next_work_time(now, work_day_fraction)
    # The epsilon means that if you ask when is the next 8am at 8am, it answers tomorrow.
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
    now = current_time(sampler)
    # Set up the event for tomorrow
    eightam = Dirac(next_work_time(now, management.work_day_fraction) - now)
    enable!(sampler, (start_the_day, 0), eightam, experiment.rng)
end


function start_the_day(experiment, sampler, manager)
    @assert manager == 0
    management = experiment.management
    for truck_idx in shuffle(experiment.rng, Vector(1:management.total))
        individual = gettruck(experiment, truck_idx)
        if individual.state == ready
            start_truck(experiment, gettruck(experiment, truck_idx), sampler)
            management.in_the_field += 1
            if management.in_the_field == management.desired_working
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
    group::Vector{Truck}
    management::TruckingManagement
    rng::Xoshiro
    TruckExperiment(group::Vector, crew_size::Int, rng) = new(
        group,
        TruckingManagement(crew_size, length(group)),
        rng
        )
end

#
# Make a simulation by making individuals.
#
function TruckExperiment(individual_cnt::Int, crew_size::Int, rng)
    done_rate = LogUniform(.8, 0.99) # Gamma(9.0, 0.2)
    break_rate = LogNormal(1.5, 0.4)
    repair_rate = Weibull(1.0, 2.0)
    workers = [Truck(ind, done_rate, break_rate, repair_rate) for ind in 1:individual_cnt]
    TruckExperiment(workers, crew_size, rng)
end


key_type(::TruckExperiment) = Tuple{Function,Int64}
worker_cnt(experiment::TruckExperiment) = size(experiment.group, 1);
gettruck(experiment::TruckExperiment, idx) = experiment.group[idx]


function initial_events(experiment::TruckExperiment, sampler)
    start_the_day(experiment, sampler, 0)
end
