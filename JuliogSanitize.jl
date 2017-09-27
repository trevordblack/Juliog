
# MOON rewrite AsgnArray for matrix, verilog bus notation
mutable struct Arrow
    WireType::Int
        # 0 -> wire
        # 1 -> input
        # 2 -> output
    Reg::Bool
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

# MOON Add the ex so that the print statements can include it
function pushArrowJSequals(name::Symbol, wt::Int, endi::Int, bl::Int, br::Int, bc::Int)
    global arrowDict
    if haskey(arrowDict, name)
        error("Attempting to create wire $(name) after creation")
    end

    # Creating a whole new wire
    arrowDict[name] = Arrow(wt, false, endi, bl, br, bc, 0, fill!(Array{Bool}(bc), 1))
end

function pushArrowJSassignment(name::Symbol, endi::Int, bl::Int, br::Int, bc::Int)
    global arrowDict
    if haskey(arrowDict, name)
        a = arrowDict[name]
        if a.Assigned != 0
            error("Attempting to assign a whole wire after assignment: $(name)")
        end
        if a.WireType == 1
            error("Attempting to assign an Input: $(name)")
        end

        # Must be assigning a previously created wire
        arrowDict[name].Assigned = 1
        arrowDict[name].AsgnArray = fill!(Array{Int}(bc), 1)
    else
        # Creating a whole new wire
        arrowDict[name] = Arrow(0, false, endi, bl, br, bc, 1, fill!(Array{Int}(bc), 1))
    end
end

function pushArrowBitsJSassignment(name::Symbol, endi::Int, bl::Int, br::Int, bc::Int)
    global arrowDict
    if haskey(arrowDict, name)
        a = arrowDict[name]
        if     a.Assigned == 1
            error("Attempting to assign individual bits after a whole wire assignment: $(name)")
        elseif a.Assigned == 0
            # this is likely an erroneous error statement, and likely needs removing
            if     a.Endian == 0 && bc > 1
                error("Attempting to assign multiple bits of a wire which lacks Endianness: $(name)")
            end
            arrowDict[name].Assigned = 2
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
            overwrites = find(arrowDict[name].AsgnArray[(minb-arrowminb+1):(maxb-arrowminb+1)] != 0)
            if overwrites != []
                error("Assigning to bits $(overwrites + minb + arrowminb) after they were already assigned: $(name)")
            end            
        end

        tmp = maximum(arrowDict[name].AsgnArray) + 1
        arrowDict[name].AsgnArray[(minb-arrowminb+1):(maxb-arrowminb+1)] = tmp
    else
        # Creating a whole new wire
        arrowDict[name] = Arrow(0, false, endi, bl, br, bc, 2, fill!(Array{Int}(bc), 1))        
    end
end

function updateArrowReg(name::Symbol)
    global arrowDict
    arrowDict[name].Reg = true
end

function JSarrowDictCleaning()
    global arrowDict

    for (k, v) in arrowDict
        if v.WireType != 1
            # Check to see if any arrows in arrowDict are created but not assigned
            if v.Assigned == 0
                warn("Arrow $(k) was created but never assigned")
            end

            # Check to see if any bits in an arrow are created but not assigned
            bmin = min(v.BitLeft, v.BitRight)
            bmax = max(v.BitLeft, v.BitRight)
            for i = 1:length(v.AsgnArray)
                bit = v.AsgnArray[i]
                if bit == 0
                    warn("Bit $(bit + bmin) in Arrow $(k) was created but never assigned")
                    arrowDict[k].Assigned = 2                    
                end
            end

            # Change assigned to 1 from 2 if all bits are assigned at once
            if v.Assigned == 2
                multipleAsgns = find(v.AsgnArray != 1)
                if multipleAsgns == []
                    arrowDict[k].Assigned = 1 
                end
            end
        end

        # Check to see if any arrows have an Undeclared Endianness
        if v.Endian == 0
            warn("Endianness of Arrow $(k) is never properly defined")
        end
    end    
end






# Create Arrows for each wire
# Initialize wires if they lack it
# Make certain the user is not attempting to 
#   write or read outside of a wires access
#   Read a wire in the incorrect endian
#   write a wire which has already been written to
#   write to an input
# Throws a warning if a wire is created but never assigned (except for inputs)
# Removes lines where BitRepeat is zero
function sanitize(ex::Expr)
    # Removes lines and exprs which are a BitRepeat of zero
    # MOON

    # Create a global arrowDict
    global arrowDict = Dict{Symbol, Arrow}()

    #  Sanatize expr block and fill the new arrowDict
    jexpr = Expr(:function)
    jargs = Array{Any}(2)
    jargs[1] = Expr(:call)
    jargs[1].args = ex.args[1]
    jargs[2] = JSblock(ex.args[2])
    jexpr.args = jargs

    JSarrowDictCleaning()

    return jexpr, arrowDict
end

function JSblock(ex::Expr)
    l = length(ex.args)
    i = 1
    while i <= l
        arg = ex.args[i]
        if     isa(arg, Expr)
            jexpr = JSblockhelper(arg)
            if     isa(jexpr, Expr)
                if jexpr.head == :block
                    ex.args[i] = jexpr.args[1]
                    m = length(jexpr.args)
                    for j = 2:m
                        insert!(ex.args, i + 1, jexpr.args[j])
                        i = i + 1
                        l = l + 1
                    end
                else
                    ex.args[i] = jexpr
                end
            else                
                error("Something Weird:\n$(ex)\n$(jexpr)")
            end
        else
            error("Found a non-expr in Juliog after parameterization:\n$(arg)")
        end
        i = i + 1
    end
    return ex     
end

# MOON check for matrix notation
function JSblockhelper(ex::Expr)
    h = ex.head
    if     h == :(=)
        return JSequals(ex)
    elseif h == :(:=)
        return JSassignment(ex)
    elseif h == :if
        return JSif(ex)
    elseif h == :macrocall
        error("Macro statements are not completed in JuliogSanitize") 
        return JSmacro(ex)
    else
        error("hit unexpected call $(j) in JSblockhelper:\n$(ex)")
    end
end

function JSequals(ex::Expr)
    # Checking to see if this expression creates a new wire, input, or output
    if isa(ex.args[2], Expr)
        if isa(ex.args[2].args[1], Expr)
            sym = ex.args[2].args[1].args[1]
            wireType = -1
            if     sym == :Wire
                wireType = 0
            elseif sym == :Input
                wireType = 1
            elseif sym == :Output
                wireType = 2
            end

            if wireType != -1
                if isa(ex.args[2].args[2], Expr)
                    # Multiple bit creation
                    bl = ex.args[2].args[2].args[1]
                    br = ex.args[2].args[2].args[2]
                    if bl >= br
                        pushArrowJSequals(ex.args[1], wireType, 1, bl, br, bl-br+1)
                    else
                        pushArrowJSequals(ex.args[1], wireType, 2, bl, br, br-bl+1)
                    end
                else
                    # must be a single bit creation
                    b = ex.args[2].args[2]
                    pushArrowJSequals(ex.args[1], wireType, 0, b, b, 1)
                end
            end
            return ex
        end
    end

    return JSassignment(ex)
end

function JSassignment(ex::Expr)    
    global arrowDict

    # Check righthand side for read errors and bit counts
    rhs = ex.args[2]
    
    bcrhs, endirhs = JSrhs(rhs)    

    # Use endirhs and bcrhs to assign the new wire    jexpr = Expr(:block)
    if isa(ex.args[1], Expr)
        # lhs is a reference
        return JSassignmentref(ex, endirhs, bcrhs)
    else
        # lhs is just a symbol for a wire
        return JSassignmentsymbol(ex, endirhs, bcrhs)
    end
end

function JSrhs(rhs)
    if isa(rhs, Expr)
        bcrhs, endirhs = JSrhsexpr(rhs)
    else
        # is a Symbol or 0,1,'x','z'
        if isa(rhs, Symbol)
            if !haskey(arrowDict, rhs)
                error("Discovered uninstantiated symbol: $(rhs) in expr:\n$(ex)")
            end
            bcrhs =  arrowDict[rhs].BitCount
            endirhs = arrowDict[rhs].Endian
        else
            if     rhs == 0
                bcrhs = 1
                endirhs = 0
            elseif rhs == 1
                bcrhs = 1
                endirhs = 0
            elseif rhs == 'x'
                bcrhs = 1
                endirhs = 0
            elseif rhs == 'z'
                bcrhs = 1
                endirhs = 0
            else
                error("Attempting to assign wire to incorrectly syntaxed Right Hand Side:\n$(ex)")
            end
        end
    end
end


function JSassignmentref(ex::Expr, endirhs::Int, bcrhs::Int)
    global arrowDict

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

        retExpr = Expr(:(=), name, Expr(:(ref), Expr(:call, :Wire), Expr(:(:), bl,br)))   

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

        retExpr = Expr(:(=), name, Expr(:(ref), Expr(:call, :Wire), 0))
    end 

    if haskey(arrowDict, name)
        jexpr = ex
        jexpr.head = :(:=)
    else
        jexpr = Expr(:block)
        jargs = Array{Any}(2)
        jargs[1] = retExpr
        jargs[2] = ex
        jargs[2].head = :(:=)
        jexpr.args = jargs
    end

    pushArrowBitsJSassignment(name, endilhs, bl,br,bclhs)
    return jexpr
end

function JSassignmentsymbol(ex::Expr, endirhs::Int, bcrhs::Int)
    global arrowDict

    # Must be a wire name
    name = ex.args[1]

    # If the lhs and rhs bits don't agree, throw out warnings
    if haskey(arrowDict, name)
        bclhs = arrowDict[name].BitCount
        if     bclhs > bcrhs
            warn("Zero Bit Padding necessitated: $(bclhs) bits on lhs, and $(bcrhs) bits on rhs:\n$(ex)")
        elseif bclhs < bcrhs
            warn("Truncation of Bits necessitated: $(bclhs) bit on lh, and $(bcrhs) bits on rhs:\n$(ex)")
        end
    end

    # Add the new linewire to the arrowDict
    # and return the new wire instantiation expr so it can be added to the block

    #  Must be a wireType of wire
    #  Is not a reg since it is outside of an if or macro
    #  The endian is inherited from rhs with associated bitleft and bitright
    #  LineWire by definition
    #  It is being assigned this line
    if bcrhs == 1
        bl = 0
        br = 0
        retExpr = Expr(:(=), name, Expr(:(ref), Expr(:call, :Wire), 0))
    else
        if endirhs == 2
            bl = 0
            br = bcrhs - 1
        else
            # if enddianness if undeclared, then big notation will be adopted
            #  in such a case big endian operation may not be accurate
            bl = bcrhs - 1
            br = 0
        end
        retExpr = Expr(:(=), name, Expr(:(ref), Expr(:call, :Wire), Expr(:(:), bl,br)))       
    end

    if haskey(arrowDict, name)
        jexpr = ex
        jexpr.head = :(:=)
    else
        jexpr = Expr(:block)
        jargs = Array{Any}(2)
        jargs[1] = retExpr
        jargs[2] = ex
        jargs[2].head = :(:=)
        jexpr.args = jargs
    end

    pushArrowJSassignment(name, endirhs, bl,br,bcrhs)
    return jexpr
end


# The righthand side of an assignment
# Makes sure symbols are instantiated wires
#  and that all bit reads satisfy wire bitcounts, bitends, and bitstarts
function JSrhsexpr(ex::Expr)
    h = ex.head
    if     h == :ref
        return JSrhsref(ex)
    elseif h == :vcat
        return JSrhsvcat(ex)
    elseif h == :call
        return JSrhscall(ex)
    elseif h == :if
        return JSrhsif(ex)
    else
        error("Hit unexpected expression symbol $(h) in JSreadrhs on expression:\n$(ex)")
    end
end

# MOON add checking for (and removing?) verilog notation
function JSrhsref(ex)
    global arrowDict

    # Check to see if the rhs is calling a symbol which is not in arrowDict
    name = ex.args[1]
    if !haskey(arrowDict, name)
        error("Discovered uninstantiated symbol: $(name) in expr:\n$(ex)")
    end
    arrow = arrowDict[name]

    # Throw a warning if the rhs is calling a wire which has not been assigned
    #  but only if that wire is not also an input
    if arrow.Assigned == 0 && arrow.WireType != 1
        warn("Wire $(name) is called before being assigned:\n$(ex)")
    end
    arrowbl = arrow.BitLeft
    arrowbr = arrow.BitRight
    arrowendi = arrow.Endian

    # Check to see if the reference is single-bit or multiple-bit

    arg = ex.args[2]
    if isa(arg, Expr)
        # Must be multiple-bit reference or single-bit double-qouted

        l = length(arg.args)
        bl = arg.args[1]

        # Check to see if reverse indexing
        # And then check to see indexing in the correct Endian        
        if l == 3
            # Reverse indexing
            br = arg.args[3]            
            if arg.args[2] != -1
                error("Second Number in $(ex.args[2]) is not -1, Failed attempt to reverse indexing in:\n$(ex)")
            end
            br = arg.args[3]
            if (arrowendi == 1 && bl > br) || (arrowendi == 2 && br > bl)
                error("Attempting to reference $(name) in incorrect Endian:\n$(ex)")
            end

        elseif l == 2
            br = arg.args[2]
            br = ex.args[2].args[2]
            if (arrowendi == 1 && br > bl) || (arrowendi == 2 && bl > br)
                error("Attempting to reference $(name) in incorrect Endian:\n$(ex)")
            end
        else
            error("In JSrhsref, have a ref with irregular length:\n$(ex)")
        end

        # Check to see if referening bits outside wire limits
        if arrowendi == 2
            if br > arrowbr
                error("Attempting to reference bit $(bl) which is outside $(name):\n$(ex)")
            end
            if bl < arrowbl
                error("Attempting to reference bit $(br) which is outside $(name):\n$(ex)")
            end
        else      
            if br < arrowbr
                error("Attempting to reference bit $(br) which is outside $(name):\n$(ex)")
            end
            if bl > arrowbl
                error("Attempting to reference bit $(bl) which is outside $(name):\n$(ex)")
            end
        end

        # If nothing has failed, then get final bc and endi
        if     bl > br
            bc =  bl - br + 1
            endi = 1
        elseif br > bl
            bc = br - bl + 1
            endi = 2
        else
            bc = 1
            endi = 0
        end
    else
        # Must be single-bit reference
        b = ex.args[2]

        if arrowendi == 2
            if b > arrowbr
                error("Attempting to reference bit $(b) which is outside $(name):\n$(ex)")
            end
            if b < arrowbl
                error("Attempting to reference bit $(b) which is outside $(name):\n$(ex)")
            end
        else               
            if b < arrowbr
                error("Attempting to reference bit $(b) which is outside $(name):\n$(ex)")
            end
            if b > arrowbl
                error("Attempting to reference bit $(b) which is outside $(name):\n$(ex)")
            end
        end        

        # if nothing has failed, take default bc and endi
        bc = 1
        endi = 0
    end

    return bc, endi
end

# Helps to get rid of Verilog bus notation if present
function JSrhsrefhelper(ex::Expr)
    if isa(ex.args[1], Expr) && ex.args[1].head == :ref
        jargs = JPrefhelper(ex.args[1])
        append!(jargs,ex.args[2:end])
        return jargs
    end

    return ex.args
end

function JSrhsvcat(ex)
    global arrowDict
    l = length(ex.args)
    bctotal = 0
    enditotal = 0
        # 0 is undefined
        # 1 is big
        # 2 is little
    for i = 1:l
        # Establish Endianness and bitcount for this particular index
        # Throw warnings if endianness conflicts with previous endianness
        arg = ex.args[i]
        if     isa(arg, Expr)
            # is a ref or bit repeat
            if arg.head == :call
                # is a bit repeat
                bc, endi = JSrhscall(arg)
            else
                # is a ref
                bc, endi = JSrhsref(arg)
            end
            if enditotal != 0 && endi != enditotal
                warn("Attempting to concatenate BigEndian and LittleEndian wires:\n$(ex)")
            end
            enditotal = endi
            bctotal = bctotal + bc
        elseif isa(arg, Symbol)
            if !haskey(arrowDict, arg)
                error("Discovered uninstantiated symbol: $(arg) in expr:\n$(ex)")
            end
            endi = arrowDict[arg].Endian
            bc = arrowDict[arg].BitCount
            if enditotal != 0 && endi != enditotal
                warn("Attempting to concatenate BigEndian and LittleEndian wires:\n$(ex)")
            end
            enditotal = endi
            bctotal = bctotal + bc
        elseif arg==0 || arg==1 || arg == 'x' || arg == 'z'
            endi = 0
            bctotal = bctotal + 1
        else
            error("Attempting to vcat with an incorrect wire entry:$(arg) in:\n$(ex)")
        end
    end

    return bctotal, 0
end

function JSrhscall(ex)

    # Is a bit repeat
    if isa(ex.args[1], Expr)
        bc, endi = JSrhsref(ex.args[1])
        rep = ex.args[2]
        if rep < 0
            error("Attempting to BitRepeat $(ex) with a negative value")
        end
        bc = bc * rep
        return bc, endi
    end

    # is a logic
    opd1 = ex.args[2]
    if     isa(opd1, Expr)
        bc1, endi1 = JSrhsexpr(opd1)
    elseif isa(opd1, Symbol)
        global arrowDict
        endi1 = arrowDict[opd1].Endian
        bc1 = arrowDict[opd1].BitCount
    elseif isa(opd1, Int)
        bc1 = 1
        endi1 = 0
    elseif isa(opd1, Char)
        bc1 = 1 
        endi1 = 0
    end   

    # Check to see if it is a 2-op logic operation
    if length(ex.args) == 3
        opd2 = ex.args[3]
        if     isa(opd2, Expr)
            bc2, endi2 = JSrhsexpr(opd2)
        elseif isa(opd2, Symbol)
            global arrowDict
            endi2 = arrowDict[opd2].Endian
            bc2 = arrowDict[opd2].BitCount
        elseif isa(opd2, Int)
            bc2 = 1
            endi2 = 0
        elseif isa(opd2, Char)
            bc2 = 1 
            endi2 = 0
        end 

        if     endi1 == 0 && endi2 == 0
            endipredicted = 0
        elseif endi1 == 0
            endipredicted = endi2
        elseif endi2 == 0
            endipredicted = endi1
        elseif endi1 != endi2
            endipredicted = 0
        else
            endipredicted = endi1
        end        
    end

    o = Symbol(ex.args[1])
    if     o == :&
        JSrctwoloose(o, ex, bc1, bc2, endi1, endi2)
        bctotal = max(bc1, bc2)
        return bctotal, endipredicted
    elseif o == :|
        JSrctwoloose(o, ex, bc1, bc2, endi1, endi2)        
        bctotal = max(bc1, bc2)
        return bctotal, endipredicted
    elseif o == :~
        return bc1, endi1
    elseif o == :+
        JSrctwoloose(o, ex, bc1, bc2, endi1, endi2)
        bctotal = max(bc1, bc2) + 1
        return bctotal, endipredicted
    elseif o == :-
        bctotal = max(bc1, bc2) + 1
        return bctotal, endipredicted
    elseif o == :*
        JSrctwoloosest(o, ex, endi1, endi2)
        bctotal = bc1 + bc2
        return bctotal, endipredicted
    elseif o == :/
        JSrctwoloosest(o, ex, endi1, endi2)
        bctotal = bc1 + bc2
        return bctotal, endipredicted
    elseif o == :%
        JSrctwoloosest(o, ex, endi1, endi2)
        bctotal = bc1 + bc2
        return bctotal, endipredicted
    elseif o == :(==)
        JSrctwoloose(o, ex, bc1, bc2, endi1, endi2)
        return 1, endipredicted
    elseif o == :(!=)        
        JSrctwoloose(o, ex, bc1, bc2, endi1, endi2)
        return 1, endipredicted
    elseif o == :>
        JSrctwoloose(o, ex, bc1, bc2, endi1, endi2)
        return 1, endipredicted
    elseif o == :<
        JSrctwoloose(o, ex, bc1, bc2, endi1, endi2)
        return 1, endipredicted
    elseif o == :(>=)
        JSrctwoloose(o, ex, bc1, bc2, endi1, endi2)
        return 1, endipredicted
    elseif o == :(<=)
        JSrctwoloose(o, ex, bc1, bc2, endi1, endi2)
        return 1, endipredicted
    elseif o == :(<<)
        JSrcshift(o, ex, bc1, opd2)
        return bc1, endi1
    elseif o == :(>>)
        JSrcshift(o, ex, bc1, opd2)
        return bc1, endi1
    elseif o == :(>>>)
        JSrcshift(o, ex, bc1, opd2)
        return bc1, endi1
    elseif o == :^
        JSrctwoloose(o, ex, bc1, bc2, endi1, endi2)
        bctotal = max(bc1, bc2)
        return bctotal, endipredicted
    else
        error("Hit unexpected head $(o) in $(ex)")
    end
end

function JSrctwostrict(op::Symbol, ex::Expr, bc1::Int, bc2::Int, endi1::Int, endi2::Int)
    if bc1 != bc2
        error("Attempting to $(op) on wires of different bit count:\n$(ex)")
    end

    if endi1 != endi2
        warn("Attempting to $(op) on wires of different Endiannes:\n$(ex)")
    end
end

function JSrctwoloose(op::Symbol, ex::Expr, bc1::Int, bc2::Int, endi1::Int, endi2::Int)
    if bc1 != bc2
        warn("Attempting to $(op) on wires of different bit count:\n$(ex)")
    end

    if endi1 != endi2
        warn("Attempting to $(op) on wires of different Endiannes:\n$(ex)")
    end
end

function JSrctwoloosest(op::Symbol, ex::Expr, endi1::Int, endi2::Int)
    if endi1 != endi2
        warn("Attempting to $(ex.args[1]) on wires of different Endiannes:\n$(ex)")
    end
end

function JSrcshift(op::Symbol, ex::Expr, bc1::Int, shift::Int)
    if shift >= bc1
        warn("Attempting to shift a wire more than it has bits:\n$(ex)")
    end
end

# Even though this looks overly simplistic, this is likely the correct solution
# Must be a tertiary command on the rhs
function JSrhsif(ex::Expr)
    l = length(ex.args)

    condition = ex.args[1]
    if isa(condition, Expr)
        bc, endi = JSrhsexpr(condition)
        if bc != 1
            error("Condition of if statement does not equal 1 bit:\n$(ex)")
        end
    else
        # is a symbol            
        global arrowDict
        if isa(condition, Symbol)
            if !haskey(arrowDict, condition)
                error("Discovered uninstantiated symbol: $(arg) in expr:\n$(ex)")
            end
        end
        if arrowDict[condition].BitCount != 1
            error("Condition of if statement does not equal 1 bit:\n$(ex)")
        end
    end

    arg = ex.args[2]
    if isa(arg, Expr)
        bc1, endi1 = JSrhsexpr(arg)
    else
        # is a 0,1,'x','z' or a symbol
        if isa(arg, Symbol)
            global arrowDict
            if !haskey(arrowDict, arg)
                error("Discovered uninstantiated symbol: $(arg) in expr:\n$(ex)")
            end
            a = arrowDict[arg]
            bc1 = a.BitCount
            endi1 = a.Endian
        elseif arg != 0 && arg != 1 && arg != 'x' && arg != 'z'
            error("Attempting to write a bit to an unauthorized value: $(arg)\n$(ex)")
        else
            bc1 = 1
            endi = 0
        end
    end

    arg = ex.args[3]
    if isa(arg, Expr)
        bc2, endi2 = JSrhsexpr(arg)
    else
        # is a 0,1,'x','z' or a symbol
        if isa(arg, Symbol)
            global arrowDict
            if !haskey(arrowDict, arg)
                error("Discovered uninstantiated symbol: $(arg) in expr:\n$(ex)")
            end
            a = arrowDict[arg]
            bc2 = a.BitCount
            endi2 = a.Endian
        elseif arg != 0 && arg != 1 && arg != 'x' && arg != 'z'
            error("Attempting to write a bit to an unauthorized value: $(arg)\n$(ex)")
        else
            bc2 = 1
            endi2 = 0                
        end
    end

    bctotal = bc1
    enditotal = endi1
    if bc1 != bc2
        warn("Bit counts differ between if and else statement in:\n$(ex)")
        bctotal = max(bc1, bc2)
    end
    if endi1 != endi2
        warn("Endianness differ between if and else statement in:\n$(ex)")
        enditotal = 0
    end    

    return bctotal, enditotal
end
