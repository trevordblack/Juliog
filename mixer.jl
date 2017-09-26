mixer = quote
function MULT_3M5A(DO, DI_X, DI_Y; WL_X = 8, WL_Y = 8)
    WL_O = WL_X + WL_Y

    DO   = Output()[2*WL_O-1:0]
    DI_X =  Input()[2*WL_X-1:0]
    DI_Y =  Input()[2*WL_Y-1:0]

    A  := DI_X[2*WL_X-1:WL_X]
    B  := DI_X[  WL_X-1:   0]
    C  := DI_Y[2*WL_Y-1:WL_Y]
    D  := DI_Y[  WL_Y-1:   0]

    # (a+jb)(c+jd) = [c(a-b) + b(c-d)] + j[d(a+b) + b(c-d)]
    AmB_t[WL_X:0] := [A[WL_X-1] ; A] - [B[WL_X-1] ; B] # A minus B
    ApB_t[WL_X:0] := [A[WL_X-1] ; A] + [B[WL_X-1] ; B] # A plus B
    CmD_t[WL_Y:0] := [C[WL_X-1] ; C] - [D[WL_X-1] ; D] # C minus D

    CtAmB_t[WL_O-1:0] := [C[WL_Y-1](WL_O-WL_Y) ; C] * [AmB_t[WL_X](WL_O-WL_X-1) ; AmB_t]
    # C times A minus B
    DtApB_t[WL_O-1:0] := [D[WL_Y-1](WL_O-WL_Y) ; D] * [ApB_t[WL_X](WL_O-WL_X-1) ; ApB_t]
    # D times A plus B
    BtCmD_t[WL_O-1:0] := [B[WL_X-1](WL_O-WL_X) ; B] * [CmD_t[WL_Y](WL_O-WL_Y-1) ; CmD_t]
    # B times C minus D

    DO_RE[WL_O-1:0] := CtAmB_t + BtCmD_t
    DO_IM[WL_O-1:0] := DtApB_t + BtCmD_t

    DO := [DO_RE ; DO_IM]
end

function SINCOS(COS, SIN, X)
    SIN = Output()[11:0]
    COS = Output()[11:0]
    X   =  Input()[13:0]

    X_w := (X[11] == 1) ? ~X[11:0] : X[11:0] #X_w[11] = 0.1250 *2pi ; X_w[10] = 0.0625 *2pi

    X_4x_w     := X_w
    X_9d2_w    := X_w + [0;0;0;X_w[11:3]]
    X_9d4_w    := [0; X_9d2_w[11:1]]
    X_9d8_w    := [0; X_9d4_w[11:1]]

    Tmp_Sin_w  := X_4x_w + ( (X_w[10] == 1) ? X_9d8_w : X_9d4_w )

    Sin_w = Wire()[10:0]
    Sin_w[ 3:0] := Tmp_Sin_w[4:1]
    Sin_w[10:4] := Tmp_Sin_w[11:5] + [X_w[10] ;0;0; X_w[10]]

    # Cosine Wave Synthesis
    Sin_3d4_w  := [0; Sin_w[10:1]] + [0;0; Sin_w[10:2]]
    Sin_3d8_w  := [0; Sin_3d4_w[10:1]] 
    Sin_3d16_w := [0; Sin_3d8_w[10:1]] 
    Sin_1d16_w := [0;0;0;0; Sin_w[10:4]]

    Mux_w = Wire()[1:0]
    Mux_w[1] := Sin_w[10] | Sin_w[9]
    Mux_w[0] := Sin_w[10] | (~Sin_w[9] & Sin_w[8])

    Tmp_Cos_r = Wire()[10:0]
    @async begin
        if     Mux_w == [0;0]
            Tmp_Cos_r = Sin_1d16_w
        elseif Mux_w == [0;1]
            Tmp_Cos_r = Sin_3d16_w
        elseif Mux_w == [1;0]
            Tmp_Cos_r = Sin_3d8_w
        elseif Mux_w == [1;1]
            Tmp_Cos_r = Sin_3d4_w
        end
    end

    Tmp_Cos_w := ~Tmp_Cos_r

    C_11_w := ( Mux_w[1]) & ( Mux_w[0])
    C_10_w := ( Mux_w[1]) & (~Mux_w[0])
    C_01_w := (~Mux_w[1]) & ( Mux_w[0])

    Cos_w       = Wire()[10:0]
    Cos_w[ 4:0] := Tmp_Cos_w[4:0]
    Cos_w[10:5] := Tmp_Cos_w + [0; C_11_w; 0; C_10_w; 0; C_01_w]

    # Quadratal Conversion
    Swap_w := X[12]^X[11] # if 0.125 <= X/2pi < 0.375, sin & cos are swaped
    NegS_w := X[13]       # if 0.500 <= X/2pi        , sin is negated
    NegC_w := X[13]^X[12] # if 0.250 <= X/2pi < 0.750, cos is negated

    Sin_Swp_w := Swap_w ? Cos_w : Sin_w # MSB: 2^-1 ; LSB: 2^-11 (No sign bit yet)
    Cos_Swp_w := Swap_w ? Sin_w : Cos_w # MSB: 2^-1 ; LSB: 2^-11 (No sign bit yet)

    SIN := NegS_w ? [1 ; ~Sin_Swp_w] : [0 ; Sin_Swp_w] # Add the sign bit
    COS := NegC_w ? [1 ; ~Cos_Swp_w] : [0 ; Cos_Swp_w] # Add the sign bit
end

function MIXER(DO, DI, THETA, ENAB, CLK, RST ; WL=10, PL=2)
    # "W"ord-"L"ength
    # "P"arallelism "L"evel (Can only be power of 2, and <= 16)
    
    CL=12    # "C"oefficient Word"L"ength

    DO    = Output()[2*WL-1:0]
    DI    = Input()[PL*WL*2-1:0]

    THETA = Input()[13:0]

    ENAB  = Input()[0]
    CLK   = Input()[0]
    RST   = Input()[0]

    DO_RE = Wire()[WL-1:0]
    DO_IM = Wire()[WL-1:0]

    DO    = [DO_RE ; DO_IM]

    DI_r  = Wire()[WL*2-1:0][PL-1:0]

    for i = 0:PL-1
        @posedge CLK begin
            if ENAB == 1
                b_s = WL*2*i
                b_e  = WL*2*(i+1) - 1
                DI_r[i] = DI[b_e:b_s]
            end
        end
    end

    Theta_r = Wire()[13:0]
    @reg begin
        if RST == 1
            Theta_r = 0
        elseif CLK == 1
            if ENAB == 1
                Theta_r = THETA
            end
        end
    end

    Acc_r  = Wire()[13:0] 
    @reg begin
        if RST == 1
            Acc_r = 0
        elseif CLK == 1
            if ENAB == 1
                Acc_r = Acc_r + (Theta_r << Int(log2(PL)))
            end
        end
    end

    cos_w = Wire()[CL-1:0][PL-1:0] 
    sin_w = Wire()[CL-1:0][PL-1:0] 
    cos_r = Wire()[CL-1:0][PL-1:0] 
    sin_r = Wire()[CL-1:0][PL-1:0] 
    re_w  = Wire()[WL+CL-1:0][PL-1:0] 
    im_w  = Wire()[WL+CL-1:0][PL-1:0]  

    if PL >= 4
        X3  = Wire()[13:0]    
        X3  = (Theta_r<<1) + Theta_r 
    end
    if PL >= 8
        X5  = Wire()[13:0]
        X7  = Wire()[13:0]
        X5  = (Theta_r<<2) + Theta_r
        X7  = (Theta_r<<3) - Theta_r
    end
    if PL == 16
        X9  = Wire()[13:0]
        X15 = Wire()[13:0]
        X9  = (Theta_r<<3) + Theta_r
        X15 = (Theta_r<<4) - Theta_r
    end
    
    # Figure out the order on this one
    Tmp_w = Wire()[13:0][PL-1:0] 
    for i= 0:PL-1
        if i == 0  
            Tmp_w[i] = Acc_r 
        elseif i == 1  
            Tmp_w[i] = Acc_r +  Theta_r 
        elseif i == 2  
            Tmp_w[i] = Acc_r +  Theta_r << 1 
        elseif i == 3  
            Tmp_w[i] = Acc_r +       X3 
        elseif i == 4  
            Tmp_w[i] = Acc_r +  Theta_r << 2 
        elseif i == 5  
            Tmp_w[i] = Acc_r +       X5 
        elseif i == 6  
            Tmp_w[i] = Acc_r +       X3 << 1 
        elseif i == 7  
            Tmp_w[i] = Acc_r +       X7 
        elseif i == 8  
            Tmp_w[i] = Acc_r +  Theta_r << 3 
        elseif i == 9  
            Tmp_w[i] = Acc_r +       X9 
        elseif i ==10  
            Tmp_w[i] = Acc_r +       X5 << 1 
        elseif i ==11  
            Tmp_w[i] = Acc_r + (Theta_r << 1) + X9 
        elseif i ==12  
            Tmp_w[i] = Acc_r +       X3 << 2 
        elseif i ==13  
            Tmp_w[i] = Acc_r + (Theta_r << 2) + X9 
        elseif i ==14  
            Tmp_w[i] = Acc_r +       X7 << 1
        elseif i ==15  
            Tmp_w[i] = Acc_r +      X15
        end
          
        @block SINCOS "SC_$(i)" (cos_w[i], sin_w[i], Tmp_w[i]) 

        @posedge CLK begin
            if ENAB == 1
                cos_r[i] = cos_w[i]
            end
        end

        @posedge CLK begin
            if ENAB == 1
                sin_r[i] = sin_w[i]
            end
        end        

        @block MULT_3M5A "Mult_$(i)" ([re_w[i] ; im_w[i]], DI_r[i], [Cos_r[i] ; Sin_r[i]] )

        @posedge CLK begin
            if ENAB == 1
                DO_RE[WL*(i+1)-1:WL*i] = re_w[i][WL+CL-1:CL-1]
            end    
        end 

        @posedge CLK begin
            if ENAB == 1
                DO_IM[WL*(i+1)-1:WL*i] = im_w[i][WL+CL-1:CL-1]
            end     
        end 
    end
end
end
