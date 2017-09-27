struct pancake
    funcSymbol::Symbol
    funcName::String
    parameterizedBlock::Expr
    sanitizedBlock::Expr
    verilogBlock::String
    juliaBlock::Expr
end

global funcStack = Array{pancake}(0)
global exSymbols = Array{Symbol}(0)
global exBlocks = Array{Expr}(0)

function loadJULIOGexpr(ex::Expr)

    # Remove the REPL line number indicators
    #   If they're not already obsolete, they will be, soon
    ex = removelinenumbers(ex)  

    if ex.head == :Function
        push!(exSymbols, ex.args[1].args[1])
        push!(exBlocks, ex)
    else
        # ex.head must equal :block
        l = length(ex.args)
        for i = 1:l
            push!(exSymbols, ex.args[i].args[1].args[1])
            push!(exBlocks, ex.args[i])
        end
    end
end

function overwriteJULIOGexpr(ex::Expr)
    global exSymbols = Array{Symbol}(0)
    global exBlocks = Array{Expr}(0)

    # Remove the REPL line number indicators
    #   If they're not already obsolete, they will be, soon
    ex = removelinenumbers(ex)    

    if ex.head == :Function
        push!(exSymbols, ex.args[1].args[1])
        push!(exBlocks, ex)
    else
        # ex.head must equal :block
        l = length(ex.args)
        for i = 1:l
            push!(exSymbols, ex.args[i].args[1].args[1])
            push!(exBlocks, ex.args[i])
        end
    end
end

function parsefile(filename::String)
    file = open(filename)
    str = readstring(file)
    return parse(str)    
end

function removelinenumbers(ex::Expr)
    l = length(ex.args)
    i = 1
    while i <= l
        if isa(ex.args[i], Expr)
            if ex.args[i].head == :line
                deleteat!(ex.args, i)
                i = i - 1
                l = l - 1
            else
                ex.args[i] = removelinenumbers(ex.args[i])
            end
        end
        i = i + 1
    end
    return ex
end

# TODO Figure out how to remember hieararchy in funcStack
#       Will come in handy when I need to unroll recursion in verilog
macro block(func::Symbol, name::String, arguments::Expr)   
    if !isdefined(:exSymbols)
        error("No expression loaded. Cannot call @block without loaded JULIOG")
    end
    if !in(func, exSymbols)
        error("No Symbol matching $(func) was found in loaded JULIOG expression")
    end

    if !isdefined(:funcStack)
        global funcStack = Array{pancake}(0)
    else
        global funcStack
    end

    ref = findlast(exSymbols .== func)
    blockToInterpret = exBlocks[ref]
  
    push!(funcStack, pancake(func, name, Expr(:function), Expr(:function), "", Expr(:function)))
    l = length(funcStack)

    # parameterize the block
    # solve for function statics
    parameterizedBlock = parameterize(blockToInterpret, arguments)
    # Print parameterizedBlock to a file
    # prettyprintPB(sanitizedBlock)

    funcStack[l] = pancake(func, name, parameterizedBlock, Expr(:function), "", Expr(:function))

    # Create Data structure of wires created
    # add wire instantiations when lacking
    sanitizedBlock, arrowDict = sanitize(parameterizedBlock)

    funcStack[l] = pancake(func, name, parameterizedBlock, sanitizedBlock, "", Expr(:function))

    # Convert the block to a string of verilog text
    verilogBlock = JuliogToVerilog(sanitizedBlock, arrowDict)
    # Print verilogBlock to a file
    # prettyprintJV(verilogBlock)

    funcStack[l] = pancake(func, name, parameterizedBlock, sanitizedBlock, verilogBlock, Expr(:function))

    #juliaBlock = JuliogToJulia(sanitizedBlock)
    juliaBlock = Expr(:function)
    # Print juliaBlock to a file
    # prettyprintJB(juliaBlock)

    #funcStack[l] = pancake(func, name, parameterizedBlock, sanitizedBlock, verilogBlock, juliaBlock)
    println("At end of @block")
end

# TODO write a pretty print function for exprs
# TODO write a print to file for verilog