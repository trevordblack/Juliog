include("D:/Box Sync/git/Juliog/JuliogParameterize.jl")
include("D:/Box Sync/git/Juliog/JuliogSanitize.jl")
#include("D:/Box Sync/git/Juliog/JuliogSanitizeif.jl")
include("D:/Box Sync/git/Juliog/JuliogSanitizemacro.jl")
include("D:/Box Sync/git/Juliog/JULIOGtoVerilog.jl")
#include("D:/Box Sync/git/Juliog/JULIOGtoJulia.jl")
include("D:/Box Sync/git/Juliog/Juliog.jl")
include("D:/Box Sync/git/Juliog/mixer.jl")

#loadJULIOGexpr(mixer)
#@block MULT_3M5A "M" (DO, DI_X, DI_Y ; WL_X=10, WL_Y=10)
#@block SINCOS "SC" (COS, SIN, X)
#@block MIXER "mixer" (DO, DI, THETA, ENAB, CLK, RST ; WL=10, PL=2)


println("At end of include")