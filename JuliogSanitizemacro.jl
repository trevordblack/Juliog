function JSmacro(ex::Expr)
    mc = ex.args[1]
    if     mc == Symbol("@async")
        return JSasync(ex)
    elseif mc == Symbol("@reg")
        return JSreg(ex)
    elseif mc == Symbol("@posedge")
        return JSedgereg(ex)
    elseif mc == Symbol("@negedge")   
        return JSedgereg(ex)
    elseif mc == Symbol("@delay")
        return JSdelay(ex)
    elseif mc == Symbol("@block")
        return JSmacroblock(ex)
    elseif mc == Symbol("@verilog")
        return JSverilog(ex)
    elseif mc == Symbol("@julia")
        return JSjulia(ex)
    else
        error("Hit an unexplored macrocall: $(mc)")
    end
end

function JSasync(ex::Expr)
    if !isa(ex.args[2], Expr)
        error("@async block is not a complete expr:\n$(ex)")
    end

    if !isa(ex.args[2].args[1], Expr)
        error("First argument in @async block is not an expr:\n$(ex)")
    end

    # Throw an error if a :(:=) is used
    JScolonequals(ex.args[2].args[1], ex.args[2].args[1])

    # Throw an error if a :(<=) is used
    JSnonblock(ex.args[2].args[1], ex.args[2].args[1])

    # Descend into the async and recursively do stuff
    ex.args[2].args[1] = JSasynchelper(ex.args[2].args[1])
end

function JSreg(ex::Expr)
    # Throw an error if the basic syntax is not met
    if !isa(ex.args[2], Expr)
        error("@reg block is not a complete expr:\n$(ex)")
    end
    if !isa(ex.args[2].args[1], Expr)
        error("First argument in @reg block is not an expr:\n$(ex)")
    end
    if length(ex.args[2].args[1].args) != 1
        error("Multiple Exprs found in @reg block:\n$(ex)")
    end

    # Throw an error if the first expr is not an if
    if ex.args[2].args[1].head != :if
        error("First argument in @reg block is not an if statement:\n$(ex)")
    end

    # Throws an error if there is more than the first if-else
    if length(ex.args[2].args) != 1
        error("@reg block contains more than 1 nested if-else expr:\n$(ex)")
    end

    # Throw an error if the bottom else is used
    if length(ex.args[2].args[1].args) != 2
        if JSregbottomelse(ex.args[2].args[1].args[3])
            error("The bottom-most else is used in an @reg block:\n$(ex)")
        end
    end

    # Throw an error if a :(:=) is used
    JScolonequals(ex.args[2].args[1])

    # Turn :(<=) into :(=)
    ex.args[2].args[1] = JSregequals(ex.args[2].args[1])

    # Descend into the reg and recursively do stuff
    ex.args[2].args[1] = JSreghelper(ex.args[2].args[1])

    # Turn :(=) into :(<=)
    ex.args[2].args[1] = JSregnonblocking(ex.args[2].args[1])
end

function JSedgereg(ex::Expr)
    # Throw an error if the basic syntax is not met
    if     isa(ex.args[2], Symbol)
        if !haskey(arrowDict , ex.args[2])
            error("Discovered uninstantiated symbol: $(rhs) in expr:\n$(ex)")
        end
        if arrowDict[ex.args[2]].BitCount != 1
            error("Pos or Neg edge register defined by a wire of bit count not 1:\n$(ex)")
        end
    elseif isa(ex.args[2], Expr)
        # MOON matrix stuff
        name = ex.args[2].args[1]
        if !haskey(arrowDict , name)
            error("Discovered uninstantiated symbol: $(name) in expr:\n$(ex)")
        end
        if isa(ex.args[2].args[2] , Expr)
            # Is a ref
            # check for single bit
            bl = ex.args[2].args[2].args[1]
            br = (length(ex.args[2].args) == 3) ? 
                ex.args[2].args[2].args[3] : ex.args[2].args[2].args[2]
            bmax = max(bl, br)
            bmin = min(bl, br)
            arrowbl = arrowDict[name].BitLeft
            arrowbr = arrowDict[name].BitRight
            if bmax != bmin
                error("Wire for edge reg is referencing more than 1 bit:\n$(ex)")
            end
            if arrowDict[name].Endian == 1 && (bmax > arrowbl)
                error("Referencing bit $(bmax) which is outside wire $(name):\n$(ex)")
            end
            if arrowDict[name].Endian == 1 && (bmin < arrowbr)
                error("Referencing bit $(bmin) which is outside wire $(name):\n$(ex)")
            end
            if arrowDict[name].Endian == 2 && (bmax > arrowbr)
                error("Referencing bit $(bmax) which is outside wire $(name):\n$(ex)")
            end
            if arrowDict[name].Endian == 2 && (bmin < arrowbl)
                error("Referencing bit $(bmin) which is outside wire $(name):\n$(ex)")
            end
            # check for single bit outside range
        else
            # Must be a single bit
            b = ex.args[2].args[2]
            bl = arrowDict[name].BitLeft
            br = arrowDict[name].BitRight
            if arrowDict[name].Endian == 1 && (b > bl || b < br)
                error("Referencing bit $(b) which is outside wire $(name):\n$(ex)")
            end
            if arrowDict[name].Endian == 2 && (b < bl || b > br)
                error("Referencing bit $(b) which is outside wire $(name):\n$(ex)")
            end
        end
    end

    if !isa(ex.args[3], Expr)
        error("@posedge or @negedge block is not a complete Expr:\n$(ex)")
    end

    # Throw an error if a :(:=) is used
    JScolonequals(ex.args[2].args[1])

    # Turn :(<=) into :(=)
    ex.args[2].args[1] = JSregequals(ex.args[2].args[1])

    # Descend into the reg and recursively do stuff
    ex.args[2].args[1] = JSreghelper(ex.args[2].args[1])

    # Turn :(=) into :(<=)
    ex.args[2].args[1] = JSregnonblocking(ex.args[2].args[1])
end


# TODO this stuff
# Throw an error if all wires are not written to
# Create wires if needed, change to regs as needed
# Accomodate for ifs when they show up,
# for ifs turn condition into JIR
function JSasynchelper(ex::Expr)

end

function JSreghelper(ex::Expr)

end


function JSregbottomelse(ex::Expr)
    # Passed an else statement block
    l = length(ex.args)
    iferror = true
    for i = 1:l
        arg = ex.args[i]
        if isa(arg, Expr) && arg.head == :if
            iferror = false
            if length(arg.args) == 3
                iferror = iferror | JSregbottomelse(arg.args[3]) 
            end
        end
    end
    return iferror
end

# Throw an error if a :(:=) is recursively found
function JScolonequals(ex::Expr)
    JScolonequalshelper(ex, ex)
end
function JScolonequals(top::Expr, ex::Expr)
    l = length(ex.args)
    for i = 1:l
        arg = ex.args[i]
        if isa(arg, Expr)
            if arg.head == :(:=)
                error("ColonEquals assignment used in $(ex) in @reg block:\n$(top)")
            end
            JScolonequalshelper(top, arg)
        end
    end
end

# Replace :(=) in regs with :(<=)
function JSregnonblocking(ex::Expr)
    l = length(ex.args)
    for i = 1:l
        arg = ex.args[i]
        if isa(arg, Expr)
            if arg.head == :(=)
                ex.args[i] = Expr(:call, :(<=), arg.args[1], arg.args[2])
            else
                ex.args[i] = JSregnonblocking(arg)
            end
        end
    end
    return ex
end

function JSregequals(ex::Expr)
    l = length(ex.args)
    for i = 1:l
        arg = ex.args[i]
        if isa(arg, Expr)
            if arg.head == :call && arg.args[1] == :(<=)
                ex.args[i] = Expr(:(=), arg.args[2], arg.args[3])
            else
                ex.args[i] = JSregnonblocking(arg)
            end
        end
    end
    return ex
end

# Throw an error if a :(<=) is recursively found
function JSnonblock(top::Expr, ex::Expr)
    l = length(ex.args)
    for i = 1:l
        arg = ex.args[i]
        if isa(arg, Expr)
            if arg.head == :call && arg.args[1] == :(<=)
                error("Nonblocking operator used in $(ex) in @async block:\n$(top)")
            end
            JSnonblock(top, arg)
        end
    end
end

function JSdelay(ex::Expr)
    l = length(ex.args)
    if l != 3
        error("Inappopriate number of arguments in @delay block, is $(l-1) should be 2:\n$(ex)")
    end
    if !isa(ex.args[2], Float64)
        error("Time delay does not represent a Float64 number:\n$(ex)")
    end
    if !isa(ex.args[3], Expr)
        error("Final argument of @delay block is not a expr:\n$(ex)")
    end
    return ex
end

function JSmacroblock(ex::Expr)
    if length(ex.args) != 4
        error("@block macro has incorrect number of arguments, should be 3:\n$(ex)")
    end
    if !isa(ex.args[2], Symbol)
        error("@block macro does not have a Symbol as it's first argument:\n$(ex)")
    end
    if !isa(ex.args[3], String)
        error("@block macro does not have a String as it's second argument:\n$(ex)")
    end
    if !isa(ex.args[3], Expr)
        error("@block macro does not have an Expr as it's third argument:\n$(ex)")
    end
    if ex.args[3].head != Tuple
        error("@block macro does not have a Tuple as it's third argument:\n$(ex)")
    end

    return ex
end

function JSverilog(ex::Expr)
    if length(ex.args) != 2
        error("@verilog macro has incorrect number of arguments, should be only 1:\n$(ex)")
    end
    if !isa(ex.args[2], Expr)
        error("@verilog macro does not have an expr as it's argument:\n$(ex)")
    end
    if ex.args[2].head != :block
        error("@verilog macro does not have a block as it's argument:\n$(ex)")
    end
    if length(ex.args[2].args) != 1
        error("@verilog macro expr has incorrect number of exprs, should be only 1:\n$(ex)")
    end        
    if !isa(ex.args[2].args[1], String)
        error("@verilog macro does not have contain a String inside it's block argument:\n$(ex)")
    end     

    return ex
end

function JSjulia(ex::Expr)
    if length(ex.args) != 2
        error("@julia macro has incorrect number of arguments, should be only 1:\n$(ex)")
    end
    if !isa(ex.args[2], Expr)
        error("@julia macro does not have an expr as it's argument:\n$(ex)")
    end
    if ex.args[2].head != :block
        error("@julia macro does not have a block as it's argument:\n$(ex)")
    end
    if length(ex.args[2].args) != 1
        error("@julia macro expr has incorrect number of exprs, should be only 1:\n$(ex)")
    end        
    if !isa(ex.args[2].args[1], String)
        error("@julia macro does not have contain a String inside it's block argument:\n$(ex)")
    end     

    return ex
end