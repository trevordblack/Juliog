
function JuliogToVerilog(ex::Expr, ad::Dict{Symbol, Arrow})
    global arrowDict = ad
    return JVmodule(ex)
end

function JVmodule(ex::Expr)
    println(ex)
    # Convert function header to a module header
    verilog = "module"
    l = length(ex.args[1].args)
    if l == 1
        warn("Conversion to Verilog: Module creation with no input/output signals")
    end
    verilog = verilog * " " * String(ex.args[1].args[1]) * "("
    for i = 2:(l-1)
        verilog = verilog * String(ex.args[1].args[i]) * ", "
    end
    verilog = verilog * String(ex.args[1].args[l]) * ") ;\n\n"

    # Convert function block into verilog syntax
    vblock = ex.args[2]
    verilog = verilog * JVblock(vblock)    

    # End the module
    verilog = verilog * "\nendmodule"

    # return the completed verilog syntax String
    return verilog
end


# Convert a block of Juliog syntax to Verilog syntax
# Returns a string
# The module will have no parameters, as those will have all been removed during parameterize
function JVblock(ex::Expr)
    verilog = ""
    l = length(ex.args)

    for i = 1:l
        outstr = JVblockhelper(ex.args[i])
        verilog = verilog * outstr * "\n"
    end
    return verilog
end

function JVblockhelper(ex::Expr)
    h = ex.head
    println(ex)
    if     h == :(=)
        return JVequals(ex)
    elseif h == :(:=)
        return JVassignment(ex)
    elseif h == :macrocall
        return JVmacro(ex)
    else
        error("Hit an unexplored expression head $(h) in expr:\n$(ex)")
    end
end

# Must be creating a wire
# MOON Accomodate matrix notation here
function JVequals(ex::Expr)
    global arrowDict

    # Get the name of the new wire or reg
    if isa(ex.args[1], Expr)
        # Is a ref
        name = ex.args[1].args[1]
    else
        name = ex.args[1]
    end

    # Get the arrow info
    wt = arrowDict[name].WireType
    reg = arrowDict[name].Reg

    # Get the bit indices and string
    bl = arrowDict[name].BitLeft
    br = arrowDict[name].BitRight
    index = "[" * dec(bl) * ":" * dec(br) * "]"

    if     wt == 0 && !reg
        return "wire " * index * " " * String(name) * " ;"
    elseif wt == 0 && reg
        return "reg " * index * " " * String(name) * " ;"
    elseif wt == 1
        return "input " * index * " " * String(name) * " ;"
    elseif wt == 2 && !reg
        return "output " * index * " " * String(name) * " ;"
    elseif wt == 0 && reg
        return "output reg " * index * " " * String(name) * " ;"
    end
end

function JVassignment(ex::Expr)
    verilog = "assign "
    if isa(ex.args[1], Expr) && ex.args[1].head == :ref
        verilog = verilog * String(ex.args[1].args[1])
        # MOON account for Matrix notation here
        if isa(ex.args[1].args[2], Expr)
            # Multiple Bits refererence
            if length(ex.args[1].args[2].args) == 3
                verilog = verilog * "[" * dec(ex.args[1].args[2].args[1]) * ":" * dec(ex.args[1].args[2].args[3]) * "] = "
            else
                verilog = verilog * "[" * dec(ex.args[1].args[2].args[1]) * ":" * dec(ex.args[1].args[2].args[2]) * "] = "
            end                
        else
            # Bit reference
            verilog = verilog * "[" * dec(ex.args[1].args[2]) * "] = "
        end
    else
        # Is just a simple symbol then
        verilog =  verilog * String(ex.args[1]) * " = "
    end

    rhs = ex.args[2]
    if isa(rhs, Expr)
        verilog = verilog * JVrhs(rhs)
    else
        # Is a simple symbol or int
        if isa(rhs, Int)
            verilog = verilog * dec(rhs)
        elseif isa(rhs, Char)
            verilog = verilog * string(rhs)
        else
            verilog = verilog * String(rhs)
        end
    end

    return verilog * " ;"
end

# MOON Accomodate matrix notation
# An expression needing to be converted to verilog syntax
function JVrhs(ex::Expr)
    h = ex.head
    if     h == :vcat
        return JVrhsvcat(ex)
    elseif h == :ref
        return JVrhsref(ex)
    elseif h == :call
        return JVrhscall(ex)
    elseif h == :if
        return JVrhsif(ex)
    else
        error("inside JVrhs, hit unexplored expression head $(h) in expr:\n$(ex)")        
    end
end

function JVrhsvcat(ex::Expr)
    println(ex)
    verilog = "{"
    l = length(ex.args)
    bitcount = 0
    bitstr = ""
    for i = 1:l
        arg = ex.args[i]

        if     isa(arg, Int)
            # accumulate bit string until something other than int
            bitcount = bitcount + 1
            bitstr = bitstr * dec(arg)
        else                     
            if verilog != "{"
                verilog = verilog * ", "
            end

            if bitcount != 0
                verilog = verilog * dec(bitcount) * "b" * bitstr
                bitcount = 0
                bitstr = ""
            end

            if     isa(arg, Expr)
                # Only refs and bit repeats are allowed
                if     arg.head == :ref
                    verilog = verilog * JVrhsref(arg)
                elseif arg.head == :call
                    verilog = verilog * JVrhscall(arg)
                else
                    error("Inside JVrhsvcat, argument $(arg) is unaccepted syntax:\n$(ex)")
                end
            elseif isa(arg, Char)
                verilog = verilog * string(arg)
            else
                # Is a symbol
                verilog = verilog * String(arg)
            end
        end
        println(bitcount)
        println(bitstr)
        println(verilog)
    end
    # In case the concatenation ends with bit padding
    if bitcount != 0
        verilog = verilog * dec(bitcount) * "b" * bitstr
    end
    # Add the closing bracket and return
    return verilog * "}"
end

# MOON Accomodate matrix notation here
function JVrhsref(ex::Expr)
    verilog = String(ex.args[1])
    if isa(ex.args[2], Expr)
        # Multiple Bits refererence
        if length(ex.args[2].args) == 3
            verilog = verilog * "[" * dec(ex.args[2].args[1]) * ":" * dec(ex.args[2].args[3]) * "]"
        else
            verilog = verilog * "[" * dec(ex.args[2].args[1]) * ":" * dec(ex.args[2].args[2]) * "]"
        end
    else
        # Bit reference
        verilog = verilog * "[" * dec(ex.args[2]) * "]"
    end
    return verilog
end

function JVrhscall(ex::Expr)
    l = length(ex.args)

    # Check to see if this call is just a bitrepeat
    if l == 2 && Symbol(ex.args[1]) != :~
        # Must be a bit repeat
        verilog = "(" * dec(ex.args[2]) * "){"
        if isa(ex.args[1], Expr)
            verilog = verilog * JVrhs(ex.args[1]) * "}"
            return verilog
        else
            verilog = verilog * String(Symbol(ex.args[1])) * "}"
            return verilog
        end
    end

    argstrs = Array{String}(l)
    for i = 1:l
        arg = ex.args[i]
        if     isa(arg, Expr) && arg.head == :call
            argstrs[i] = "(" * JVrhscall(arg) * ")"
        elseif isa(arg, Expr)
            argstrs[i] = JVrhs(arg)
        elseif isa(arg, Int)
            argstrs[i] = dec(arg)
        elseif isa(arg, Char)
            argstrs[i] = string(arg)
        else
            argstrs[i] = String(Symbol(arg))
        end
    end

    if     l == 3
        return argstrs[2] * " " * argstrs[1] * " " * argstrs[3]
    elseif l == 2
        return argstrs[1] * argstrs[2]
    else
        error("In JVrhscall, Hit a :call head which has $(l) arguments. Throwing a fit:\n$(ex)")
    end
end

# TODO Accomodate the new condition rules (e.g. a cond will just be a ~, symbol, or ref)
function JVrhsif(ex::Expr)
    # reduce condition to a single bit if acceptable
    verilog = "(" * JVrhsifcondition(ex.args[1]) * ") ? "

    # Must have 3 args after sanitization step
    arg = ex.args[1]
    if     isa(arg, Expr)
        argstr = "(" * JVrhs(arg) * ")"
    elseif isa(arg, Int)
        argstr = dec(arg)
    elseif isa(arg, Char)
        argstr = string(arg)
    else
        argstr = String(arg)
    end    
    verilog = verilog * argstr * " : "

    arg = ex.args[2]
    if     isa(arg, Expr)
        argstr = "(" * JVrhs(arg) * ")"
    elseif isa(arg, Int)
        argstr = dec(arg)
    elseif isa(arg, Char)
        argstr = string(arg)
    else
        argstr = String(arg)
    end    
    verilog = verilog * argstr

    return verilog
end


# This whole thing can probably get thrown out
function JVrhsifcondition(ex::Expr)
    # Can reduce if either of the operands are 0, 1
    #  And if the condition is only a single bit
    #  This requires importing JS functions to determine bit count
    reducible = false
    if     ex.args[2] == 0 || ex.args[2] == 1
        arg = ex.args[3]
        if     isa(arg, Expr) && arg.head == :ref
            bc, endi = JSreadrhsref(arg)
            if bc == 1
                reducible = true            
                argstr = JVrhsref(arg)
            end            
        elseif isa(arg, Expr) && arg.head == :vcat
            bc, endi = JSreadrhsvcat(arg)
            if bc == 1
                reducible = true
                argstr = JVrhsvcat(arg)
            end
        elseif isa(arg, Symbol)
            global arrowDict
            if arrowDict[arg].BitCount == 1
                reducible = true
                argstr = String(arg)
            end
        else
            error("In JVrhsifcondition, Attempting to if with condition $(arg) in expr: $(ex)")
        end

        if reducible
            return (ex.args[2] == 1) ? argstr : ("~" * argstr)
        end
    elseif ex.args[3] == 0 || ex.args[3] == 1
        arg = ex.args[2]
        if     isa(arg, Expr) && arg.head == :ref
            bc, endi = JSreadrhsref(arg)
            if bc == 1
                reducible = true            
                argstr = JVrhsref(arg)
            end            
        elseif isa(arg, Expr) && arg.head == :vcat
            bc, endi = JSreadrhsvcat(arg)
            if bc == 1
                reducible = true
                argstr = JVrhsvcat(arg)
            end
        elseif isa(arg, Symbol)
            global arrowDict
            if arrowDict[arg].BitCount == 1
                reducible = true
                argstr = String(arg)
            end
        else
            error("In JVrhsifcondition, Attempting to if with condition $(arg) in expr: $(ex)")
        end

        if reducible
            return (ex.args[3] == 1) ? argstr : ("~" * argstr)
        end
    end

    # Cannot be further reduced, convert directly to String
    arg = ex.args[2]
    if     isa(arg, Expr) && arg.head == :ref
        argstr = JVrhsref(arg)
    elseif isa(arg, Expr) && arg.head == :vcat
        argstr = JVrhsvcat(arg)
    elseif isa(arg, Int)
        argstr = dec(arg)
    elseif isa(arg, Char)
        argstr = string(arg)
    elseif isa(arg, Symbol)
        argstr = String(arg)
    else
        error("In JVrhsifcondition, Attempting to if with condition $(arg) in expr: $(ex)")
    end    
    verilog = argstr * " " * String(ex.args[1]) * " " 

    arg = ex.args[3]
    if     isa(arg, Expr) && arg.head == :ref
        argstr = JVrhsref(arg)
    elseif isa(arg, Int)
        argstr = dec(arg)
    elseif isa(arg, Char)
        argstr = string(arg)
    elseif isa(arg, Symbol)
        argstr = String(arg)
    else
        error("In JVrhsifcondition, Attempting to if with condition $(arg) in expr: $(ex)")
    end    
    verilog = verilog * argstr
    return verilog    
end


# TODO Verilog doesn't natively support recursion, so need to remove it
function JVmacro(ex::Expr)
    mc = ex.args[1]
    if     mc == Symbol("@async")
        return JVasync(ex)
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

function JVasync(ex::Expr)
    verilog = "always@* begin\n"

    l = length(ex.args[2].args)
    for i = 1:l
        verilog = verilog * JVasynchelper(ex.args[2].args[i], 1)
    end

    verilog = verilog * "end"
    return verilog
end

function JVasynchelper(ex::Expr, depth::Int)
    if isa(ex.args[1], Expr) && ex.args[1].head == :if
        verilog = ""

    else
        if ex.args[1].head == :ref
            verilog = String(ex.args[1].args[1])
            # MOON account for Matrix notation here
            if isa(ex.args[1].args[2], Expr)
                # Multiple Bits refererence
                if length(ex.args[1].args[2].args) == 3
                    verilog = verilog * "[" * dec(ex.args[1].args[2].args[1]) * ":" * dec(ex.args[1].args[2].args[3]) * "] = "
                else
                    verilog = verilog * "[" * dec(ex.args[1].args[2].args[1]) * ":" * dec(ex.args[1].args[2].args[2]) * "] = "
                end                
            else
                # Bit reference
                verilog = verilog * "[" * dec(ex.args[1].args[2]) * "] = "
            end            
        else
            # Is just a simple symbol then
            verilog =  ex.args[1] * " = "
        end

        rhs = ex.args[2]
        if isa(rhs, Expr)
            verilog = verilog * JVrhs(rhs)
        else
            # Is a simple symbol or int
            if isa(rhs, Int)
                verilog = verilog * dec(rhs)
            elseif isa(rhs, Char)
                verilog = verilog * string(rhs)
            else
                verilog = verilog * String(rhs)
            end
        end

        for i = 1:depth
            verilog = "\t" * verilog 
        end

        return verilog * " ;\n"
    end
end
