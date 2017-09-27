# ex is a hardware function block
# passedArguments is the passed Tuple which represents its arguments
function parameterize(ex::Expr, passedArgs::Expr)
    jexpr = Expr(:function)
    jargs = Array{Any}(2)

    funcArgs = ex.args[1]
    # Resolve the keyword parameters
    if isa(funcArgs.args[2], Expr) && funcArgs.args[2].head == :parameters
        # The funcArgs[2] arguments must be keywords
        l = length(funcArgs.args[2].args)
        pkArgs = passedArgs.args[1]
        if isa(pkArgs, Expr) && pkArgs.head == :parameters
            m = length(pkArgs.args)
            for i = 1:l
                keywordSymbol = funcArgs.args[2].args[i].args[1]
                keywordValue = funcArgs.args[2].args[i].args[2]
                for j = 1:m
                    if keywordSymbol == pkArgs.args[j].args[1]
                        keywordValue = pkArgs.args[j].args[2]
                        break
                    end
                end
                eval( :($(keywordSymbol) = $(keywordValue)) )
            end
        else
            for i = 1:l
                keywordSymbol = funcArgs.args[2].args[i].args[1]
                keywordValue = funcArgs.args[2].args[i].args[2]
                eval( :($(keywordSymbol) = $(keywordValue)) )
            end          
        end

        # Remove the keywords
        jargs[1] = [funcArgs.args[1] ; funcArgs.args[3:end]]
    else
        jargs[1] = funcArgs
    end

    global wireSymArray = Array{Symbol}(0)
    # parameterize the expression block
    #  now with complete keyword information
    jargs[2] = JPblock(ex.args[2])

    jexpr.args = jargs
    return jexpr
end

function JPblock(ex::Expr)
    l = length(ex.args)
    for i = 1:l
        arg = ex.args[i]
        if     isa(arg, Expr)
            ex.args[i] = JPblockhelper(arg)
        elseif isa(arg, Symbol) && isdefined(arg)
            ex.args[i] = eval(arg)
        end
    end 
    # scrub out the nothing(s)
    l = length(ex.args)
    i = 1
    while i <= l
        arg = ex.args[i]
        if arg === nothing
            deleteat!(ex.args, i)
            l = l - 1
        else
            i = i + 1
        end
    end
    # raise the blocks
    i = 1
    while i <= length(ex.args)
        arg = ex.args[i]
        if isa(arg, Expr) && arg.head == :block
            index = i
            args_ref = arg.args
            ar = length(args_ref)
            for j = 1:ar
                insert!(ex.args, index, args_ref[j])
                index = index + 1
            end
            deleteat!(ex.args, index)
        else
            i = i + 1
        end
    end

    return ex
end

function JPblockhelper(ex::Expr)
    h = ex.head
    if     h == :(=)
        return JPequals(ex)
    elseif h == :(:=)
        return JPassignment(ex)
    elseif h == :const
        return JPconst(ex)
    elseif h == :global
        if isa(ex.args[1], Expr)
            error("global expressions are not supported.")
        end
        eval(ex)
        return nothing
    elseif h == :import
        eval(ex)
        return nothing
    elseif h == :macrocall
        return JPmacro(ex)
    elseif h == :if 
        return JPif(ex)
    elseif h == :for
        return JPfor(ex)
    elseif h == :while 
        error("hit unfinished block: $(h)")
    else
        error("hit unexpected expr head $(h) in JPblockhelper:\n$(ex)")
    end
end

function JPequals(ex::Expr)
    global wireSymArray
    assn = ex.args[2]
    if     isa(assn, Expr)
        ex.args[2] = JPrhs(assn)
    elseif isa(assn, Symbol) && isdefined(assn)
        ex.args[2] = eval(assn)
    end

    if isa(ex.args[1], Expr)
        ex.args[1] = JPlhs(ex.args[1])
    else
        if isa(assn ,Expr) && JPwiredec(assn)
            push!(wireSymArray, ex.args[1])
        end
        if !isa(ex.args[2], Symbol) && !isa(ex.args[2], Expr) && !in(ex.args[1], wireSymArray)
            eval(ex)
            return nothing
        elseif isa(ex.args[2], Expr) && isevaluable(ex.args[2]) && !in(ex.args[1], wireSymArray)
            eval(ex)
            return nothing
        end
    end
    return ex
end

function JPassignment(ex::Expr)
    assn = ex.args[2]
    if     isa(assn, Expr)
        ex.args[2] = JPrhs(assn)
    elseif isa(assn, Symbol) && isdefined(assn)
        ex.args[2] = eval(assn)
    end

    if isa(ex.args[1], Expr)
        ex.args[1] = JPlhs(ex.args[1])
    end
    return ex
end

function JPconst(ex::Expr)
    assn = ex.args[1].args[2]
    if     isa(assn, Expr)
        ex.args[1].args[2] = JPrhs(assn)
    elseif isa(assn, Symbol) && isdefined(assn)
        ex.args[1].args[2] = eval(assn)
    end
    if isevaluable(ex.args[1].args[2])
        eval(ex)
        return nothing
    end
    return ex
end

function JPrhs(ex::Expr)
    h = ex.head
    if     h == :call 
        return JPcall(ex)
    elseif h == :vcat
        return JPvcat(ex)  
    elseif h == :ref
        return JPref(ex)
    elseif h == :if 
        return JPif(ex)
    else
        error("Hit unexpected expression symbol $(h) in JPrhs on expression:\n$(ex)")
    end
end

function JPlhs(ex::Expr)
    h = ex.head
    if     h == :call 
        return JPcall(ex)  
    elseif h == :ref
        return JPref(ex)
    elseif h == :vcat
        return JPvcat(ex)
    elseif h == :tuple
        return JPtuple(ex)
    else
        error("Hit unexpected expression symbol $(h) in JPlhs on expression:\n$(ex)")
    end    
end

function JPcall(ex::Expr)
    if ex.args[1] != :(<=)
        # Is not a Non-Blocking operator
        l = length(ex.args)
        for i = 1:l
            arg = ex.args[i]
            if     isa(arg, Expr)
                ex.args[i] = JPcallhelper(arg)
            # move to check for module i.e. main
            elseif isa(arg, Symbol) && isdefined(arg)
                ex.args[i] = eval(arg)
            end
        end 
        if isevaluable(ex)
            return eval(ex)
        end
        return ex   
    else
        # Definitely a Non-Blocking operator    
        assn = ex.args[3]
        if     isa(assn, Expr)
            ex.args[3] = JPrhs(assn)
        elseif isa(assn, Symbol) && isdefined(assn)
            ex.args[3] = eval(assn)
        end

        if isa(ex.args[2], Expr)
            ex.args[2] = JPlhs(ex.args[1])
        end
        return ex
    end
end

function JPcallhelper(ex::Expr)
    h = ex.head
    if     h == :call 
        return JPcall(ex)
    elseif h == :vcat
        return JPvcat(ex)  
    elseif h == :ref
        return JPref(ex)
    elseif h == :if 
        return JPif(ex)
    else
        error("Hit unexpected expression symbol $(h) in JPcall on expression:\n$(ex)")
    end   
end



function JPvcat(ex::Expr)
    l = length(ex.args)
    for i = 1:l
        arg = ex.args[i]
        if     isa(arg, Expr)
            ex.args[i] = JPvcathelper(arg)
        # move to check for module i.e. main
        elseif isa(arg, Symbol) && isdefined(arg)
            ex.args[i] = eval(arg)
        end
    end 
    if isevaluable(ex)
        return eval(ex)
    end
    return ex   
end

# MOON vcats in vcats set up busses, matrices
function JPvcathelper(ex::Expr)
    h = ex.head
    if     h == :call 
        return JPcall(ex)
    elseif h == :vcat
        return JPvcat(ex)  
    elseif h == :ref
        return JPref(ex)
    else
        error("Hit unexpected expression symbol $(h) in JPvcat on expression:\n$(ex)")
    end
end

# MOON Confirm Matrix and Verilog notation operation
function JPref(ex::Expr)
    l = length(ex.args)
    for i = 1:l
        arg = ex.args[i]
        if isa(arg, Expr)
            ex.args[i] = JPrefhelper(arg)
        elseif isa(arg, Symbol) && isdefined(arg)
            ex.args[i] = eval(arg)
        end
    end
    if isa(ex.args[1], Symbol) && isdefined(ex.args[1]) && JPrefevaluable(ex)
        eval(ex)
        return ex
    end
    return ex
end

function JPrefhelper(ex::Expr)
    if     ex.head == :ref || ex.head == :(:)
        l = length(ex.args)
        for i = 1:l
            arg = ex.args[i]
            if     isa(arg, Expr)
                ex.args[i] = JPrefhelper(arg)                
            elseif isa(arg, Symbol) && isdefined(arg)
                ex.args[i] = eval(arg)
            end
        end
        return ex
    elseif ex.head == :call
        return JPcall(ex)
    else
        error("Hit an unexpected expr head in JPrefhelper:\n$(ex)")
    end 
end

function JPrefevaluable(ex::Expr)
    l = length(ex.args)
    for i = 1:l
        if isa(ex.args[i], Expr) && ex.args[i].head == :ref
            return false
        end
        if JPrefevaluable(ex.args[i]) == false
            return false
        end
    end
    return true
end

function JPif(ex::Expr)
    if isa(ex.args[1], Expr)
        if     ex.args[1].head == :ref
            ex.args[1] = JPref(ex.args[1])
        elseif ex.args[1].head == :call
            ex.args[1] = JPcall(ex.args[1])
        else
            error("Incorrect if condition syntax:\n$(ex)")
        end
    end

    condition = ex.args[1]
    if isa(condition, Bool)
        if condition
            arg = ex.args[2]
            if     isa(arg, Expr) 
                return JPreduce(arg)
            elseif isa(arg, Symbol) && isdefined(arg)
                return eval(arg)
            else
                return arg
            end
        else
            if length(ex.args) == 3
                arg = ex.args[3]
                if     isa(arg, Expr)
                    return JPreduce(arg)
                elseif isa(arg, Symbol) && isdefined(arg)
                    return eval(arg)
                else
                    return arg
                end
            else
                return nothing
            end
        end
    else
        if     isa(ex.args[2], Expr)
            ex.args[2] = JPreduce(ex.args[2])
        elseif isa(ex.args[2], Symbol) && isdefined(ex.args[2])
            ex.args[2] = eval(ex.args[2])
        end
        if length(ex.args) == 3
            if     isa(ex.args[3], Expr)
                ex.args[3] = JPreduce(ex.args[3])
            elseif isa(ex.args[3], Symbol) && isdefined(ex.args[3])
                ex.args[3] = eval(ex.args[3])
            end
        end

        return ex
    end
end

function JPreduce(ex::Expr)
    h = ex.head
    if     h == :call 
        return JPcall(ex)
    elseif h == :vcat
        return JPvcat(ex)  
    elseif h == :ref
        return JPref(ex)
    elseif h == :if 
        return JPif(ex)
    elseif h == :block
        return JPblock(ex)
    else
        error("Hit unexpected expression symbol $(h) in JPreduce on expression:\n$(ex)")
    end
end

function JPfor(ex::Expr)
    h = ex.args[1].args[2].head
    if     h == :(:)
        return JPforcolon(ex)
    elseif h == :hcat
        return JPforarray(ex)
        warn("hcat functionality not guaranteed in JPfor on expression:\n$(ex)")
    elseif h == :vcat
        return JPforarray(ex)
        warn("vcat functionality not guaranteed in JPfor on expression:\n$(ex)")
    elseif h == :vect
        return JPforarray(ex)
        warn("vect functionality not guaranteed in JPfor on expression:\n$(ex)")
    else
        error("Hit unexpected expression symbol $(h) in JPfor on expression:\n$(ex)")
    end
end

function JPforcolon(ex::Expr)
    subex = ex.args[1].args[2]
    # subex represents the looping condition
    l = length(subex.args)
    for i = 1:l
        arg = subex.args[i]
        if     isa(arg, Expr)
            ex.args[1].args[2].args[i] = JPreduce(arg)
        elseif isa(arg, Symbol) && isdefined(arg)
            ex.args[1].args[2].args[i] = eval(arg)
        end
    end       

    l = length(subex.args)
    if isevaluable(subex)
        if l == 2 && subex.args[1] > subex.args[2]
            warn("Skipping over for loop due to negative order")
        end
        ex.args[1].args[2] = eval(subex)
    end

    loop = ex.args[1].args[2]
    sym = ex.args[1].args[1]
    block_arguments = Array{Any}(0)
    for i = loop
        arg_copy = copy(ex.args[2])
        overwrite = :($sym = $i)
        eval(overwrite)
        arg_copy = JPblock(arg_copy)
        append!(block_arguments, arg_copy.args)
    end
    new_ex = Expr(:block)
    new_ex.args = block_arguments
    return new_ex
end

function JPforarray(ex::Expr)
    subex = ex.args[1].args[2]
    # subex represents the looping condition
    l = length(subex.args)
    for i = 1:l
        arg = subex.args[i]
        if     isa(arg, Expr)
            ex.args[1].args[2].args[i] = JPreduce(arg)
        elseif isa(arg, Symbol) && isdefined(arg)
            ex.args[1].args[2].args[i] = eval(arg)
        end
    end       

    loop = ex.args[1].args[2]
    sym = ex.args[1].args[1]
    block_arguments = Array{Any}(0)
    for i = loop
        arg_copy = copy(ex.args[2])
        overwrite = :($sym = $i)
        eval(overwrite)
        arg_copy = JPblock(arg_copy)
        append!(block_arguments, arg_copy.args)
    end
    new_ex = Expr(:block)
    new_ex.args = block_arguments
    return new_ex
end

function JPmacro(ex::Expr)
    if ex.args[1] == Symbol("@block")
        if isa(ex.args[3] , Expr)
            ex.args[3] = eval(ex.args[3])
        end

        if isa(ex.args[4], Expr)
            # This should always be the case
            #  because a function needs more than one argument
            l = length(ex.args[4].args)
            for i = 1:l
                arg = ex.args[4].args[i]
                if isa(arg, Expr)
                    ex.args[4].args[i] = JPreduce(arg)
                end
            end
        end

        eval(ex)
        return ex
    else
        # Any other macro calls
        l = length(ex.args)
        for i = 2:l
            arg = ex.args[i]
            if isa(arg, Expr)
                ex.args[i] = JPreduce(arg)
            end
        end
        return ex
    end    
end

function JPwiredec(ex::Expr)
    if     ex.head == :call
        if length(ex.args) == 1
            arg = ex.args[1]
            return (arg == :Wire) || (arg == :Input) || (arg == :Output)
        else
            return false
        end
    elseif ex.head == :ref
        if isa(ex.args[1], Expr)
            return JPwiredec(ex.args[1])
        end
    end
    return false
end


function isevaluable(ex::Expr)
    for arg in ex.args
        if isa(arg, Symbol) && !isdefined(arg)
            return false
        elseif isa(arg, Expr)
            return false
        end
    end

    return true
end