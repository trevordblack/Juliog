
function JSif(ex::Expr)    
    # The if statement is outside of a macro, so it gets turned into a mux to verilog
    # The wires are not turned into regs
    jexpr = Expr(:Block)

    # Convert Juliog conditions to JIR if necessary
    ex = JSifconds(ex)

    # Recursively solve for nested if assignments    
    jargs = JSifblock(ex)

    l = length(jargs)
    for i = 1:l
        jargs[i] = JSblockhelper(jarg[i])
    end

    jexpr.args = jargs
    return jexpr
end

function JSifconds(ex::Expr)
    if !isa(ex.args[1], Expr)
        error("Condition for if statement is not an expr:\n$(ex)")
    end   

    # Convert top level condition
    ex.args[1] = JSifcond(ex.args[1])

    # Plunge into if block, convert any nested conditions
    for i = 1:length(ex.args[2].args)
        arg = ex.args[2].args[i]
        if isa(arg, Expr) && arg.head == :if
            ex.args[2].args[i] = JSifconds(arg)
        end
    end

    # Plunge into else block, if it exists, convert any nested conditions
    if length(ex.args) == 3
        for i = 1:length(ex.args[3].args)
            arg = ex.args[3].args[i]
            if isa(arg, Expr) && arg.head == :if
                ex.args[3].args[i] = JSifconds(arg)
            end
        end
    end

    return ex
end

function JSifcond(ex::Expr)
    global arrowDict

    # Check for warnings in condition syntax
    JSrhscall(ex)

    if     ex.args[3] == 1 || ex.args[3] == 0
        if     isa(ex.args[2], Symbol)
            bc = arrowDict[ex.args[2]].BitCount
        elseif isa(ex.args[2], Expr)
            # MOON Right here solve matrix notation and swap ex.args[2] to it
            bc,endi = JSreadrhs(ex.args[2])
        end

        if bc == 1
            if     ex.args[3] == 1
                return ex.args[2]
            elseif ex.args[3] == 0
                return [:~ ; ex.args[2]]
            end
        else
            error("Condition of if statement does not equal 1 bit:\n$(ex)")
        end
    elseif ex.args[2] == 1 || ex.args[2] == 0
        if     isa(ex.args[3], Symbol)
            bc = arrowDict[ex.args[3]].BitCount
        elseif isa(ex.args[3], Expr)
            # MOON Right here solve matrix notation and swap ex.args[2] to it
            bc,endi = JSreadrhs(ex.args[3])
        end

        if bc == 1
            if     ex.args[2] == 1
                return ex.args[3]
            elseif ex.args[2] == 0
                return [:~ ; ex.args[3]]
            end
        else
            error("Condition of if statement does not equal 1 bit:\n$(ex)")
        end
    end

    # Can't be reduced to a single wire, so just return as is
    return ex
end







# TODO from here on needs touching up

mutable struct ifArrow
    Endian::Int
        # 0 -> Undeclared
        # 1 -> Big Endian
        # 2 -> Little Endian
    BitLeft::Int
    BitRight::Int
    BitCount::Int
    Assigned::Int
        # 0 -> Unassigned
        # 1 -> Assigned
        # 2 -> Bitwise Assigned
    AsgnArray::Array{Int}
end

function JSifblock(ex::Expr)
    elseargs = Array{Any}(0)
    condition = ex.args[1]

    l = length(ex.args)
    if l == 3 
        ifArrowDict = Dict{Symbol, ifArrow}()
        elseArrowDict = Dict{Symbol, ifArrow}()
        ifargs = Array{Any}(0)
        l = length(ex.args[2].args)
        for i = 1:l
            arg = ex.args[2].args[i]
            h = arg.head
            if     h == :(=)
                JSifblockequals(arg, ifArrowDict)
                push!(ifargs, arg)
            elseif h == :if
                args = JSifblock(arg)
                append!(ifargs, args)
            else
                error("Found incorrect expr head $(h) in if expr:\n$(ex)")                
            end
        end  
        
        l = length(ex.args[3].args)
        for i = 1:l                
            arg = ex.args[3].args[i]
            h = arg.head
            if     h == :(=)
                JSifblockequals(arg, elseargs)
                push!(elseargs, arg)
            elseif h == :if
                args = JSifblock(arg)
                append!(elseargs, args)
            else
                error("Found incorrect expr head $(h) in if expr:\n$(ex)")                
            end
        end   

        # TODO this for loop
        # compare ifargs against elseargs
        l = length(ifargs)
        m = length(elseargs)
        for i = 1:l
            lhs = ifargs[i].args[1]
            if isa(lhs, Expr)
                # MOON matrix notation
                name = lhs.args[1]
            else
                # Is a symbol
                name = lhs
            end


            jarg = jargs[j]
            jargs[j].args[2] = Expr(:if, condition, jarg.args[2], jarg.args[1])
        end

        append!(jargs, ifargs)
        ex.args[2].args[i] = jexpr 


    else
        l = length(ex.args[2].args)
        for i = 1:l
            arg = ex.args[2].args[i]
            h = arg.head
            if     h == :(=)
                JSifequals(arg)
                push!(elseargs, arg)
            elseif h == :if
                append!(elseargs, JSifblock(arg))
            else
                error("Found incorrect expr head $(h) in if expr:\n$(ex)")                
            end
        end
        l = length(elseargs)
        for i = 1:l
            arg = elseargs[i]
            elseargs[i].args[2] = Expr(:if, condition, arg.args[2], arg.args[1])
            warn("Latch of expr $(elseargs[i].args[2]) created in if expr:\n$(ex)")
        end
        return elseargs
    end 
end


function JSifblockequals(ex::Expr, ifAD::Dict{Symbol, ifArrow})
    # Check rhs correctness
    bcrhs, endirhs = JSrhs(ex.args[2])

    # check lhs correctness
    if isa(ex.args[1], Expr)
        # lhs is a reference
        JSifblockequalsref(ifAD, ex, bcrhs, endirhs)
    else
        # lhs is just a symbol for a wire
        JSifblockequalssymbol(ifAD, ex, bcrhs, endirhs)
    end    
end

function JSifblockequalsref(ifAD::Dict{Symbol, ifArrow}, ex::Expr, bcrhs::Int, endirhs::Int)
    # LHS is a reference
    #   Maybe a vcat or tuple, can't do anything about that yet
    name = ex.args[1].args[1]

    # Check to see if the rhs and lhs bitcounts agree
    #  Throw a warning if that is not the case
    arg = ex.args[1].args[2]
    if isa(arg, Expr)
        # Multiple bit or single bit
        bl = arg.args[1] 
        l = length(arg.args)
        if l == 3
            br = arg.args[3]
        else
            br = arg.args[2]
        end

        # Determine the endianness and bitcount of the lhs
        if bl == br
            bclhs = 1
            endilhs = 0
        elseif bl > br
            bclhs = bl - br + 1
            endilhs = 1
        else
            bclhs = br - bl + 1
            endilhs = 2
        end

        if     bclhs > bcrhs
            warn("Zero Bit Padding necessitated: $(bclhs) bits on lhs, and $(bcrhs) bits on rhs:\n$(ex)")
        elseif bclhs < bcrhs
            warn("Truncation of Bits necessitated: $(bclhs) bits on lhs, and $(bcrhs) bits on rhs:\n$(ex)")
        end

        if     endilhs == 1 && endirhs == 2
            error("Endian Mismatch: LHS is Big Endian, RHS is Little Endian:\n$(ex)")
        elseif endilhs == 2 && endilhs == 1
            error("Endian Mismatch: LHS is Little Endian, RHS is Big Endian:\n$(ex)")
        end
    else
        # Single bit
        bclhs = 1
        bl = arg
        br = arg
        endilhs = 0
        if     1 > bcrhs
            warn("Zero Bit Padding necessitated: $(1) bit on lhs, and $(bcrhs) bits on rhs:\n$(ex)")
        elseif 1 < bcrhs
            warn("Truncation of Bits necessitated: $(1) bit on lh, and $(bcrhs) bits on rhs:\n$(ex)")
        end
    end 

    pushArrowBitsJSif(ifAD, name, endilhs, bl,br,bclhs)
end

function JSifblockequalssymbol(ifAD::Dict{Symbol, ifArrow}, ex::Expr, bcrhs::Int, endirhs::Int)
    # Must be a wire name
    name = ex.args[1]

    # If the lhs and rhs bits don't agree, throw out warnings
    if haskey(ifAD, name)
        bclhs = ifAD[name].BitCount
        if     bclhs > bcrhs
            warn("Zero Bit Padding necessitated: $(bclhs) bits on lhs, and $(bcrhs) bits on rhs:\n$(ex)")
        elseif bclhs < bcrhs
            warn("Truncation of Bits necessitated: $(bclhs) bit on lh, and $(bcrhs) bits on rhs:\n$(ex)")
        end
    end

    pushArrowJSif(ifAD, name, endirhs, bl,br,bcrhs)
end


function pushArrowJSif(ifAD::Dict{Symbol, ifArrow}, name::Symbol, endi::Int, bl::Int, br::Int, bc::Int)
    if haskey(ifAD, name)
        error("Attempting to assign a whole wire after assignment: $(name)")
    else
        # Creating a whole new wire
        ifAD[name] = ifArrow(endi, bl, br, bc, 1, fill!(Array{Int}(bc), 1))
    end
end

function pushArrowBitsJSif(ifAD::Dict{Symbol, ifArrow}, name::Symbol, endi::Int, bl::Int, br::Int, bc::Int)
    if haskey(ifAD, name)
        a = ifAD[name]
        if     a.Assigned == 1
            error("Attempting to assign individual bits after a whole wire assignment: $(name)")
        elseif a.Assigned == 0
            # this is likely an erroneous error statement, and likely needs removing
            if     a.Endian == 0 && bc > 1
                error("Attempting to assign multiple bits of a wire which lacks Endianness: $(name)")
            end
            ifAD[name].Assigned = 2
        end

        minb = min(bl, br)
        maxb = max(bl, br)
        arrowminb = min(a.BitRight, a.BitLeft)
        arrowmaxb = max(a.BitRight, a.BitLeft)
        if     minb < arrowminb
            error("Attempting to assign bit $(minb) which is outside $(name)")
        elseif maxb > arrowmaxb
            error("Attempting to assign bit $(maxb) which is outside $(name)")
        end

        if a.Assigned == 2
            overwrites = find(ifAD[name].AsgnArray[(minb-arrowminb+1):(maxb-arrowminb+1)] != 0)
            if overwrites != []
                error("Assigning to bits $(overwrites + minb + arrowminb) after they were already assigned: $(name)")
            end            
        end

        tmp = maximum(ifAD[name].AsgnArray) + 1
        ifAD[name].AsgnArray[(minb-arrowminb+1):(maxb-arrowminb+1)] = tmp
    else
        # Creating a whole new wire
        ifAD[name] = ifArrow(endi, bl, br, bc, 2, fill!(Array{Int}(bc), 1))        
    end
end



