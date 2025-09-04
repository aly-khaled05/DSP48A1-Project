module DSP_tb();
//Parameters
parameter A0REG=0;      
parameter A1REG=1;     
parameter B0REG=0;      
parameter B1REG=1;     
parameter CREG=1;
parameter DREG=1;
parameter MREG=1;
parameter PREG=1;
parameter CARRYINREG=1;
parameter CARRYOUTREG=1;
parameter OPMODEREG=1;
parameter CARRYINSEL="OPMODE[5]";
parameter B_INPUT="DIRECT";
parameter RSTTYPE="SYNC";
//Inputs
reg [17:0] A;
reg [17:0] B;
reg [47:0] C;
reg [17:0] D;
reg [17:0] BCIN;
reg [47:0] PCIN;
reg CARRYIN;
reg CLK;
reg CEA;
reg CEB;
reg CEC;
reg CECARRYIN;
reg CED;
reg CEM;
reg CEOPMODE;
reg CEP;
reg RSTA;
reg RSTB;
reg RSTC;
reg RSTCARRYIN;
reg RSTD;
reg RSTM;
reg RSTOPMODE;
reg RSTP;
reg [7:0] OPMODE;
//Outputs
wire [35:0] M;
wire [47:0] P;
wire [47:0] PCOUT;
wire [17:0] BCOUT;
wire CARRYOUT;
wire CARRYOUTF;
//SIGNALS
reg [47:0] preP;
reg [47:0] prePOUT;
//DUT
DSP #(.A0REG(A0REG),.A1REG(A1REG),.B0REG(B0REG),.B1REG(B1REG),.CREG(CREG),.DREG(DREG),
.MREG(MREG),.PREG(PREG),.CARRYINREG(CARRYINREG),.CARRYOUTREG(CARRYOUTREG),.OPMODEREG(OPMODEREG)
,.CARRYINSEL(CARRYINSEL),.B_INPUT(B_INPUT),.RSTTYPE(RSTTYPE))
dsp_dut  (A,B,C,D,BCIN,CARRYIN,CLK,OPMODE,CEA,CEB,CEC,CED,CECARRYIN,CEM,CEP,CEOPMODE,
RSTA,RSTB,RSTC,RSTD,RSTCARRYIN,RSTM,RSTP,RSTOPMODE,BCOUT,PCOUT,M,P,PCIN,CARRYOUT,CARRYOUTF);
//Clock generation
initial  begin
    CLK=0;
    forever begin
        #1;
        CLK=~CLK;
    end
end
initial  begin
    RSTA=1;
    RSTB=1;
    RSTC=1;
    RSTD=1;
    RSTCARRYIN=1;
    RSTM=1;
    RSTOPMODE=1;
    RSTP=1;
    A=$random; 
    B=$random;
    C=$random;
    D=$random;
    BCIN=$random;
    CARRYIN=$random;
    OPMODE=$random;
    CEA=$random;
    CEB=$random;
    CEC=$random;
    CED=$random;
    CEM=$random;
    CECARRYIN=$random;
    CEOPMODE=$random;
    CEP=$random;
    @ (negedge CLK);
    if (M==0 && P==0 && PCOUT==0 && BCOUT==0 && CARRYOUT==0 && CARRYOUTF==0 ) begin
        $display("CORRECT OUTPUT-The reset is working well");
    end
    else begin
        $display("ERROR-INCORRECT OUTPUT");
        $stop;
    end
    RSTA=0;
    RSTB=0;
    RSTC=0;
    RSTD=0;
    RSTCARRYIN=0;
    RSTM=0;
    RSTOPMODE=0;
    RSTP=0;
    CEA=1;
    CEB=1;
    CEC=1;
    CED=1;
    CEM=1;
    CECARRYIN=1;
    CEOPMODE=1;
    CEP=1;
    repeat(100) begin
        OPMODE=8'b11011101;
        A=20;
        B=10;
        C=350;
        D=25;
        BCIN=$random;
        PCIN=$random;
        CARRYIN=$random;
        repeat(4) @ (negedge CLK);
        if(BCOUT=='hf && M=='h12c && P=='h32 && PCOUT=='h32 && CARRYOUT==0 && CARRYOUTF==0 ) begin
            $display("CORRECT OUTPUT-path 1 works well");
        end
        else begin
            $display("ERROR-INCORRECT OUTPUT");
            $stop;
        end
    end
    
    repeat(100) begin`
        OPMODE = 8'b00010000;
        A = 20;
        B = 10;
        C = 350;
        D = 25;
        BCIN=$random;
        PCIN=$random;
        CARRYIN=$random;
        repeat(3) @(negedge CLK);
        if(BCOUT=='h23 && M=='h2bc && P==0 && PCOUT==0 && CARRYOUT==0 && CARRYOUTF==0 ) begin
             $display("CORRECT OUTPUT-path 2 works well");
        end
        else begin
            $display("ERROR-INCORRECT OUTPUT");
            $stop;
        end
    end
    
     repeat (100) begin
       OPMODE = 8'b00001010;
        A = 20;
        B = 10;
        C = 350;
        D = 25;
        BCIN=$random;
        PCIN=$random;
        CARRYIN=$random;
        preP=P;
        prePOUT=PCOUT;
        repeat(3) @(negedge CLK);
        if(BCOUT=='ha && M=='hc8 && P==preP && PCOUT==prePOUT && CARRYOUT==0 && CARRYOUTF==0 ) begin
             $display("CORRECT OUTPUT-path 3 works well");
        end
        else begin
            $display("ERROR-INCORRECT OUTPUT");
            $stop;
        end
     end
     repeat(100) begin
      OPMODE = 8'b10100111;
        A = 5;
        B = 6;
        C = 350;
        D = 25;
        PCIN=3000;
        BCIN=$random;
        CARRYIN=$random;
        repeat(3) @(negedge CLK);
        if(BCOUT=='h6 && M=='h1e && P=='hfe6fffec0bb1 && PCOUT=='hfe6fffec0bb1 && CARRYOUT==1 && CARRYOUTF==1 ) begin
             $display("CORRECT OUTPUT-path 4 works well");
        end
        else begin
            $display("ERROR-INCORRECT OUTPUT");
            $stop;
        end
        $stop;
     end
end
endmodule





    






