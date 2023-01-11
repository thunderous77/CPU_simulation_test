`include "defines.v"

module Register (
    input wire clk,
    input wire rst,

    // from & to cmd
    input wire enable_sign_from_cmd,
    input wire [`REG_POS_TYPE] rd_from_cmd,
    input wire [`ROB_ID_TYPE] rd_rob_id_from_cmd,
    input wire [`REG_POS_TYPE] rs1_from_cmd,
    input wire [`REG_POS_TYPE] rs2_from_cmd,
    output wire [`DATA_TYPE] V1_to_cmd,
    output wire [`DATA_TYPE] V2_to_cmd,
    output wire [`ROB_ID_TYPE] Q1_to_cmd,
    output wire [`ROB_ID_TYPE] Q2_to_cmd,

    // from ROB
    input wire commit_sign_from_rob,
    input wire rollback_sign_from_rob,
    input wire [`DATA_TYPE] V_from_rob,
    input wire [`ROB_ID_TYPE] Q_from_rob,
    input wire [`REG_POS_TYPE] rd_from_rob

);

    // register store
    reg [`ROB_ID_TYPE] Q [`REG_SIZE-1:0];
    reg [`DATA_TYPE] V [`REG_SIZE-1:0]; 

    // prevent latch
    // deal with the input data at once, but only modify the register at posedge clk
    reg shadow_rollback_sign_from_rob, shadow_commit_data_valid_sign;
    reg [4:0] shadow_Q_from_cmd, shadow_rd_from_cmd, shadow_rd_from_rob;
    reg [31:0] shadow_V_from_rob;

    // wire commit_data_valid_sign = (enable_sign_from_cmd && rd_from_rob == rd_from_cmd) ? `FALSE :  (Q[rd_from_rob] == Q_from_rob);

    assign Q1_to_cmd = (shadow_rd_from_rob == rs1_from_cmd && shadow_commit_data_valid_sign) ? `INVALID_ROB : (shadow_rd_from_cmd == rs1_from_cmd ? shadow_Q_from_cmd : (rollback_sign_from_rob ? `INVALID_ROB : Q[rs1_from_cmd]));
    assign Q2_to_cmd = (shadow_rd_from_rob == rs2_from_cmd && shadow_commit_data_valid_sign) ? `INVALID_ROB : (shadow_rd_from_cmd == rs2_from_cmd ? shadow_Q_from_cmd : (rollback_sign_from_rob ? `INVALID_ROB : Q[rs2_from_cmd]));
    assign V1_to_cmd = (shadow_rd_from_rob == rs1_from_cmd && rs1_from_cmd != `ZERO_REG) ? shadow_V_from_rob : V[rs1_from_cmd];
    assign V2_to_cmd = (shadow_rd_from_rob == rs2_from_cmd && rs2_from_cmd != `ZERO_REG) ? shadow_V_from_rob : V[rs2_from_cmd];

    // debug
    // integer outfile;
    // initial begin
    //     outfile = $fopen("reg.out");
    // end

    always @(*) begin
        shadow_rollback_sign_from_rob = `FALSE;
        shadow_commit_data_valid_sign = `FALSE;
        shadow_Q_from_cmd = `INVALID_ROB;
        shadow_rd_from_cmd = `ZERO_REG;
        shadow_rd_from_rob = `ZERO_REG;
        shadow_V_from_rob = `NULL;

        if (rollback_sign_from_rob) shadow_rollback_sign_from_rob = `TRUE;
        else if (enable_sign_from_cmd && rd_from_cmd != `ZERO_REG) begin
            shadow_rd_from_cmd = rd_from_cmd;
            shadow_Q_from_cmd = rd_rob_id_from_cmd;
        end

        if (commit_sign_from_rob && rd_from_rob != `ZERO_REG) begin
            shadow_rd_from_rob = rd_from_rob;
            shadow_V_from_rob = V_from_rob;
            if (!(enable_sign_from_cmd && rd_from_rob == rd_from_cmd) && Q[rd_from_rob] == Q_from_rob) shadow_commit_data_valid_sign = `TRUE;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            for (integer i = 0; i < `REG_SIZE; i = i + 1) begin
                Q[i] <= `INVALID_ROB;
                V[i] <= `NULL;
            end
        end
        else begin
            if (shadow_rollback_sign_from_rob) begin
                for (integer i = 0; i < `REG_SIZE; i = i + 1) Q[i] <= `INVALID_ROB;
            end
            // reorder
            else if (shadow_rd_from_cmd != `ZERO_REG) begin
                Q[shadow_rd_from_cmd] <= shadow_Q_from_cmd;
            end 

            if (shadow_rd_from_rob != `ZERO_REG) begin
                V[shadow_rd_from_rob] <= shadow_V_from_rob;
                if (shadow_commit_data_valid_sign) Q[shadow_rd_from_rob] <= `INVALID_ROB;
            end
        end

        // debug
        // $fdisplay(outfile, "reg1 = %x, reg2 = %x, reg3 = %x, reg4 = %x, reg5 = %x, reg6 = %x, reg7 = %x, reg8 = %x", V[1], V[2], V[3], V[4], V[5], V[6], V[7], V[8]);
        // $fdisplay(outfile, "reg9 = %x, reg10 = %x, reg11 = %x, reg12 = %x, reg13 = %x, reg14 = %x, reg15 = %x, reg16 = %x", V[9], V[10], V[11], V[12], V[13], V[14], V[15], V[16]);
    end
endmodule