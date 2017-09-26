## Juliog
Open Source Verilog Based Hardware Description Language Written in the Julia Programming Language



#LOADING A JULIOG FUNCTION INTO JULIA
-----------------------------------------------------------------------------------

Juliog functions cannot be directly parsed into the julia command-line or your operating system's command console.
They must first be parsed through a preprocesser to sanitize the syntax and convert the (julia-esque) syntax to genuinely runnable julia code

There are 3 ways to input jg code for preprocessing

1) Call the parsefile function on a juliog file of interest

	```
	julia> func = parsefile(file_dir)
	```
	
	where file_dir is the file location as a string of where the juliog function is found

	```
	julia> file_dir = "C:/Users/Trevor/Documents/full_adder.jl"
	julia> func = parsefile(file_dir)
	```

2) Through a blocked expression
```
	julia> func = :( 
		function example(example_input, example_output)
			# example implementation
		end
	)

3) Through a quoted expression
	julia> func = quote 
		function example(example_input, example_output)
			# example implementation
		end
	end

Then run preprocess on the returned function block
	julia> preprocessed_func = preprocess(func)

This will return an expression which contains runnable julia code
	to run this code, use
	julia> eval(preprocessed_func) 




JULIOG SYNTAX
-----------------------------------------------------------------------------------

How to set parameters
	There are 4 ways to set parameters to a hardware design function

1) Setting a local parameter
	e.g. localparm in verilog
	Just by calling an assignment within a juliog function
		julia> this_param = 5
	Can't be overwritten at a higher level

2) Passing a parameter through function interface
	if your hardware function has keywords they can be overwritten
	e.g.
		julia> function LOGIC(OUT, IN ; passed_param = 8)
			# LOGIC implementation
		end
		This then is called from above by:
		julia> @block LOGIC "Clever_Name" (OUT_wire, IN_wire ; passed_param = 16)
		Where for the LOGIC hardware function, the passed_param has been overwritten

3) Importing a modular parameter
	First create a module of parameters
		julia> module my_parameters
			word_length   = 32 
			nibble_length = 4
		end
	then import the module in your hardware function
		julia> function LOGIC(OUT, IN)
			import my_parameters
			# LOGIC implementation
		end
	Alternatively, individual parameters can be requested
		julia> function LOGIC(OUT, IN)
			import my_parameters.word_length
			import my_parameters.nibble_length
		end

4) Create a global parameter
	e.g. #define in Verilog
	Big advantage over verilog
	You can just set a large portion of your design according to a specific global param
	Greatly reducing code complexity
		julia> function LOGIC(OUT, IN)
			global global_param
			# LOGIC implementation
		end
	Then, somewhere in the testbench, or in the console command-line
		julia> global global_param = 16
	The parameterization step of preprocessing will take care the rest





How to create a wire
	There are 5 ways to create a wire

1) Create a wire of indeterminate bit length (not yet supported)
	julia> indet_wire = Wire()
2) Create a wire of bit length 1
	julia> bit_wire = Wire()[a] 
		where a is a non-negative Int
3) Create a wire of bit length 1 or greater
	julia> bus_wire = Wire()[a:b]
		where a and b are of type Int
		both are non-negative
		a and b can be the same number, e.g. bit length of 1
		both endians accepted:
			Either a or b can be greater than the other
4) Assign a value to an undefined variable name
	julia> isdefined(:new_wire) # this returns false
	julia> new_wire = A & B # the := can also be used here 
	The bit length of the new_wire will be determined by the bit length
		of the wire that the right hand side solves to (e.g. bit length of A and B)
5) Assign a value to an undefined variable name of determinate bit length
	julia> isdefined(:new_wire) # this returns false
	julia> new_wire[7:0] = A & B # the := can also be used here 
6) Maybe a vcat or a tuple (not yet implemented)
	julia> [cout ; sum] := A + B
	julia cout, sum := A + B

output and input creation only allows for 1-3 above:
	i.e.
	julia> indet_output = Output()
	julia> indet_input  = Input()
	julia> bit_output   = Output()[a]
	julia> bit_input    = Input()[a]
	julia> wire_input    = Input()[a:b]
	julia> wire_output   = Output()[a:b]

Higher Dimensionality Wires (in progress, but not yet complete, do not use)
# TODO mention difference between Julia matrix syntax and verilog bus syntax
	Just like any other higher-order programming language, Julia supports multidimentional arrays
	JADE extends this functionality for the creation of multi-dimensional wires
		Multi-dimensional wires are commonly refered to as buses in Verilog parlance
	Buses of indeterminate width are not allowed,
		but the wires within can still be indeterminate 
		julia> bus_bit_wires   = Wire()[a][c:d]
		julia> bus_wires       = Wire()[a:b][c:d]
		julia> bus_indet_wires = Wire()[][c:d]
The same is also capable for inputs and outputs, using same syntax
	julia> bus_bit_inputs    =  Input()[a][c:d]
	julia> bus_inputs        =  Input()[a:b][c:d]
	julia> bus_bit_outputs   = Output()[a][c:d]
	julia> bus_outputs       = Output()[a:b][c:d]

Wire Assignments
	Can be accomplished in 1 of 3 seperate ways
	1) using = operator after wire creation
		julia> created_wire = Wire()
		julia> created_wire = A & B
	2) using := operator after wire creation
		julia> created_wire = Wire()
		julia> created_wire := A & B
		Note that this is functionally equivalent to using the = operator at the gate level
			The = operator is converted to the := operator in preprocessing
			and the := is ultimately used for conversion to gate-level
		A reason the designer may choose to use := over = is for ease of code clarity
			keeping assignments as := may improve code legibility
	3) Using = or := to declare an as of yet undeclared wire
		julia> undeclared_wire = A & B
		OR
		julia> undeclared_wire := A & B

	A wire can also be assigned to a constant value
	But only after it is already created, otherwise the wire will be replaced through out the codebase with your static value
		julia> const_25 = Wire()
		julia> const_25 = 25



TODO Add reverse indexing explanation
Bit indexing
	Indexing a wire on the right hand side of = or := is identical to verilog syntax
	julia> word = Input()[7:0]
	julia> upper_nibble = word[7:4]
	julia> lower_nibble = word[3:0]
	Alternatively, the following is also fine
	julia> word = Input()[7:0]
	julia> upper_nibble := word[7:4]
	julia> lower_nibble := word[3:0]	

Bit(s) Assignment
	The bits of a wire can be assigned on the left hand side
		But only for a wire which has already been created
	julia> upper_nibble = Input()[3:0]
	julia> lower_nibble = Input()[3:0]
	julia> nibbles = Wire()[7:0]
	julia> nibbles[7:4] = upper_nibble
	julia> nibbles[3:0] = lower_nibble
	The following would also be accepted
	...
	julia> nibbles[7:4] = upper_nibble[3:0]
	julia> nibbles[3:0] = lower_nibble[3:0]	

	But the following is NOT accepted, since nibbles was not previously created
	julia> upper_nibble = Input()[3:0]
	julia> lower_nibble = Input()[3:0]
	julia> nibbles[7:4] = upper_nibble
	julia> nibbles[3:0] = lower_nibble

Bit Concatentation
	the bits of any two or more wires can be concatenated in the following mannor
	e.g.
		julia> combined = Wire()
		julia> combined = [a ; b]     # for 2 wires
		julia> combined = [a ; b ; c] # for 3 wires
		julia> # can be extended for any number of wires
	The wires of interest can, of course, be the indexed bit(s) of a larger wire
		julia> combined = [a[3:0] ; a[1:0] ; b[5:0]]

Bit Repetition
	A wire's bit(s) can be concatenated to itself a set number of times
	e.g.
		julia> bit_repeats = a(repeats)
			where a is a wire, and repeats is an integer
	These can also be concatened just as above
		julia> complicated = [ a(repeats) ; a[1:0](8) ; b[1:0] ]

Supported Logic Functions
	& - AND
	| - OR
	~ - NOT
	+ - ADD
	- - SUB
	* - MULT
	/ - DIV
	% - REM
	== - Equivalence
	!= - Non-Equivalence
	>  - Greater than
	<  - Lesser than
	>= - Greater than or equal to
	<= - Lesser than or equal to
	<< - Shift Left
	>> - Logical Shift Right
	>>> - Arithmetic Shift Right
		An important note about the shift right operations
		The >>> in Julia is the logical shift right
		The >> in Julia is the arithmetic shift right
		This is opposite in Verilog, and so JG code follows the verilog convention
		Outside of JG, file, they will be in the julia convention
		BE CAREFUL.
	^ - XOR
		An important note about the xor operation:
		The xor function in Julia is called by xor(num, other_num)
		The ^ operator is reserved for the power function
			e.g. 2 ^ 5 => 32
		So in preprocessing, the ^ op is replaced by a xor function call
		Outside of JG file, the ^ op will act as a power operator
		BE CAREFUL.
	? : - MUX
		An imporant note about the ? : operation
		the ? : op is parsed in julia into an if-else statement
		It is therefore completely indistinguishable from an if-else statement
	Latch - through special logic see below
	Reg   - through special logic see below

	Unitary & and | not yet supported, support is in decision


Instantiating other hardware functions
	julia> :(
		function LOGIC(OUT, IN)
		# LOGIC implementation

		OTHER_LOGIC the_other_logic (ol_output, my_val)

		# More LOGIC implementation
		end
	)

	Can also be named by a string
	julia> :(
		function LOGIC(OUT, IN)
		# LOGIC implementation

		OTHER_LOGIC "the_other_logic" (ol_output, my_val)

		# More LOGIC implementation
		end
	)
	Strings may be preferred because interpolation can be used to dynamically change name
	e.g.
	julia> :(
		function LOGIC(OUT, IN)
		# LOGIC implementation

		for i = 1:n
			OTHER_LOGIC "logic_$(i)" (ol_output[i], my_val)
		end

		# More LOGIC implementation
		end
	)




if-else constructs
	At the parameterization stage,
		any variables will be replaced with their constant values
	And, for the if statements which can be determined at compilation, they will
	e.g.
		julia> :(
			architecure = "Accumulating"
			if architecture == "Accumulating"
				# Accumulating architecture code
			else
				# Non accumulating architecture code
			end
		)
	Will be subbed for
		julia> :(
			if true
				# Accumulating architecture code
			else
				# Non accumulating architecture code
			end
		)
	And, finally
			julia> :(
			# Accumulating architecture code
		)

	If the if statement can't be determined at compilation time
		e.g. the if statement is determined by a wire
			julia> :(
				# nibble_index, out_wire, and value are created as wires
				if nibble_index == 0
					out_wire = value[3:0]
				else
					out_wire = value[7:4]
				end
			)
			if nibble_index == 0
		Then the if statement will not be block-wise reduced as above
		Constants where applicable, even within the if block, will still be replaced
		And the if-else statement will be turned into a MUX at preprocessing time

# TODO write about the two possible if condition syntaxes: Julia and Verilog

Case Statements
	Aren't supported, sorry

for loops
	Juliog can unroll for loops

	Supports 4 Syntaxes

	julia> for i = 1:l
	julia> for i = [1; 2; 4; 6; 27]
	julia> for i = [1  2  4  6  27]
	julia> for i = [1, 2, 4, 6, 27]

Important Macros
	@reg
		can be used to create any kind of register
	@posedge
		can be used to create a posedge register (or an asynchronously resetteble PR)
	@negedge
		can be used to create a negedge register (or an asynchronously resetteble NR)	
	@async
		can be used to quote off specific block of functional asynchronous logic
	@delay
		can be used to establish a delay for a specific Juliog assignment or lines of code
	@block
		can be used to initialize a submodule
	@verilog
		Any string following @verilog will be unchanged and spit directly to Verilog
	@julia
		Any string following @julia will be unchanged and spit directly to Julia

Creating Registers
The @posedge macro
	e.g.
	julia> :(
		# CLK, D, Q created as wires

		@posedge CLK begin
			Q <= D
		end

		# Alternatively
		@posedge CLK begin
			Q = D
		end
	)

The @negedge macro
	e.g.
	julia> :(
		# CLK, D, Q created as wires

		@negedge CLK begin
			Q <= D
		end

		# Alternatively
		@negedge CLK begin
			Q = D
		end
	)


The @reg macro
	e.g.
	julia> :(
		# RST, CLK, D, Q created as wires

		# for a posedge
		@reg begin
			if CLK == 1
				Q = D
			end
		end

		# for a negedge
		@reg begin
			if CLK == 0
				Q = D
			end
		end

		# for a double-edged
		@reg begin
			if CLK == 1
				Q = D
			elseif CLK == 0
				Q = D
			end
		end

		# for an async-reset posedge
		@reg begin
			if RST == 1
				Q = 0
			elseif CLK = 1
				Q = D
			end
		end
	)


Creating Latches
	Use a if-else or ternary op to create latches
	e.g.
		julia> :(
			# pass, D, and Q created as wires

			if   pass == 1
				D = Q
			else
				D = D
			end
		)
	OR, e.g.
		julia> :(
			# pass, D, and Q created as wires

			D = (pass == 1) ? Q : D
		)



Creating Delays
	use the @delay macro
	syntax:
		@delay number assignment
	The number must be represented as a floating point number
	e.g. for a delay of 5
		julia> :(
			@delay 5.0  A := B[3:0]
			# OR
			@delay 5.0 begin
				A := B[3:0]
			end
			# OR
			@delay 5.0 quote
				A := B[3:0]
			end
		)


Difference between logic inside and outside @async call
	Logic can be established inside a seperate @async macro
	e.g.
		julia> :(
			@async begin
				A := B[3:0]
			end
		)
	Any logic included inside of an @async block is indistinguishable from logic outside of an @async block
	However,
	The reason for its inclusion is
	1) Aid in code clarity
	2) Has specific impacts on the conversion to verilog

Conversion to Verilog
	Occurs after parameterization
	the @async macro does two things
		1) @async macro calls are directly converted into always @* function calls in verilog
		2) any wire assigned within an @async macro will be converted to a reg
		3) Any if-else statements inside of and @async will remain an if-else statement inside an always block, whereas if-elses outside @async will be turned into ? : calls
	The reason it might be desirable to use or not use @async macros is due to the intended hardware
		FPGA compilation tends to improve with explicit ? : Mux calls, due to the poor quality of FPGA compilation software
			Therefore, the @async macro may not be desired
		ASIC compilation is done in dc_shell, where the existence of always blocks rather than ? : Mux calls is fairly insubstantial
	The @async macro can be used as a style choice



Inclusion of Don't Cares and High Impedances
	They are in here, but at present, are dumb. They only exist to aid in simulation.
	They can't be reasonably used to debug code, you should check parity with the testbench for that one. 
	julia> A = Wire()[0]
	julia> A := 'x'
	julia> A := 'z'


Noticable Absences from the 0.1 release
	only works on 64 bit machines
	Absence of smart +, -, *, /, remainder


Driving the same wire by multiple logic calls
	Is possible, will fuck up your shit.
	don't assign to the same bits more than once.
	I am in the process of checking for this. But it isn't certain yet.


MOONSHOOT Stuff
------------------------------------------------------------------------------------
Combinational Reductions
    trace a path of operations e.g. [& & | + - ^] from input to reg, reg to reg, reg to output
    have a list of combinational reduction equivalences

    The program will still run if no combinational reductions are made
    the first juliog simulator will not include these things

Flatten function
    Removes any hierarchy from function, unrolls everything into top level
    Not necessary, but can be convienent


NEXT UPDATE FUNCTIONALITY
-----------------------------------------------------------------------------------
#TODO Tuples and vcats on left hand side of equations

#TODO Julia Matrix Notation and Verilog Bus Notation

#TODO Supports writing values to ints, as opposed to vcat with 0s and 1s

#TODO nonblocking operator <= is less than equal operator in Julia, consider changing


DATA FLOW GRAPHS
------------------------------------------------------------------------------------

Atomic units





TEST BENCH CONSTRUCTION
-----------------------------------------------------------------------------------



POTENTIAL FEATURES
-----------------------------------------------------------------------------------
Polymorphic Matlab code (Write Once)
Combinational Reduction
Instances of algorithmic equivalences
Intelligent and Power-saving bitlength decisions
Atomic Units that print whenever a truncation has occurred
	that keep track of bits flipped for power consumption
Reversible logic so simulation can be played forward/backwards
Visual graph which shows i.r.t what wire values are
Recursion
Multithreaded simulation
	Determine trees of dependency, use to maximize multithreads
Vulkan-accelerated xtor gate list
	setup/hold times calculations can be SIMD
CPU emulation running alongside Hardware simulation
SPICE integration
Stochastic delay modelling
Easy Monte-Carlo simulations
