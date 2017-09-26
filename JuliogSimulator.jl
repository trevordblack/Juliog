WireVal = Union{UInt, UInt8, Array{UInt8}}
# Defining the Wire struct
struct Wire
    val::Array{WireVal}
    BitCount::Int
    Dependents::Array{Any}
    Name::String
end
# TODO change Block struct to contain a string for arithmetic op
# Defining the Block struct
# Known Errors: At present only one output wire is allowed
struct Block
    OutputLocks::Nullable{Array{UInt}}
    Inputs::Array{Wire}
    Outputs::Array{Wire} 
    Arithmetic::Function
    Delays::Nullable{Array{Float64}}
    Name::String
end

# Wire and Block constructors
function Wire(bitcount::Int, dep::Array{Block}, name::String)
    val = Array{WireVal}(1)
    val[] = UInt8('x')
    global blockname
    w = Wire(val, bitcount, dep, blockname * "/" * name)
    push!(BSG.Arrows, w)
    return w
end
function Wire(bitCount::Int, name::String)
    dep = Array{Block}(0)
    Wire(bitCount, dep, name)
end
function Wire()
    val = Array{WireVal}(1)
    val[] = fill(UInt8('x'), 64)
    bitcount = 64
    dep = Array{Block}(0)
    name = ""
    Wire(val, bitcount, dep, name)
end

function Block(ins::Array{Wire}, outs::Array{Wire}, arith::Function, delays::Nullable{Array{Float64}}, name::String)
    if isnull(delays)
        outputlocks = Nullable{Array{UInt}}()
    else
        outputlocks = Array{UInt}(length(outs))
    end
    b = Block(outputlocks, ins, outs, arith, delays, name)
    push!(BSG.Nodes, b)
    return b
end
Block(ins::Array{Wire}, outs::Array{Wire}, arith::Function, delays::Nullable{Array{Float64}}) = Block(ins, outs, arith, delays, blockname)

# Defining the BehavioralSimulationGraph struct
struct BehavioralSimulationGraph
    Nodes::Array{Block}   
    Arrows::Array{Wire}

    Inputs::Array{Wire}
    Outputs::Array{Wire}
end

function prettyprint(bsg::BehavioralSimulationGraph)
    if !isdefined(:wallclock)
        println("No Current Time")
    else
        println("Current time is $(wallclock)s")
    end
    prettyprint.(bsg.Arrows)
    return
end
function prettyprint(w::Wire)
    if isassigned(w.val)
        println("\twire $(w.Name) = $(w.val[]) of type $(typeof(w.val[]))")
    else
        println("\twire $(w.Name) = #undef with type undefined")
    end
end
ppbsg() = prettyprint(BSG)

BSG = BehavioralSimulationGraph(Array{Block}(0), Array{Wire}(0), Array{Wire}(0), Array{Wire}(0))

# overwriting @wire macro
macro wire(name::Symbol, bitcount::Int)
    eval( :($(name) = Wire($(bitcount), $(String(name)) )))
end
macro wire(name::String, bitcount::Int)
    eval( :($(Symbol(name)) = Wire($(bitcount), $(name) )))
end
# overwriting @input macro
macro input(name::Symbol, bitcount::Int)
    extWire = eval(name)
    eval( :($(name) = Wire($(bitcount), $(String(name)) )))
    BITS(eval(name), extWire, bitcount-1, 0)
end
macro input(name::String, bitcount::Int)
    extWire = eval(Symbol(name))
    eval( :($(Symbol(name)) = Wire($(bitcount), $(name) )))
    BITS(eval(Symbol(name)), extWire, bitcount-1, 0) 
end
#overwriting @output macro
macro output(name::Symbol, bitcount::Int)
    extWire = eval(name)
    eval( :($(name) = Wire($(bitcount), $(String(name)) )))
    BITS(extWire, eval(name), bitcount-1, 0)
end
macro output(name::String, bitcount::Int)
    extWire = eval(Symbol(name))
    eval( :($(Symbol(name)) = Wire($(bitcount), $(name) )))
    BITS(extWire, eval(Symbol(name)), bitcount-1, 0) 
end


function wire(name::String, bitcount::Int)
    esc( eval(:($(Symbol(name)) = Wire($(bitcount), $(name) ))))
end
function input(name::String, bitcount::Int)
    extWire = eval(Symbol(name))
    esc( eval(:($(Symbol(name)) = Wire($(bitcount), $(name) ))))
    BITS(eval(Symbol(name)), extWire, bitcount-1, 0) 
end
function output(name::String, bitcount::Int)
    extWire = eval(Symbol(name))
    esc( eval(:($(Symbol(name)) = Wire($(bitcount), $(name) ))))
    BITS(extWire, eval(Symbol(name)), bitcount-1, 0) 
end


macro monitor(name::Symbol)
    MONITOR(eval(name))
end
macro monitor(name::String)
    if name[1] != "/"
        name = "/" * name
    end
    l = length(BSG.Arrows)
    for i = 1:l
        w = BSG.Arrows[i]
        if w.Name == name
            MONITOR(w)
            return
        end
    end
end

macro compile(sym::Symbol, name::String)
    # Convert Juliog to JLG
    global blockname
    prev_blockname = blockname 
    global blockname = blockname * "/" * name
    eval(eval(sym))
    global blockname = prev_blockname    
end

global blockname = ""
macro block(name::String, ex::Expr)
    global blockname
    prev_blockname = blockname 
    global blockname = blockname * "/" * name
    eval(ex)
    global blockname = prev_blockname
end

struct FullProcess
    block::Block
    wallclock::Float64
end
struct BlockProcess
    block::Block
    outwire::Wire
    wallclock::Float64
end
struct ValueProcess
    wire::Wire
    val::WireVal
    wallclock::Float64
end


# Initializing the process_stack
ProcessUnion = Union{FullProcess, BlockProcess, ValueProcess}
pstack = Array{ProcessUnion}(0) # p(rocess)stack

# pretty print process stack
function ppps()
    println("In-Order printing of Process Stack:")
    for p in pstack
        if isa(p, FullProcess)
            println("\t$(p.wallclock): Full Process  ... $(p.block.Name)")
        elseif isa(p, BlockProcess)
            println("\t$(p.wallclock): Block Process ... $(p.block.Name) , in -> $(p.inwire) , out -> $(p.outwire)")
        elseif isa(p, ValueProcess)
            println("\t$(p.wallclock): Value Process ... $(p.wire.Name) -> $(p.val)")
        else
            error("Process $(p) in process stack is NOT a process!")
        end
    end
end


function add_samples(; offset = 0.0 , sample_rate = 1e-12, samples = Array{UInt8}(0), wire::Wire = nothing)
    if !in(wire , BSG.Inputs)
        push!(BSG.Inputs, wire)
    end
    
    s = length(samples)
    input_ps = Array{ValueProcess}(s)
    for i = 1:s
        sample_val = samples[i]
        if sample_val == 'x'
            sample_val = UInt8('x')
        elseif sample_val == 'z'
            sample_val = UInt8('z')
        elseif sample_val < 0
            sample_val = UInt(sample_val >>> (64 - wire.BitCount))
        elseif isa(sample_val, Float64)

        elseif isa(sample_val, Float32)

        else
            sample_val = UInt(sample_val)
        end

        input_ps[i]  = ValueProcess(wire, sample_val , (i-1)*sample_rate + offset)
    end    
    append!(pstack, input_ps)
end

# inserts at the end of the next processes
function InsertProcessEndConcurrent!(P)
    clock = P.wallclock

    l = length(pstack)

    for i = 1:l
        if(clock < pstack[i].wallclock)
            insert!(pstack, i, P)
            return
        end
    end
    push!(pstack, P)
end

function InsertProcess!(P)
    clock = P.wallclock

    global pstack
    l = length(pstack)

    for i = 1:l
        if(clock <= pstack[i].wallclock)
            insert!(pstack, i, P)
            return
        end
    end
    push!(pstack, P)
end

function next()
    global pstack
    if length(pstack) == 0
        println("\nNo more samples, Simulation has already completed")
    else
        # a) Change the current time
        #        This assumes pstack is sorted with next at index 1
        current_time = pstack[1].wallclock

        # b) Take only the top process off of pstack
        nextp = pstack[1]
        pstack = pstack[2:end]

        # c) If nextp is a full process
        if isa(nextp, FullProcess)
            println("\nStarting a Full Process")
            bloc = nextp.block
            out_val = bloc.Arithmetic()
            println("\tNew Value is $(out_val)")
            println("\tDriving to $(bloc.Outputs[].Name)")
            vp = ValueProcess(bloc.Outputs[], out_val, current_time)
            println("Inserting...")
            InsertProcessEndConcurrent!(vp)
            println()
        # d) nextp is a block process
        elseif isa(nextp, BlockProcess)
            bloc = nextp.block
            # TODO finish this

            error("Next Process is a Block Process, BP implementation incomplete")

        # e) nextp is a value process
        else
            println("\nStarting a Value Process")
            w = nextp.wire
            if nextp.val != w.val
                w.val[] = nextp.val
                dep_blocks = w.Dependents
                d = length(dep_blocks)
                for i = 1:d
                    dep_block = dep_blocks[i]
                    if isnull(dep_block.Delays)
                        InsertProcessEndConcurrent!(FullProcess(dep_block, current_time))
                    else
                        # TODO finish this
                        error("Value Process attempting to produce a Block Progress")
                    end
                end
            end
            println("Value Process Complete")
        end

        global wallclock = current_time
    end
    println("Updated Results:")
    ppbsg()
    ppps()
end

# At least for now, the assigned name of a HW function does not matter
macro simulate()
    global pstack

    # Sort the pstack because add_samples is done nonchronilogically
    pstack = sort(pstack, by=(x)->(x.wallclock))    

    # complete the rest of the simulation
    while length(pstack) != 0

        # a) Change the current time
        #       This assumes process_stack is sorted with next at index 1
        current_time = pstack[1].wallclock
        global wallclock = current_time

        # b) Check for Next processes to compute (all must be at same time)         
        l = length(pstack)
        i = 2      
        while i <= l && current_time == pstack[i].wallclock
            i = i+1
        end

        # c) Collect Next processes        
        current_stack = pstack[1:i-1]
        pstack = pstack[i:end]

        # d) Remove duplicate Next Processes (if they exist)
        #    a duplicate is multiple FullProcess or BlockProcess calls to a single block
        #current_stack = unique(current_stack)
        # uniquing will fuck up outputlock count

        # e) Partition Next Processes by process type
        vc = 0
        fc = 0
        bc = 0        
        l = length(current_stack)
        for i = 1:l
            p = current_stack[i]
            if isa(p, ValueProcess)
                vc = vc + 1
            elseif isa(p, BlockProcess)
                bc = bc + 1
            else
                fc = fc + 1
            end
        end
        vi = 1
        fi = 1
        bi = 1
        value_stack = Array{ValueProcess}(vc)
        full_stack  = Array{FullProcess}(fc)
        block_stack = Array{BlockProcess}(bc)
        for i = 1:l
            p = current_stack[i]
            if isa(p, ValueProcess)
                value_stack[vi] = p
                vi = vi + 1
            elseif isa(p, BlockProcess)
                block_stack[bi] = p
                bi = bi + 1
            else
                full_stack[fi] = p
                fi = fi + 1
            end
        end

        # f) Run Full Processes (if they exist)
        # If is a Full Process
        #   Add value processes for all wires into value_stack
        l = length(full_stack)
        for i = 1:l
            bloc = full_stack[i].block
            out_val = bloc.Arithmetic()                
            o = length(bloc.Outputs)
            if o != 1
                for j = 1:o
                    vp = ValueProcess.(bloc.Outputs[j], out_val[j], current_time)
                    push!(value_stack, vp)
                end
            else
                vp = ValueProcess.(bloc.Outputs[], out_val, current_time)
                push!(value_stack, vp)
            end
        end

        # g) Run Block Processes (if they exist)
        # If is a Block Process
        #   decrease the outputlocks for the outwire output for that block 
        #   if any output lock = 0
        #       solve for values
        #       add ValueProcess for outwire into value_stack
        l = length(block_stack)
        for i = 1:l
            bp = block_stack[i]
            bloc = bp.block
            j = 1
            o = length(bloc.Outputs)
            out = bp.outwire
            while j < o
                if bloc.Outputs[j] === out
                    break
                end
                j = j + 1
            end
            bloc.OutputLocks[j] -= 1

            if bloc.OutputLocks[j] > 0
                vp = ValueProcess(out, UInt8('x'), current_time)
            else
                out_val = bloc.Arithmetic()
                o = length(bloc.Outputs)
                if o != 1
                    for j = 1:o
                        vp = ValueProcess.(bloc.Outputs[j], out_val[j], current_time)
                        push!(value_stack, vp)
                    end
                else
                    vp = ValueProcess.(bloc.Outputs[], out_val, current_time)
                    push!(value_stack, vp)
                end
            end
        end

        # h) Run Value Processes (if they exist)
        l = length(value_stack)
        for i = 1:l        
            vp = value_stack[i]
            w = vp.wire
            if vp.val != w.val[]
                w.val[] = vp.val
                dep_blocks = w.Dependents
                d = length(dep_blocks)
                for j = 1:d
                    dep_block = dep_blocks[i]
                    if isnull(dep_block.Delays)
                        InsertProcess!(FullProcess(dep_block, current_time))
                    else
                        di = length(dep_block.Inputs)
                        col = 1
                        while col < di
                            if dep_block.Inputs[col] === w
                                break
                            end
                            col = col + 1
                        end


                        for row = 1:length(dep_block.Outputs)                            outwire = dep_block.Outputs[row]
                            outwire = dep_block.Outputs[row]

                            # Change Output values to don't cares (if applicable)
                            # so they can be properly updated later
                            vp = ValueProcess(outwire, UInt8('x'), current_time)
                            push!(value_stack, vp)
                            l = l + 1

                            delay = dep_block.delays[col * row]
                            InsertProcess!(BlockProcess(dep_block, outwire, current_time + delay))
                        end

                    end
                end
            end
        end



    end
    println("Simulation completed")
end
