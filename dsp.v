module reg_and_mux (in,clk,out,rst,enable);  //used 10 times
    parameter rstTYPE="SYNC" ;
    parameter reg_pipeline=1;
    parameter width=18;                   //inputs and outputs width
    input [width-1:0] in;
    input clk;
    input rst;
    input enable;
    output  [width-1:0] out;
    reg [width-1:0] input_to_reg; 
    generate 
        if (rstTYPE=="SYNC")  begin
            always @ (posedge clk) begin
                if(rst) begin
                    input_to_reg<=0;
                end
                else if (enable) begin
                    input_to_reg<=in;
                end
            end
        end
        else if(rstTYPE=="ASYNC")  begin
            always @ (posedge clk or posedge rst) begin
                if(rst) begin
                    input_to_reg<=0;
                end
                else if (enable) begin
                    input_to_reg<=in;
                end
            end
        end    
    endgenerate
    assign out=(reg_pipeline)?input_to_reg:in;
endmodule




module DSP (A,B,C,D,BCIN,CARRYIN,CLK,OPMODE,CEA,CEB,CEC,CED,CECARRYIN,CEM,CEP,CEOPMODE,
RSTA,RSTB,RSTC,RSTD,RSTCARRYIN,RSTM,RSTP,RSTOPMODE,BCOUT,PCOUT,M,P,PCIN,CARRYOUT,CARRYOUTF);
//parameters
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
//input ports
input [17:0] A;
input [17:0] B;
input [47:0] C;
input [17:0] D;
input [17:0] BCIN;
input [47:0] PCIN;
input CARRYIN;
input CLK;
input CEA;
input CEB;
input CEC;
input CECARRYIN;
input CED;
input CEM;
input CEOPMODE;
input CEP;
input RSTA;
input RSTB;
input RSTC;
input RSTCARRYIN;
input RSTD;
input RSTM;
input RSTOPMODE;
input RSTP;
input [7:0] OPMODE;
//output ports
output  [35:0] M;
output  [47:0] P;
output [47:0] PCOUT;
output [17:0] BCOUT;
output CARRYOUT;
output CARRYOUTF;
//internal signals
reg  [17:0] B_OR_BCIN;    //output of the mux before B0 REG
wire [17:0] A0_MUX_OUT;   //output of A0 REG mux
wire [17:0] A1_MUX_OUT;   //output of A1 REG mux
wire [17:0] B0_MUX_OUT;   //output of B0 REG mux
wire [17:0] B1_MUX_OUT;   //output of B1 REG mux
wire [47:0] C_MUX_OUT;    //output of C REG mux
wire [17:0] D_MUX_OUT;    //output of D REG mux
wire [7:0] OPMODE_MUX_OUT; //output of OPMODE REG mux
wire [35:0] M_MUX_OUT;    //output of M REG mux
reg [17:0] pre_add_subtract_out;  //output of pre-adder/subtracter   
reg [17:0] pre_B1REG_MUX_OUT;     //input of B1 REG
reg [35:0] multiplier_out;        //output of the multiplier
reg CARRY_CASCADE_MUX_OUT;        //input of CYI REG
wire CYI_MUX_OUT;                 //output of CYI REG
reg [47:0] mux_X_OUT;             //MUX X output
reg [47:0] mux_Z_OUT;             //MUX z output
reg [48:0] post_adder_subtract_out;  // output of post-adder/subtracter 
wire [47:0] p_internal;
wire carryout_msb;                 // carryout bit              
wire [47:0] concatenated_bus;      
always @ (*)  begin               //mux 2 to 1 (B and BCIN)
    if(B_INPUT=="DIRECT") begin
      B_OR_BCIN=B;
    end
    else if (B_INPUT=="CASCADE") begin
        B_OR_BCIN=BCIN;
    end
    else begin
        B_OR_BCIN=0;
    end
end
reg_and_mux # (.rstTYPE(RSTTYPE),.reg_pipeline(DREG),.width(18)) D_REG   (D,CLK,D_MUX_OUT,RSTD,CED);
reg_and_mux # (.rstTYPE(RSTTYPE),.reg_pipeline(B0REG),.width(18)) B0_REG  (B_OR_BCIN,CLK,B0_MUX_OUT,RSTB,CEB);
reg_and_mux # (.rstTYPE(RSTTYPE),.reg_pipeline(A0REG),.width(18)) A0_REG  (A,CLK,A0_MUX_OUT,RSTA,CEA);
reg_and_mux # (.rstTYPE(RSTTYPE),.reg_pipeline(CREG),.width(48)) C_REG   (C,CLK,C_MUX_OUT,RSTC,CEC);
reg_and_mux # (.rstTYPE(RSTTYPE),.reg_pipeline(A1REG),.width(18)) A1_REG  (A0_MUX_OUT,CLK,A1_MUX_OUT,RSTA,CEA);
reg_and_mux # (.rstTYPE(RSTTYPE),.reg_pipeline(B1REG),.width(18)) B1_REG  (pre_B1REG_MUX_OUT,CLK,B1_MUX_OUT,RSTB,CEB);
reg_and_mux # (.rstTYPE(RSTTYPE),.reg_pipeline(OPMODEREG),.width(8)) OPMODE_REG (OPMODE,CLK,OPMODE_MUX_OUT,RSTOPMODE,CEOPMODE);
reg_and_mux # (.rstTYPE(RSTTYPE),.reg_pipeline(MREG),.width(36)) M_REG   (multiplier_out,CLK,M_MUX_OUT,RSTM,CEM);
reg_and_mux # (.rstTYPE(RSTTYPE),.reg_pipeline(CARRYINREG),.width(1)) CYI_REG (CARRY_CASCADE_MUX_OUT,CLK,CYI_MUX_OUT,RSTCARRYIN,CECARRYIN);
reg_and_mux # (.rstTYPE(RSTTYPE),.reg_pipeline(PREG),.width(48))  P_REG  (post_adder_subtract_out[47:0],CLK,p_internal,RSTP,CEP);
reg_and_mux # (.rstTYPE(RSTTYPE),.reg_pipeline(CARRYOUTREG),.width(1)) CYO_REG (carryout_msb,CLK,CARRYOUT,RSTCARRYIN,CECARRYIN);
//pre-Adder/subtracter operation
always @ (*) begin        
    case(OPMODE_MUX_OUT[6]) 
    1'b0:pre_add_subtract_out=D_MUX_OUT+B0_MUX_OUT;
    1'b1:pre_add_subtract_out=D_MUX_OUT-B0_MUX_OUT;
    default:pre_add_subtract_out=18'b0;
    endcase
end
//mux before B1REG
always @ (*) begin  
    if(OPMODE_MUX_OUT[4]) begin
        pre_B1REG_MUX_OUT=pre_add_subtract_out;
    end
    else if(OPMODE_MUX_OUT[4]==0) begin
        pre_B1REG_MUX_OUT=B0_MUX_OUT;
    end
end
//muultiplier
always @ (*)  begin
    multiplier_out=A1_MUX_OUT*B1_MUX_OUT;
end
//CYI MUX
always @ (*)  begin                 
    if(CARRYINSEL=="CARRYIN") begin
        CARRY_CASCADE_MUX_OUT=CARRYIN;
    end
    else if(CARRYINSEL=="OPMODE[5]")  begin
        CARRY_CASCADE_MUX_OUT=OPMODE_MUX_OUT[5];
    end
end

assign concatenated_bus={D_MUX_OUT[11:0],A1_MUX_OUT[17:0],B1_MUX_OUT[17:0]};

//mux X
always @(*) begin
    case (OPMODE_MUX_OUT[1:0])
        0: mux_X_OUT=0;
        1: mux_X_OUT={12'b0,M_MUX_OUT};
        2: mux_X_OUT=p_internal;
        3: mux_X_OUT=concatenated_bus;
    endcase
end
//mux Z
always @(*) begin
    case (OPMODE_MUX_OUT[3:2])
        0: mux_Z_OUT=0;
        1: mux_Z_OUT=PCIN;
        2: mux_Z_OUT=p_internal;
        3: mux_Z_OUT=C_MUX_OUT;
    endcase
end

//post-adder/subtractor
always @ (*) begin
    if(OPMODE_MUX_OUT[7]) begin
        post_adder_subtract_out=(mux_Z_OUT-(mux_X_OUT+CYI_MUX_OUT));
    end
    else if (OPMODE_MUX_OUT[7]==0) begin
        post_adder_subtract_out=mux_X_OUT+mux_Z_OUT+CYI_MUX_OUT;
    end
    else begin
        post_adder_subtract_out=48'b0;
    end
end
//outputs 
assign P=p_internal;
assign PCOUT=p_internal;
assign carryout_msb=post_adder_subtract_out[48];
assign CARRYOUTF=CARRYOUT;
assign BCOUT=B1_MUX_OUT;
assign M=M_MUX_OUT;
endmodule