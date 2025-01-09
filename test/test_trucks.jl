using SafeTestsets


@safetestset run_trucks = "call run on the trucks" begin
    using TruckReliability
    using Random

    rng = Xoshiro(928734293487)
    truck_cnt = 15
    crew_size = 10
    experiment = TruckExperiment(truck_cnt, crew_size, rng)

    day_cnt = 10
    observer = TruckReliability.NullObserver()
    run_experiment(experiment, observer, day_cnt)
end
