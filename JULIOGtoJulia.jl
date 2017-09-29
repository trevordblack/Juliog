# TODO add support for reverse indexing with -1
#       e.g. a[0:-1:5]
# MOON add support for Julia matrix notation
#       e.g. a[5:0, 3:1, 2:0]


# Prerequitisite: Must be passed a preprocessed Juliog function block
function JULIOGtoJulia(ex::Expr, ad::Dict{Symbol, Arrow})
    global arrowDict = ad
    return JJfunction(ex)
end

# TODO add symbolic link for nameDict for direct assignments of one wire to another
function JJfunction(ex::Expr)
    println(ex)    
    global nameDict = Dict{Symbol, Array{Symbol}}()
    jexpr = Expr(:Function)
    jargs = Array{Any}(2)
    jargs[1] = ex.args[1]
    jargs[2] = JJblock(ex.args[2])
    jexpr.args = jargs
    return jexpr
end


# Prerequisite: Expr head MUST be a :block
function JJblock(ex::Expr)
    l = length(ex.args)
    jexpr = Expr(:block)
    jargs = Array{Any}(l)

    for i = 1:l
        println(i)
        arg = ex.args[i]
        println(arg)
        if     isa(arg, Expr)
            jargs[i] = JJblockhelper(arg)
            println("jargs at $(i) is $(jargs[i])")
        else
            error("Inside JULIOGtoJulia hit a non-expression block argument")
        end
    end

    # remove :block exprs
    i = 1
    while i <= length(jargs)
        arg = jargs[i]
        if     isa(arg, Expr) && arg.head == :block
            splice!(jargs, i, arg.args)
        elseif isa(arg, Expr) && arg.head == :call
            i = i + 1
        else
            error("A non Expr, or an Expr not of type call is found in the Julia:\n$(jargs)")
        end
    end

    jexpr.args = jargs
    return jexpr
end

function JJblockhelper(ex::Expr)
    h = ex.head
    elseif h == :(=)
        return JJequals(ex)
    elseif h == :(:=)
        return JJassignment(ex)
    elseif h == :macrocall  
        return JJmacro(ex)
    else
        error("Hit an unexplored expression head $(h) in expr:\n$(ex)")
    end
end

function JJequals(ex::Expr)
    global arrowDict

    # Get the name of the new wire or reg
    if isa(ex.args[1], Expr)
        # Is a ref
        name = ex.args[1].args[1]
        # MOON
    else
        name = ex.args[1]
    end

    # Get the arrow info
    a = arrowDict[name]

    # Get the wire assignment information
    asgn = a.Assigned
    # Get the wire type
    wt = a.WireType
    # Get the bit indices and string
    bc = a.BitCount

    if     asgn == 0
        jargs = Array{Any}(2)
        jargs[1] = Expr(:call, :Wire, name, bc)
        jargs[2] = Expr(:call, :CONST, name, fill!(Array{UIn8}(bc), UInt8('z')))
        jexpr = Expr(:block, jargs[1], jargs[2])
        return jexpr
    elseif asgn == 1
        if     wt == 0
            return Expr(:call, :Wire, name, bc)
        elseif wt == 1
            return Expr(:call, :Input, name, bc)
        elseif wt == 2
            return Expr(:call, :Output, name, bc)
        end 
    elseif asgn == 2
        global nameDict
        jargs = Array{Any}(0)
        nameArray = Array{Symbol}(0)

        tmpasgn = a.AsgnArray[1]
        tmpi = 1
        bmin = min(a.BitLeft, a.BitRight)

        l = length(a.AsgnArray)
        for i = 2:l
            asgn = a.AsgnArray[i]
            if asgn != tmpasgn
                newname = Symbol(
                    String(String(name) * "!!b" * 
                    dec(tmpi + bmin - 1) * "_" * dec(i + bmin - 2)))
                bc = i - tmpi
                append!(nameArray, fill(newname , bc))

                if   asgn == 0
                    append!(jargs, [Expr(:call, :Wire, newname, bc) ;
                        Expr(:call, :CONST, newname, fill(UInt8('z'), bc))])
                else
                    push!(jargs, Expr(:call, :Wire, newname, bc))
                end

                tmpasgn = asgn
                tmpi = i
            end
        end
        # Solve for last wire bits
        newname = Symbol(
            String(String(name) * "!!b" * 
            dec(tmpi + bmin - 1) * "_" * dec(l + bmin - 1)))
        bc = l - tmpi + 1
        append!(nameArray, fill(newname , bc))

        if   asgn == 0                
            append!(jargs, [Expr(:call, :Wire, newname, bc) ;
                Expr(:call, :CONST, newname, fill(UInt8('z'), bc))])
        else
            push!(jargs, Expr(:call, :Wire, newname, bc))
        end

        nameDict[name] = nameArray

        jexpr = Expr(:block)
        jexpr.args = jargs
        return jexpr
    end  
end


function JJassignment(ex::Expr)

    # Deal with lhs
    if isa(ex.args[1], Expr)
        # Is a ref
        name = ex.args[1].args[1]
        # TODO get name for this assignment from new data structure
        # TODO account for reverse indexing

        # MOON 
    else
        # Must just be a symbol and therefore the wire is not partitioned
        name = ex.args[1]
    end



    # Deal with rhs
    rhs = ex.args[2]
    # If declaring two wires as equal, make a symbolic link and save bit offset
    if     isa(rhs, Symbol)

    # Also a symbolic link
    elseif isa(rhs, Expr) && rhs.head == :ref && isa(rhs.args[1], Symbol)

    # Is a simple constant declaration
    elseif isa(rhs, Int)

    # Is a simple constant declaration
    elseif isa(rhs, Char)

    # Actually some logic involved
    else
        rhsArgs, rhsJulia = JJrhs(rhs)
    end



    # Assign to lhs
    if isa(ex.args[1], Expr)
        # We are indexing bit(s)
        sym = ex.args[1].args[1]

        # Get bits of interest
        if isa(ex.args[1].args[2], Expr)
            # Multiple Bits refererence
            bl = ex.args[1].args[2].args[1]
            br = ex.args[1].args[2].args[2]
            endi = bl > br
        else
            # Bit reference
            bl = ex.args[1].args[2]
            br = bl
            endi = true
        end      

        # throw error if writing bits of undefined wire
        if !haskey(arrowdict, sym)
            error("Attempting to write to the bits of undefined wire: $(sym)")
        else
            # throw error if we are assigning to these wires an additional time
            arrow = arrowdict[sym]
            l = length(arrow.SubArrows)
            if l != 0
                if endi
                    # Big endian
                    for i = 1:l
                        sa = arrow.SubArrows[i]
                        if ((bl >= sa.bitleft) && (sa.bitleft >= br))
                            || ((bl >= sa.bitright) && (sa.bitright >= br))
                            error("Attempting to assign bits of wire $(sym) an additional time")
                        end
                    end
                else
                    # little endian
                    for i = 1:l
                        sa = arrow.SubArrows[i]
                        if ((br >= sa.bitleft) && (sa.bitleft >= bl))
                            || ((br >= sa.bitright) && (sa.bitright >= bl))
                            error("Attempting to assign bits of wire $(sym) an additional time")
                        end
                    end
                end
            end
        end

        # Done error checking
        # TODO create wire(s) as needed for correct bifurcation
        # TODO evaluation
        # something like
        # JJevaluation(sym , ex, arrowdict)

    else
        # Are not bit indexing
        sym = ex.args[1]

        if haskey(arrowdict, sym)
            # throw error if writing to a defined wire we have already written over
            # throw error if we are assigning to these wires an additional time
            arrow = arrowdict[sym]
            l = length(arrow.SubArrows)
            if l != 0
                error("Attempting to assign wire $(sym) an additional time")
            end

            # TODO evaluation
            # something like
            # JJevaluation(sym, ex, arrowdict)

        else
            # determine bit count of rhs
            # TODO

        end
    end

end


function JJrhs(rhs)
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


# The righthand side of an assignment
function JJrhsexpr(ex::Expr)
    h = ex.head
    if     h == :ref
        return JJrhsref(ex)
    elseif h == :vcat
        return JJrhsvcat(ex)
    elseif h == :call
        return JJrhscall(ex)
    elseif h == :if
        return JJrhsif(ex)
    else
        error("Hit unexpected expression symbol $(h) in JSreadrhs on expression:\n$(ex)")
    end
end






function JJevaluation(sym::Symbol, bl::Int, br::Int, endi::Bool, ex::Expr)
    jexpr = Expr(:block)
    newsym = Symbol(String(sym)  * "!" * dec(bl) * "_" * dec(br))
    b = abs(bl - br) + 1
    wirearg = [Symbol("@wire") ; newsym ; b]

    if !isa(ex.args[2], Expr)
        # is either a constant wire, or a complete assignment of one wire to another
        if isa(ex.args[2], Symbol)
            # Assignment of one wire to another
            jargs = Array{Any}(2)
            jargs[1] = wirearg
            jargs[2] = [Symbol("EQUALS") ; newsym ; ex.args[2]]
            jexpr.args = jargs
            return jexpr
        else
            # constant (unsigned) value
            val = ex.args[2]
            vt = typeof(val)
            if vt != Int && vt != UInt && vt != UInt8 && vt != Array{UInt8}
                error("Attempting to write a constant value which is of wrong type")
            end
            if vt == Int
                val = UInt8(val)
            end
            jargs = Array{Any}(2)
            newsym = Symbol(String(sym)  * "!" * dec(bl) * "_" * dec(br))
            jargs[1] = wirearg
            jargs[2] = [Symbol("CONST") ; newsym ; val]
            jexpr.args = jargs
            return jexpr           
        end
    end

    # Must be an expr on rhs    
    #  descend into expressions
    finalsuffix, bitcount, evalargs = JJevaluationhelper(0, newsym, ex.args[2])

    # raise block that was created
    # Make certain that lhs and rhs have same bitcount

    # Return expr and wire sym 
end



# Always passed an expr, and always the rhs of an assignment
function JJevaluationhelper(suffix::Int, newsym::Symbol, endi::Bool, ex::Expr)
    h = ex.head
    if     h == :ref
        # Is a bitwise wire index
        return JJref(suffix, newsym, ex, arrowdict)
    elseif h == :vcat
        # Is a wire concatenation
        return JJvcat(suffix, newsym, endi, ex, arrowdict)
    elseif h == :call
        l = length(ex.args)
        s = Array{Int}(l+1)
        s[1] = suffix
        bt = Array{Int}(l)
        jargs = Array{Any}(0)
        for i = 2:l
            if     isa(ex.args[i], Expr)
                s[i+1], bt[i], evalargs = JJevaluationhelper(s[i], newsym, endi, ex)
                append!(jargs, evalargs)
            end
        end

        op = ex.args[1]    
        if isa(op, Symbol)
            if     op == :(&)
                # Must have 2 operands
                if bt[1] != bt[2]
                    error("Attempting to AND wires of differing bit sizes: $(bt[1]) and $(bt[2])")
                end
                andargs = Array{Any}(2)



            elseif op == :(|)

            elseif op == :(~)

            elseif op == :(^)

            elseif op == :(+)

            elseif op == :(-)

            elseif op == :(*)

            elseif op == :(/)

            elseif op == :(%)

            else
                # must be the bit repeat of a wire

            end

        else
            # Must be a bit repeat of a bit reference

        end

    else
        error("In JJevaluationhelper, hit an unexpected subexpression head: $(h)")
    end
end

# TODO add support for matrix notation
function JJref(suffix::Int, newsym::Symbol, ex::Expr)
    # Since this is an expr, it must be a bit(s) reference
    refsym = ex.args[1]
    if !haskey(arrowdict, refsym)
        error("Attempting to reference an undefined wire: $(refsym)")
    end
    refarrow = arrowdict[refsym]

    # Create a symbol for this intermediate wire
    interwiresym = Symbol(String(newsym) * "!!" * dec(suffix))

    if isa(ex.args[2], Expr)
        # bits reference
        bl = ex.args[2].args[1]
        br = ex.args[2].args[2]

        if refarrow.Endian
            # Big-Endian
            
            # Check endian of reference
            if br > bl
                error("Attempting to reference $(refsym) in incorrect endian, reverse endian not implemented yet")                
            end

            # Check boundary conditions
            if     bl > refarrow.BitLeft
                error("Attempting to reference bit $(bl) which is outside $(refsym)")
            elseif br < refarrow.BitRight
                error("Attempting to reference bit $(br) which is outside $(refsym)")
            end

            # Create new wire
            bt = (bl-br)+1
            wireexpr = Expr(:macrocall)
            wireexpr.args = [Symbol("@wire") ; interwiresym ; bt]

            # BITS new wire
            refexpr = Expr(:call)
            refexpr.args = [Symbol("BITS") ; interwiresym ; refsym ; bl-refarrow.BitRight ; br-refarrow.BitRight ]

            jargs = Array{Any}(2)
            jargs[1] = wireexpr
            jargs[2] = refexpr
            return (suffix+1, bt, jargs)

        else
            # Little-Endian

            # Check endian of reference
            if bl > br
                error("Attempting to reference $(refsym) in incorrect endian")                
            end

            # Check boundary conditions
            if     bl < refarrow.BitLeft
                error("Attempting to reference bit $(bl) which is outside $(refsym)")
            elseif br > refarrow.BitRight
                error("Attempting to reference bit $(br) which is outside $(refsym)")
            end

            # Create new wire
            # Create expr
            bt = (br-b1)+1
            wireexpr = Expr(:macrocall)
            wireexpr.args = [Symbol("@wire") ; interwiresym ; bt]

            # BITS new wire
            refexpr = Expr(:call)
            refexpr.args = [Symbol("BITS") ; interwiresym ; refsym ; br-refarrow.BitLeft ; bl-refarrow.BitLeft ]

            jargs = Array{Any}(2)
            jargs[1] = wireexpr
            jargs[2] = refexpr
            return (suffix+1, bt, jargs)
        end

    else
        # single bit reference
        b = ex.args[2]

        # Check boundary conditions
        if refarrow.Endian
            if b > refarrow.BitLeft
                error("Attempting to reference bit $(b) which is outside $(refsym)")
            end

            # BIT new wire
            refexpr = Expr(:call)
            refexpr.args = [Symbol("BIT") ; interwiresym ; refsym ; b-refarrow.BitRight]

        else
            if b > refarrow.BitRight
                error("Attempting to reference bit $(b) which is outside $(refsym)")
            end
            # BIT new wire
            refexpr = Expr(:call)
            refexpr.args = [Symbol("BIT") ; interwiresym ; refsym ; b-refarrow.BitLeft]
        end

        # Create new wire
        wireexpr = Expr(:macrocall)
        wireexpr.args = [Symbol("@wire") ; interwiresym ; 1]

        jargs = Array{Any}(2)
        jargs[1] = wireexpr
        jargs[2] = refexpr
        return (suffix+1, 1, jargs)
    end
end

# TODO add support for bit repeat
# only accepts references, symbols, chars, ints
# need to know endian of wire being written
function JJvcat(suffix::Int, newsym::Symbol, endi::Bool, ex::Expr)
    l = length(ex.args)

    if l == 1
        error("Attempting to concatenate a single wire: $(ex.args[1])\n\tDon't do that.")
    end

    s = suffix

    totalbitcount = 0
    bitcount
    bitval = 0
    i = endi ? 1 : l
    jargs = Array{Any}(0)
    while (endi && (i <= l)) || (!endi && (i > 0))
        arg = ex.args[i]

        if     isa(arg, Int) && (arg == 0 || arg == 1)
            # accumulate bit string until something other than int
            bitcount = bitcount + 1
            bitval = (bitval << 1) | arg
            totalbitcount = totalbitcount + 1
        else
            if s == suffix && bitcount == 0
                catargs = Array{Any}(2)                    
                vcatsym = Symbol(String(newsym)  * "!!" * dec(s))
                if     isa(arg, Expr)
                    # Must be a bit reference
                    tmp, bt, refargs = JJref(s, newsym, ex)
                    catargs[1:2] = refargs
                    totalbitcount = totalbitcount + bt
                elseif isa(arg, Symbol)
                    # Must be a wire symbol
                    # TODO flesh this out
                    error("Until Reverse endian indexing is implemented, You must bit reference any wire in a vcat")
                else
                    # Must be an int not 0 or 1
                    argtype = typeof(arg)
                    if argtype != Int && argtype != Char && argtype != UInt && argtype != UInt8 && argtype != Array{UInt8}
                        error("Attempting to write a constant value which is of wrong type")
                    end
                    if argtype == Int || argtype == Char
                        val = UInt8(arg)
                    end

                    wireexpr = Expr(:macrocall)
                    wireexpr.args = [Symbol("@wire") ; vcatsym ; 1]
                    constexpr = Expr(:call)
                    constexpr.arg = [Symbol("CONST") ; vcatsym ; val]
                    catargs[1] = wireexpr
                    catargs[2] = constexpr
                    bitcount = 0
                    bitval = 0 
                    totalbitcount = totalbitcount + 1
                end       
                append!(jargs, catargs)     
                s = s + 1
            else
                if bitcount != 0
                    # Means we have accumulated integers
                    vcatsym = Symbol(String(newsym)  * "!!" * dec(s))
                    wireexpr = Expr(:macrocall)
                    wireexpr.args = [Symbol("@wire") ; vcatsym ; bitcount]
                    constexpr = Expr(:call)
                    constexpr.arg = [Symbol("CONST") ; vcatsym ; bitval]

                    constargs = Array{Any}(2)    
                    constargs[1] = wireexpr
                    constargs[2] = constexpr
                    append!(jargs, constargs)
                    s = s + 1

                    bitcount = 0
                    bitval = 0 
                    totalbitcount = totalbitcount + 1
                end  

                catargs = Array{Any}(4)                    
                vcatsym = Symbol(String(newsym)  * "!!" * dec(s))
                if     isa(arg, Expr)
                    # Must be a bit reference
                    tmp, bt, refargs = JJref(s, newsym, ex)
                    constargs[1:2] = refargs
                    totalbitcount = totalbitcount + bt
                elseif isa(arg, Symbol)
                    # Must be a wire symbol
                    error("Until Reverse endian indexing is implemented, You must bit reference any wire in a vcat")
                else
                    # Must be an int not 0 or 1
                    argtype = typeof(arg)
                    if argtype != Int && argtype != Char && argtype != UInt && argtype != UInt8 && argtype != Array{UInt8}
                        error("Attempting to write a constant value which is of wrong type")
                    end
                    if argtype == Int || argtype == Char
                        val = UInt8(arg)
                    end

                    wireexpr = Expr(:macrocall)
                    wireexpr.args = [Symbol("@wire") ; vcatsym ; 1]
                    constexpr = Expr(:call)
                    constexpr.arg = [Symbol("CONST") ; vcatsym ; val]
                    catargs[1] = wireexpr
                    catargs[2] = constexpr
                    totalbitcount = totalbitcount + 1
                end

                vcatsymtwo = Symbol(String(newsym)  * "!!" * dec(s+1))
                catwireexpr = Expr(:macrocall)
                catwireexpr.args = [Symbol("@wire") ; vcatsymtwo ; totalbitcount]  
                catcallexpr = Expr(:call)
                catcallexpr.args = [Symbol("CAT") ; vcatsymtwo; vcatsym ; Symbol(String(newsym)  * "!!" * dec(s-1))]

                catargs[3] = catwireexpr
                catargs[4] = catcallexpr
                append!(jargs, catargs)
                s = s + 2
            end
        end

        if endi
            i = i + 1
        else
            i = i - 1
        end
    end

    # In case the concatenation ends with bit padding
    if bitcount != 0
        catargs = Array{Any}(4)                    
        vcatsym = Symbol(String(newsym)  * "!!" * dec(s))
        constwireexpr = Expr(:macrocall)
        constwireexpr.args = [Symbol("@wire") ; vcatsym ; bitcount]
        constcallexpr = Expr(:call)
        constcallexpr.arg = [Symbol("CONST") ; vcatsym ; bitval]

        vcatsymtwo = Symbol(String(newsym)  * "!!" * dec(s+1))
        catwireexpr = Expr(:macrocall)
        catwireexpr.args = [Symbol("@wire") ; vcatsymtwo ; totalbitcount]  
        catcallexpr = Expr(:call)
        catcallexpr.args = [Symbol("CAT") ; vcatsymtwo; vcatsym ; Symbol(String(newsym)  * "!!" * dec(s-1))]

        catargs[1] = constwireexpr
        catargs[2] = constcallexpr
        catargs[3] = catwireexpr
        catargs[4] = catcallexpr
        append!(jargs, catargs)
    end

    # Return the expressions
    return (s, totalbitcount, jargs)
end

function JJmacro(ex::Expr)
    mc = ex.args[1]
    if     mc == Symbol("@async")
    error("Hit an unfinished macrocall: $(mc)")
    elseif mc == Symbol("@reg")
        error("Hit an unfinished macrocall: $(mc)")
    elseif mc == Symbol("@posedge")
        error("Hit an unfinished macrocall: $(mc)")
    elseif mc == Symbol("@negedge")   
        error("Hit an unfinished macrocall: $(mc)")
    elseif mc == Symbol("@delay")
        error("Hit an unfinished macrocall: $(mc)")
    elseif mc == Symbol("@block")
        error("Hit an unfinished macrocall: $(mc)")
    elseif mc == Symbol("@verilog")
        error("Hit an unfinished macrocall: $(mc)")
    elseif mc == Symbol("@Julia")
        error("Hit an unfinished macrocall: $(mc)")        
    else
        error("Hit an unexplored macrocall $(mc) in expr:\n$(ex)")
    end
end










#=

    # Can't be reduced to a single wire, so create a new wire
    wireName = "if!" * toString(ex.args[2]) * "_" * toString(ex.args[3]) * "!!"
    i = 0
    wireNamei = Symbol(wireName * dec(i))
    while haskey(arrowDict, wireNamei)
        i = i + 1
        wireNamei = Symbol(wireName * dec(i))
    end

    jargs = Array{Any}(2)
    jargs[1] = Expr(:(=), wireNamei, Expr(:(ref), Expr(:call, :Wire), 0))
    jargs[2] = Expr(:(:=), wireNamei, ex)

function toString(name)
    if isa(name ,Symbol)
        return String(name)
    elseif isa(name, Int)
        return dec(name)
    else
        return string(name)
    end
end

=#