@doc md"""
Extract epoch data from SSR.

### Optional arguments

* valid_triggers: Trigger numbers that are considered valid ([1,2])
* remove_first: Remove the first n triggers (0).
* remove_last: Remove the last n triggers (0)

### Example

```julia
epochs = extract_epochs(SSR, valid_triggers=[1,2])
```
""" ->
function extract_epochs(a::SSR; valid_triggers::AbstractArray=[1,2], remove_first::Int=0, remove_last::Int=0, kwargs...)

    merge!(a.processing, ["epochs" => extract_epochs(a.data, a.triggers, valid_triggers, remove_first, remove_last)])

    return a
end


function epoch_rejection(a::SSR; cutOff::Number=0.95, kwargs...)

    a.processing["epochs"] = epoch_rejection(a.processing["epochs"], cutOff)

    return a
end


function create_sweeps(a::SSR; epochsPerSweep::Int=64, kwargs...)

    merge!(a.processing, ["sweeps" => create_sweeps(a.processing["epochs"], epochsPerSweep)])

    return a
end





#######################################
#
# Add triggers for more epochs
#
#######################################


function add_triggers(a::SSR; kwargs...)

    debug("Adding triggers to reduce SSR. Using SSR modulation frequency")

    add_triggers(a, float(a.modulation_frequency); kwargs...)
end


function add_triggers(a::SSR, mod_freq::Number; kwargs...)

    debug("Adding triggers to reduce SSR. Using $(mod_freq)Hz")

    epochIndex = DataFrame(Code = a.triggers["Code"], Index = a.triggers["Index"]);
    epochIndex[:Code] = epochIndex[:Code] - 252

    add_triggers(a, mod_freq, epochIndex; kwargs...)
end


function add_triggers(a::SSR, mod_freq::Number, epochIndex; cycle_per_epoch::Int=1, kwargs...)

    info("Adding triggers to reduce SSR. Reducing $(mod_freq)Hz to $cycle_per_epoch cycle(s).")

    # Existing epochs
    existing_epoch_length   = median(diff(epochIndex[:Index]))     # samples
    existing_epoch_length_s = existing_epoch_length / float(a.samplingrate)
    debug("Existing epoch length: $(existing_epoch_length_s)s")

    # New epochs
    new_epoch_length_s = cycle_per_epoch / mod_freq
    new_epochs_num     = round(existing_epoch_length_s / new_epoch_length_s) - 2
    new_epoch_times    = [1:new_epochs_num]*new_epoch_length_s
    new_epoch_indx     = [0, round(new_epoch_times * float(a.samplingrate))]
    debug("New epoch length = $new_epoch_length_s")
    debug("New # epochs     = $new_epochs_num")

    # Place new epoch indices
    debug("Was $(length(epochIndex[:Index])) indices")
    new_indx = epochIndex[:Index][1:end-1] .+ new_epoch_indx'
    new_indx = reshape(new_indx', length(new_indx), 1)[1:end-1]
    debug("Now $(length(new_indx)) indices")

    # Place in dict
    new_code = int(ones(1, length(new_indx))) .+ 252
    a.triggers = ["Index" => vec(int(new_indx)'), "Code" => vec(new_code), "Duration" => ones(length(new_code), 1)']
    #TODO Possible the trigger duration of one is not long enough

    return a
end




#######################################
#
# Rejection channels
#
#######################################

function channel_rejection(a::SSR; kwargs...)

    if haskey(a.processing, "epochs")

        data = reshape(a.processing["epochs"],
                size(a.processing["epochs"], 1) * size(a.processing["epochs"], 2), size(a.processing["epochs"],3))
    else
        data = a.data
    end

    valid = channel_rejection(data, kwargs...)

    info("Rejected $(sum(!valid)) channels $(append_strings(a.channel_names[find(!valid)]))")

    remove_channel!(a, a.channel_names[find(!valid)])

    return a
end