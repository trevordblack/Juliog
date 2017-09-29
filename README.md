Juliog
===
Open Source Verilog Based Hardware Description Language Written in the Julia Programming Language



LOADING A JULIOG FUNCTION INTO JULIA
---

Juliog functions cannot be directly parsed into the julia command-line or your operating system's command console.
They must first be parsed through a preprocesser to sanitize the syntax and convert the (julia-esque) syntax to genuinely runnable julia code

There are 3 ways to input juliog code for loading

1) Call the parsefile function on a juliog file of interest

   ```julia
   julia> func = parsefile(file_dir)
   ```

   where file_dir is the file location as a string of where the juliog function is found

   ```julia
   julia> file_dir = "C:/Users/Trevor/Documents/full_adder.jl"
   julia> func = parsefile(file_dir)
   ```

2) Through a blocked expression

   ```julia
   julia> func = :( 
	   function example(example_input, example_output)
	    	# example implementation
	    end
   )
   ```

3) Through a quoted expression

   ```julia
   julia> func = quote 
	   function example(example_input, example_output)
		   # example implementation
	   end
   end
   ```

Then once the Juliog has been entered into Julia as an Expr, run loadJULIOGexpr

```julia
julia> loadJULIOGexpr(func)
```

Where func is the name of the inputted expression

Then, for preprocessing, run @block

```julia
julia> @block example "Arbitrary Block Name" (example_in, example_out)
```

Where `:example` is the name of the hardware function, `"Arbitrary Block Name"` is the arbitary name of the hardware block implementation, and `the Tuple` contains the names of testbench wires and parameters.


JULIOG SYNTAX
---

### How to set parameters
	
There are 4 ways to set parameters to a hardware design function

1) Setting a local parameter

   Behaves identically to  `localparm` in Verilog  
   Just call an assignment within a juliog function.  
   This cannot be overwritten at a higher level.

   ```julia
	   julia> this_param = 5
   ```

2) Passing a parameter through function interface

   Behaves identically to `parameter` in Verilog.  
   If your hardware function has keywords they can be overwritten.

   ```julia
       julia> function LOGIC(OUT, IN ; passed_param = 8)
		   # LOGIC implementation
	   end
   ```

   This then is called from above by:

   ```julia
	   julia> @block LOGIC "Clever_Name" (OUT_wire, IN_wire ; passed_param = 16)
   ```

   Where for the LOGIC hardware function, the passed_param has been overwritten.

3) Importing a modular parameter
	
   First create a module of parameters, likely in your command-line or an include file.

   ```julia
   julia> module my_parameters
	   word_length   = 32 
	   nibble_length = 4
   end
   ```

   then import the module in your hardware function

   ```julia
   julia> function LOGIC(OUT, IN)
	   import my_parameters
	   # LOGIC implementation
   end
   ```

   Alternatively, individual parameters can be requested

   ```julia
   julia> function LOGIC(OUT, IN)
	   import my_parameters.word_length
	   import my_parameters.nibble_length
   end
   ```

   This follows the Julia Module syntax, see [Julia Stable Modules](https://docs.julialang.org/en/stable/manual/modules/)

4) Create a global parameter

   This behaves similarly to #define in Verilog.

   You can just set a large portion of your design according to a specific global parameter, greatly reducing code complexity.

   ```julia
   julia> function LOGIC(OUT, IN)
	   global global_param
	   # LOGIC implementation
   end
   ```

   Then, somewhere in the testbench, the console command-line, or an include file:
  	
   ```julia
	   julia> global global_param = 16
   ```

   The parameterization step of preprocessing will take care the rest.


### How to create a wire

There are 5(+1) ways to create a wire

1) Create a wire of indeterminate bit length (not yet supported)

   ```julia
   julia> indet_wire = Wire()
   ```

2) Create a wire of bit length 1

   ```julia
   julia> bit_wire = Wire()[a] 
   ```

   where a is a non-negative Int


3) Create a wire of bit length 1 or greater

   ```julia
   julia> bus_wire = Wire()[a:b]
   ```

   where a and b are non-negative Ints.

   a and b can be the same number, i.e. bit length of 1.

   both endians accepted:  
   Either a or b can be greater than the other.

4) Assign a value to an undefined variable name

   ```julia
   julia> isdefined(:new_wire) # this returns false
   julia> new_wire = A & B # the := can also be used here 
   ```

   The bit length of the new_wire will be determined by the bit length of the wire that the right hand side solves to.
   For this example the bit length would be that of A and B


5) Assign a value to an undefined variable name of determinate bit length

   ```julia
   julia> isdefined(:new_wire) # this returns false
   julia> new_wire[7:0] = A & B # the := can also be used here 
   ```

6) Maybe a vcat or a tuple (not yet implemented)

   ```julia
   julia> [cout ; sum] := A + B
   julia cout, sum := A + B
   ```

Output and input creation only allows for 1-3 above:

```julia
julia> indet_output = Output()
julia> indet_input  = Input()
julia> bit_output   = Output()[a]
julia> bit_input    = Input()[a]
julia> wire_input    = Input()[a:b]
julia> wire_output   = Output()[a:b]
```


### Higher Dimensionality Wires (in progress, but not yet complete, do not use)

* This section needs fleshing out  
* Mention difference between Julia matrix syntax and verilog bus syntax

Just like any other higher-order programming language, Julia supports multidimentional arrays.

Juliog extends this functionality for the creation of multi-dimensional wires.
		
Multi-dimensional wires are commonly refered to as buses in Verilog parlance.

Buses of indeterminate width are not allowed, but the wires within can still be indeterminate.

```julia
julia> bus_bit_wires   = Wire()[a][c:d]
julia> bus_wires       = Wire()[a:b][c:d]
julia> bus_indet_wires = Wire()[][c:d]
```

The same is also capable for inputs and outputs, using same syntax

```julia
julia> bus_bit_inputs    =  Input()[a][c:d]
julia> bus_inputs        =  Input()[a:b][c:d]
julia> bus_bit_outputs   = Output()[a][c:d]
julia> bus_outputs       = Output()[a:b][c:d]
```

### Wire Assignments

Can be accomplished in 1 of 3 seperate ways

1) using equals operator (=) after wire creation

   ```julia
   julia> created_wire = Wire()
   julia> created_wire = A & B
   ```

2) using colon-equals operator (:=) after wire creation

   ```julia
   julia> created_wire = Wire()
   julia> created_wire := A & B
   ```

    Note that this is functionally equivalent to using the = operator at the gate level
	
    The = operator is converted to the := operator in preprocessing and the := is ultimately used for assignment once converting to Verilog and Julia

     A reason the designer may choose to use := over = is for ease of code clarity, keeping assignments as := may improve code legibility

3) Using = or := to declare an as of yet undeclared wire

   ```julia
   julia> undeclared_wire = A & B
   # OR
   julia> undeclared_wire := A & B
   ```

A wire can also be assigned to a constant value

But only after it is already created, otherwise the wire will be replaced through out the codebase with your static value

```julia
julia> const_25 = Wire()
julia> const_25 = 25
```

Whereas the following will not create a wire, but will create a parameter:

```julia
julia> const_25 = 25
```

* Add reverse indexing explanation


### Bit indexing

Indexing a wire on the right hand side of = or := is identical to verilog syntax

```julia
julia> word = Input()[7:0]
julia> upper_nibble = word[7:4]
julia> lower_nibble = word[3:0]
julia> one_bit = word[7]
```

Of course, the colon-equals operator is also fine

```julia
julia> word = Input()[7:0]
julia> upper_nibble := word[7:4]
julia> lower_nibble := word[3:0]
julia> one_bit := word[7]
```

### Bit(s) Assignment

The bits of a wire can be assigned on the left hand side
	
But only for a wire which has already been created

```julia
julia> upper_nibble = Input()[3:0]
julia> lower_nibble = Input()[3:0]
julia> nibbles = Wire()[7:0]
julia> nibbles[7:4] = upper_nibble
julia> nibbles[3:0] = lower_nibble
```

The following two examples would also be accepted:

```julia
julia> upper_nibble = Input()[3:0]
julia> lower_nibble = Input()[3:0]
julia> nibbles = Wire()[7:0]
julia> nibbles[7:4] = upper_nibble[3:0]
julia> nibbles[3:0] = lower_nibble[3:0]	
```

```julia
julia> upper_nibble = Input()[3:0]
julia> lower_nibble = Input()[3:0]
julia> nibbles = Wire()[7:0]
julia> nibbles[7:4] := upper_nibble[3:0]
julia> nibbles[3:0] := lower_nibble[3:0]	
```

Note that again, the := operator is acceptable for assignment. It is, not, however acceptable to use a := operator for Wire or I/O creation. The = operator is exclusive for that operation.


Note also, that the following is NOT accepted, since nibbles was not previously created:

```julia
julia> upper_nibble = Input()[3:0]
julia> lower_nibble = Input()[3:0]
julia> nibbles[7:4] = upper_nibble # Throws an Error
julia> nibbles[3:0] = lower_nibble # Throws an Error
```

In this example, we are attempting to write to bits which we are not certain actually exist. There is a means by which this could be acceptable, but in the Juliog language, we ban it outright. Writing to specific bits of wires is only allowed if the wire is created *A Priori*.

### Bit Concatentation

The bits of any two or more wires can be concatenated in the following manner

```julia
julia> combined = [a ; b]     # for 2 wires
julia> combined = [a ; b ; c] # for 3 wires
julia> # can be extended for any number of wires
```

The wires of interest can, of course, be the indexed bit(s) of a larger wire

```julia
julia> combined = [a[3:0] ; a[1:0] ; b[5:0]]
```

### Bit Repetition

A wire's bit(s) can be concatenated to itself a set number of times

```julia
julia> bit_repeats = a(repeats)
julia> other_bit_repeats = a[3:0](repeats)
```

Where a is a wire, and repeats is an integer

These can also be concatenated just as above:

```julia
julia> complicated = [ a(repeats) ; a[1:0](8) ; b[1:0] ]
```

### Supported Logic Functions

```
&   - AND
|   - OR
~   - NOT
+   - ADD
-   - SUB
*   - MULT
/   - DIV
%   - REM
==  - Equivalence
!=  - Non-Equivalence
>   - Greater than
<   - Lesser than
>=  - Greater than or equal to
<=  - Lesser than or equal to
<<  - Shift Left
>>  - Logical Shift Right

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
```

Unitary & and | not yet supported, support is in decision


### Instantiating Children Hardware functions

```julia
julia> :(
	function LOGIC(OUT, IN)
	# LOGIC implementation

	@block CHILD_LOGIC "the_child_logic" (ol_output, my_val)

	# More LOGIC implementation
	end
)
```

Strings in block names enable interpolation, which can then be used to dynamically change name at compile time:

```julia
julia> :(
	function LOGIC(OUT, IN)
	# LOGIC implementation

	for i = 1:n
		@block CHILD_LOGIC "child_logic_$(i)" (ol_output[i], my_val)
	end

	# More LOGIC implementation
	end
)
```


### if-else constructs

At the parameterization stage, any variables will be replaced with their constant values.

Any statically defined if conditions will reduce to either `true` or `false` at compile time. If the condition reduces to the static Bool `true` then the contents of the if block will be raised to the level of the if statement, the condition will be removed, and the else block will be removed. For an if statment in the function block, the if block will be raised to function block; for a nested if statement, the nested if will be raised to the parent if statement. If the condition is reduced to a static Bool `false` then the contents of the else block will be raised, the if block will be removed, and the condition will be removed. Should no else condition exist, then nothing will be raised, and the entire if statement will be removed. 


```julia
julia> :(
	architecure = "Accumulating"
	if architecture == "Accumulating"
		# Accumulating architecture code
	else
		# Non accumulating architecture code
	end
)
```

When the parameter (can also be referred to as a local variable) :architecture is defined to be "Accumulating" the block will be reduced to the following:

```julia
julia> :(
	if true
		# Accumulating architecture code
	else
		# Non accumulating architecture code
	end
)
```

And, ultimately:

```julia
julia> :(
	# Accumulating architecture code
)
```


For the if statement condition which is not statically defined (i.e. dynamically defined in relation to a wire value) the if statement and all of its constituent parts (the if condition, the if block, and the else block should it exist) will be parameterized, but not raised, nor removed.

If the if statement can't be determined at compilation time
i.e. The if statement is determined by a wire:

```julia
julia> :(
	# nibble_index, out_wire, and value are created as wires
	if nibble_index == 0
		out_wire = value[3:0]
	else
		out_wire = value[7:4]
	end
)
```

Then the if statement will not be block-wise reduced as above.
Constants where applicable, even within the if block, will still be replaced.
And the if-else statement will be turned into a MUX at preprocessing time.


### Case Statements

Aren't supported natively in Julia, and are not supported here, as well.

Case statements are an additional abstraction which may never be necessary.

### for loops

Juliog can unroll for loops.

```julia
julia> :(
	# l is a parameter and equals 3; c, a, b are created as wires
	for i = 0:l
		c[i] = a[i] + b[i]
		# Other assignments
	end
)

```

At compile time, the static for condition will unroll the above to the following code snippet:


```julia
julia> :(
	c[0] = a[0] + b[0]
	# Other assignments
	c[1] = a[1] + b[1]
	# Other assignments
	c[2] = a[2] + b[2]
	# Other assignments
	c[3] = a[3] + b[3]
	# Other assignments
)

```


Supports 4 Syntaxes for the for condition:

```julia
julia> for i = 1:l
julia> for i = [1; 2; 4; 6; 27] # Vertical Concatenation
julia> for i = [1  2  4  6  27] # Horizontal Concatentation
julia> for i = [1, 2, 4, 6, 27] # Vectors
```

### Important Macros

```julia
@reg
```

Can be used to create any kind of register

```julia
@posedge
```

Can be used to create a posedge register (or a synchronously resetteble PR)

```julia
@negedge
```

Can be used to create a negedge register (or a synchronously resetteble NR)	

```julia
@async
```

Can be used to quote off specific block of functional asynchronous logic

```julia
@delay
```

Can be used to establish a delay for a specific Juliog assignment or lines of code

```julia
@block
```

Can be used to initialize a submodule

```julia
@verilog
```

Any string following @verilog will be unchanged and spit directly to Verilog

```julia
@julia
```

Any string following @julia will be unchanged and spit directly to Julia



### Creating Registers

The @posedge macro

```julia
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
```

The @negedge macro

```julia
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
```

The @reg macro

```julia
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
		if     CLK == 1
			Q = D
		elseif CLK == 0
			Q = D
		end
	end

	# for an async-reset posedge
	@reg begin
		if     RST == 1
			Q = 0
		elseif CLK = 1
			Q = D
		end
	end
)
```

### Creating Latches

Use an if-else or a ternary operation to create latches

```julia
julia> :(
	# pass, D, and Q created as wires

	if   pass == 1
		D = Q
	else
		D = D
	end
)
```

Or with the ternary operation:


```julia
julia> :(
	# pass, D, and Q created as wires

	D = (pass == 1) ? Q : D
)
```

Just like Verilog, Juliog supports "accidentally" creating latches:

```julia
julia> :(
	# pass, D, and Q created as wires

	if pass == 1
		D = Q
	end
)
```

Note that the sanitization stage of preprocessing will warn you of the accidental latch. The explicit latch created by the other two examples will NOT warn you.


### Creating Delays

Use the @delay macro

```julia
@delay floating_point assignment
```

The number must be represented as a floating point number.

e.g. for a delay of 5

```julia
julia> :(
	@delay 5.0  A := B[3:0]
	# OR
	@delay 5.0 begin
		A := B[3:0]
	end
)
```


### Difference between logic inside and outside @async call

Logic can be established inside a seperate @async macro

```julia
julia> :(
	@async begin
		A := B[3:0]
	end
)
```

Any logic included inside of an @async block is indistinguishable from logic outside of an @async block. So the following example is logically equivalent to the above example:

```julia
julia> :(
	A := B[3:0]
)

```

However, the reason for its inclusion is

1) Aid in code clarity
2) Has specific impacts on the conversion to verilog


### Inclusion of Don't Cares and High Impedances

They are in here, but at present, are dumb. They only exist to aid in simulation.
They can't be used to certifiably debug code, but their inclusion may help you catch some architecture problems. You should check parity with the testbench for complete debugging. 

```julia
julia> A = Wire()[0]
julia> A := 'x'
julia> A := 'z'
```

### Driving the same wire by multiple logic calls

Is possible, will fuck up your shit.  
Don't assign to the same bits more than once.  
I am in the process of checking for this. But it isn't certain yet.  

CONVERSION TO VERILOG
---

Occurs after the parameterization and sanitization steps of preprocessing.

The @async macro does three things:
1) @async macro calls are directly converted into always @* function calls in verilog
2) Any wire assigned within an @async macro will be converted to a reg
3) Any if-else statements inside of and @async will remain an if-else statement inside an always block, whereas if-elses outside @async will be turned into ? : calls

The reason it might be desirable to use or not use @async macros is due to the intended hardware.

+ FPGA compilation tends to improve with explicit ? : Mux calls, due to the poor quality of FPGA compilation software. Therefore, the @async macro may not be desired

+ ASIC compilation is done in Design Compiler, where the existence of always blocks versus ? : Mux calls is fairly insubstantial.

+ The @async macro can be also used as a style choice

CURRENT RELEASE
---

### Noticable Absences from the 0.1 release

+ Julia Simulation only works on 64 bit machines, with the 64 bit installation of Julia. Preprocessing, and conversion to Verilog does not carry this constraint
+ Absence of smart +, -, *, /, remainder
+ Matrix or Bus notation
+ Working ifs, registers of any kind


NEXT UPDATE FUNCTIONALITY
---

+ Tuples and vcats on left hand side of equations

+ Julia Matrix Notation and Verilog Bus Notation

+ Supports writing values to ints, as opposed to vcat with 0s and 1s

+ nonblocking operator <= is less than equal operator in Julia, consider changing

+ if statements support differing left hand side assignments. At present, the lhs side of any statement in an if block has a dumb way of matching.


POTENTIAL FEATURES
---

+ Polymorphic Julia code (Write Once)

+ Combinational Reductions:
    
  Trace a path of operations e.g. [& & | + - ^] from input to reg, reg to reg, reg to output have a list of combinational reduction equivalences

+ Flatten function:

  Removes any hierarchy from function, unrolls everything into top level

+ Lossless bitlength decisions, Lossy bit length decisions

  Intelligent and Power-saving bitlength decisions. Wires of indeterminate bitlength act as indicators for programming.

+ Instances of algorithmic equivalences

  For a defined set of functions and a finite input set, algorithmic equivalence can be defined. A defined set of equivalent functions can be extrapolated to solve for equivalent algorithm for a defined algorithm.

+ Generalized Hardware Programmability

  Given a "program" to map to hardware, and a complete description of the programmable hardware, a generalized program can be written which tells you: One, if the program can be successfully mapped to the programmable hardware, and two, a generalized--if potentially very inefficient--means to map the program onto the hardware.

+ Reversible logic so simulation can be played forward/backwards
+ Visual graph which shows i.r.t what wire values are

+ CPU emulation running alongside Hardware simulation
+ Multithreaded Simulation
+ Vulkan-accelerated Simulation

+ Synthesis
+ Vulkan-accelerated Synthesis
+ SPICE integration
+ Stochastic delay modelling
+ Easy Monte-Carlo simulations


TEST BENCH CONSTRUCTION
---

W.I.P.
