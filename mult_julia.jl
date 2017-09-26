# After parameterization, WL_X = 10, WL_Y = 10
function MULT_3M5A(DO, DI_X, DI_Y)
    DO   = Output()[39:0]
    DI_X =  Input()[19:0]
    DI_Y =  Input()[19:0]

    A  := DI_X[19:10]
    B  := DI_X[9:0]
    C  := DI_Y[19:10]
    D  := DI_Y[9:0]

    # (a+jb)(c+jd) = [c(a-b) + b(c-d)] + j[d(a+b) + b(c-d)]
    AmB_t[10:0] := [A[9] ; A] - [B[9] ; B] # A minus B
    ApB_t[10:0] := [A[9] ; A] + [B[9] ; B] # A plus B
    CmD_t[10:0] := [C[9] ; C] - [D[9] ; D] # C minus D

    CtAmB_t[9:0] := [C[9](WL_O-WL_Y) ; C] * [AmB_t[10](9) ; AmB_t]
    # C times A minus B
    DtApB_t[9:0] := [D[9](WL_O-WL_Y) ; D] * [ApB_t[10](9) ; ApB_t]
    # D times A plus B
    BtCmD_t[9:0] := [B[9](WL_O-WL_X) ; B] * [CmD_t[10](9) ; CmD_t]
    # B times C minus D

    DO_RE[19:0] := CtAmB_t + BtCmD_t
    DO_IM[19:0] := DtApB_t + BtCmD_t

    DO := [DO_RE ; DO_IM]
end

# After sanitization
function MULT_3M5A(DO, DI_X, DI_Y)
    DO   = Output()[39:0]
    DI_X =  Input()[19:0]
    DI_Y =  Input()[19:0]

    A = Wire()[9:0]
    A  := DI_X[19:10]

    B = Wire()[9:0]
    B  := DI_X[9:0]

    C = Wire()[9:0]
    C  := DI_Y[19:10]

    D = Wire()[9:0]
    D  := DI_Y[9:0]

    # (a+jb)(c+jd) = [c(a-b) + b(c-d)] + j[d(a+b) + b(c-d)]
    AmB_t = Wire()[10:0]
    AmB_t[10:0] := [A[9] ; A] - [B[9] ; B] # A minus B

    ApB_t = Wire()[10:0]
    ApB_t[10:0] := [A[9] ; A] + [B[9] ; B] # A plus B

    CmD_t = Wire()[10:0]
    CmD_t[10:0] := [C[9] ; C] - [D[9] ; D] # C minus D

    # C times A minus B
    CtAmB_t = Wire()[19:0]
    CtAmB_t[9:0] := [C[9](WL_O-WL_Y) ; C] * [AmB_t[10](9) ; AmB_t]

    # D times A plus B
    DtApB_t = Wire()[19:0]
    DtApB_t[9:0] := [D[9](WL_O-WL_Y) ; D] * [ApB_t[10](9) ; ApB_t]

    # B times C minus D
    BtCmD_t = Wire()[19:0]    
    BtCmD_t[9:0] := [B[9](WL_O-WL_X) ; B] * [CmD_t[10](9) ; CmD_t]

    DO_RE = Wire()[19:0]
    DO_RE[19:0] := CtAmB_t + BtCmD_t
    DO_IM = Wire()[19:0]
    DO_IM[19:0] := DtApB_t + BtCmD_t

    DO := [DO_RE ; DO_IM]
end


# The following is only for simulation purposes
function MULT_3M5A(DO, DI_X, DI_Y)
    Output(DO, 40)
    Input(DI_X, 20)
    Input(DI_Y, 20)

    BITS(A, DI_X, 19, 10)
    BITS(B, DI_X, 9, 0)
    BITS(C, DI_Y, 19, 10)
    BITS(D, DI_Y, 9, 0)

    # (a+jb)(c+jd) = [c(a-b) + b(c-d)] + j[d(a+b) + b(c-d)]
    BIT(AmB_t!!s0, A, 9)
    CAT(AmB_t!!s1, AmB_t!!s0, A)
    BIT(AmB_t!!s2, B, 9)
    CAT(AmB_t!!s3, AmB_t!!s2, B)
    SUB(AmB_t, AmB_t!!s1, AmB_t!!s3) # A Minus B

    BIT(ApB_t!!s0, A, 9)
    CAT(ApB_t!!s1, ApB_t!!s0, A)
    BIT(ApB_t!!s2, B, 9)
    CAT(ApB_t!!s3, ApB_t!!s2, B)
    ADD(ApB_t, ApB_t!!s1, ApB_t!!s3) # A Plus B

    BIT(CmD_t!!s0, C, 9)
    CAT(CmD_t!!s1, CmD_t!!s0, C)
    BIT(CmD_t!!s2, D, 9)
    CAT(CmD_t!!s3, CmD_t!!s2, D)
    ADD(CmD_t, CmD_t!!s1, CmD_t!!s3) # C Minus D

    # C times A minus B
    BIT(CtAmB_t!!s0, C, 9)
    REPEAT(CtAmB_t!!s1, CtAmB_t!!s0, 10)
    CAT(CtAmB_t!!s2, CtAmB_t!!s1, C)
    BIT(CtAmB_t!!s3,  AmB_t, 10)
    REPEAT(CtAmB_t!!s4, CtAmB_t!!s3, 9)
    CAT(CtAmB_t!!s5, CtAmB_t!!s4, AmB_t)
    MULT(CtAmB_t, CtAmB_t!!s2, CtAmB_t!!s5)    

    # D times A plus B
    BIT(DtApB_t!!s0, D, 9)
    REPEAT(DtApB_t!!s1, DtApB_t!!s0, 10)
    CAT(DtApB_t!!s2, DtApB_t!!s1, D)
    BIT(DtApB_t!!s3,  ApB_t, 10)
    REPEAT(DtApB_t!!s4, DtApB_t!!s3, 9)
    CAT(DtApB_t!!s5, DtApB_t!!s4, ApB_t)
    MULT(DtApB_t, DtApB_t!!s2, DtApB_t!!s5) 

    # B times C minus D
    BIT(BtCmD_t!!s0, B, 9)
    REPEAT(BtCmD_t!!s1, BtCmD_t!!s0, 10)
    CAT(BtCmD_t!!s2, BtCmD_t!!s1, B)
    BIT(BtCmD_t!!s3,  CmD_t, 10)
    REPEAT(BtCmD_t!!s4, BtCmD_t!!s3, 9)
    CAT(BtCmD_t!!s5, BtCmD_t!!s4, CmD_t)
    MULT(BtCmD_t, BtCmD_t!!s2, BtCmD_t!!s5) 

    ADD(DO_RE, CtAmB_t, BtCmD_t)
    ADD(DO_IM, DtApB_t, BtCmD_t)

    CAT(DO, DO_RE, DO_IM)
end
