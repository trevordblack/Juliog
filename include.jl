<<<<<<< HEAD
include("D:/Box Sync/git/Juliog/JuliogParameterize.jl")
include("D:/Box Sync/git/Juliog/JuliogSanitize.jl")
include("D:/Box Sync/git/Juliog/JULIOGtoVerilog.jl")
#include("D:/Box Sync/git/Juliog/JULIOGtoJulia.jl")
include("D:/Box Sync/git/Juliog/Juliog.jl")
include("D:/Box Sync/git/Juliog/mixer.jl")

loadJULIOGexpr(mixer)
#@block MULT_3M5A "M" (DO, DI_X, DI_Y ; WL_X=10, WL_Y=10)
@block SINCOS "SC" (COS, SIN, X)
#@block MIXER "mixer" (DO, DI, THETA, ENAB, CLK, RST ; WL=10, PL=2)

=======
include("D:/Box Sync/git/Juliog/JuliogParameterize.jl")
include("D:/Box Sync/git/Juliog/JuliogSanitize.jl")
include("D:/Box Sync/git/Juliog/JULIOGtoVerilog.jl")
#include("D:/Box Sync/git/Juliog/JULIOGtoJulia.jl")
include("D:/Box Sync/git/Juliog/Juliog.jl")
include("D:/Box Sync/git/Juliog/mixer.jl")

loadJULIOGexpr(mixer)
#@block MULT_3M5A "M" (DO, DI_X, DI_Y ; WL_X=10, WL_Y=10)
@block SINCOS "SC" (COS, SIN, X)
#@block MIXER "mixer" (DO, DI, THETA, ENAB, CLK, RST ; WL=10, PL=2)

>>>>>>> af2b9d2b252b71a2344fb523c72d7fea2e38ef55
println("At end of include")