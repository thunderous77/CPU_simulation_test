`include "defines.v"
`include "ID/Decoder.v"

module Commander(
    input clk,
    input rst,
    input rdy,
    
    // from fetcher
    input wire finish_flag_from_fch,
    input wire [`INST_TYPE] inst_from_fch,
    input wire [`ADDR_TYPE] pc_from_fch,
    input wire predicted_jump_sign_from_fch,
    input wire [`ADDR_TYPE] rollback_pc_from_fch,

    // rollback information from ROB
    input wire rollback_sign_from_rob,

    // data from & to ROB
    input wire Q1_ready_sign_from_rob,
    input wire Q2_ready_sign_from_rob,
    input wire [`DATA_TYPE] V1_from_rob,
    input wire [`DATA_TYPE] V2_from_rob,
    output wire [`ROB_ID_TYPE] Q1_to_rob,
    output wire [`ROB_ID_TYPE] Q2_to_rob,

    // instruction information from & to ROB
    input wire [`ROB_ID_TYPE] rob_id_from_rob,
    output reg enable_sign_to_rob,
    output reg [`REG_POS_TYPE] rd_to_rob,
    output reg is_jump_inst_to_rob,
    output reg is_store_inst_to_rob,
    output reg predicted_jump_sign_to_rob,
    output reg [`ADDR_TYPE] pc_to_rob,
    output reg [`ADDR_TYPE] rollback_pc_to_rob,

    // from & to register
    input wire [`ROB_ID_TYPE] Q1_from_reg,
    input wire [`ROB_ID_TYPE] Q2_from_reg,
    input wire [`DATA_TYPE] V1_from_reg,
    input wire [`DATA_TYPE] V2_from_reg,
    output wire [`REG_POS_TYPE] rs1_to_reg,
    output wire [`REG_POS_TYPE] rs2_to_reg,
    output reg enable_sign_to_reg,
    output reg [`REG_POS_TYPE] rd_to_reg,
    output wire [`ROB_ID_TYPE] rd_rob_id_to_reg,

    // to RS
    output reg enable_sign_to_rs,
    output reg [`OPNUM_TYPE] opnum_to_rs,
    output reg [`DATA_TYPE] V1_to_rs,
    output reg [`DATA_TYPE] V2_to_rs,
    output reg [`ROB_ID_TYPE] Q1_to_rs,
    output reg [`ROB_ID_TYPE] Q2_to_rs,
    output reg [`ADDR_TYPE] pc_to_rs,
    output reg [`DATA_TYPE] imm_to_rs,
    output wire [`ROB_ID_TYPE] rob_id_to_rs,

    // from RS_EX
    input wire [`ROB_ID_TYPE] rob_id_from_rs_ex,
    input wire valid_sign_from_rs_ex,
    input wire [`DATA_TYPE] data_from_rs_ex,

    // to LSB
    output reg enable_sign_to_ls,
    output reg [`OPNUM_TYPE] opnum_to_ls,
    output reg [`DATA_TYPE] V1_to_ls,
    output reg [`DATA_TYPE] V2_to_ls,
    output reg [`ROB_ID_TYPE] Q1_to_ls,
    output reg [`ROB_ID_TYPE] Q2_to_ls,
    output reg [`DATA_TYPE] imm_to_ls,
    output wire [`ROB_ID_TYPE] rob_id_to_ls,

    // from LS_EX
    input wire [`ROB_ID_TYPE] rob_id_from_ls_ex,
    input wire valid_sign_from_ls_ex,
    input wire [`DATA_TYPE] data_from_ls_ex
);

    // decoder
    wire [`OPNUM_TYPE] opnum_from_dcd;
    wire [`REG_POS_TYPE] rd_from_dcd, rs1_from_dcd, rs2_from_dcd;
    wire [`DATA_TYPE] imm_from_dcd;
    wire is_jump_inst_from_dcd, is_ls_inst_from_dcd, is_store_inst_from_dcd;

    Decoder decoder (
        .inst(inst_from_fch),
        .opnum(opnum_from_dcd),
        .rd(rd_from_dcd),
        .rs1(rs1_from_dcd),
        .rs2(rs2_from_dcd),
        .imm(imm_from_dcd),
        .is_jump_inst(is_jump_inst_from_dcd),
        .is_ls_inst(is_ls_inst_from_dcd),
        .is_store_inst(is_store_inst_from_dcd)
    );

    // data forward
    wire [`ROB_ID_TYPE] data_forward_Q1 = (valid_sign_from_rs_ex && Q1_from_reg == rob_id_from_rs_ex) ? `INVALID_ROB : ((valid_sign_from_ls_ex && Q1_from_reg == rob_id_from_ls_ex) ? `INVALID_ROB : (Q1_ready_sign_from_rob ? `INVALID_ROB : Q1_from_reg));
    wire [`ROB_ID_TYPE] data_forward_Q2 = (valid_sign_from_rs_ex && Q2_from_reg == rob_id_from_rs_ex) ? `INVALID_ROB : ((valid_sign_from_ls_ex && Q2_from_reg == rob_id_from_ls_ex) ? `INVALID_ROB : (Q2_ready_sign_from_rob ? `INVALID_ROB : Q2_from_reg));
    wire [`DATA_TYPE] data_forward_V1 = (valid_sign_from_rs_ex && Q1_from_reg == rob_id_from_rs_ex) ? data_from_rs_ex : ((valid_sign_from_ls_ex && Q1_from_reg == rob_id_from_ls_ex) ? data_from_ls_ex :(Q1_ready_sign_from_rob ? V1_from_rob : V1_from_reg));
    wire [`DATA_TYPE] data_forward_V2 = (valid_sign_from_rs_ex && Q2_from_reg == rob_id_from_rs_ex) ? data_from_rs_ex : ((valid_sign_from_ls_ex && Q2_from_reg == rob_id_from_ls_ex) ? data_from_ls_ex :(Q2_ready_sign_from_rob ? V2_from_rob : V2_from_reg));

    assign Q1_to_rob = Q1_from_reg;
    assign Q2_to_rob = Q2_from_reg;
    assign rs1_to_reg = rs1_from_dcd;
    assign rs2_to_reg = rs2_from_dcd;
    assign rd_rob_id_to_reg = rob_id_from_rob;
    assign rob_id_to_rs = rob_id_from_rob;
    assign rob_id_to_ls = rob_id_from_rob;
    // assign rd_to_reg = rd_from_dcd;

    always @(posedge clk) begin
        if (rst || opnum_from_dcd == `OPNUM_NULL || finish_flag_from_fch == `FALSE || rollback_sign_from_rob) begin
            enable_sign_to_reg <= `FALSE;
            enable_sign_to_rs <= `FALSE;
            enable_sign_to_ls <= `FALSE;
            enable_sign_to_rob <= `FALSE;
        end
        else if (~rdy) begin
        end
        else begin
            enable_sign_to_reg <= `FALSE;
            enable_sign_to_rs <= `FALSE;
            enable_sign_to_ls <= `FALSE;
            enable_sign_to_rob <= `FALSE;

            // to ROB
            rd_to_rob <= rd_from_dcd;
            is_jump_inst_to_rob <= is_jump_inst_from_dcd;
            is_store_inst_to_rob <= is_store_inst_from_dcd;
            predicted_jump_sign_to_rob <= predicted_jump_sign_from_fch;
            pc_to_rob <= pc_from_fch;
            rollback_pc_to_rob <= rollback_pc_from_fch;

            // to register
            rd_to_reg <= rd_from_dcd;

            // to LS
            opnum_to_ls <= opnum_from_dcd;
            imm_to_ls <= imm_from_dcd;
            Q1_to_ls <= data_forward_Q1;
            Q2_to_ls <= data_forward_Q2;
            V1_to_ls <= data_forward_V1;
            V2_to_ls <= data_forward_V2;

            // to RS
            opnum_to_rs <= opnum_from_dcd;
            pc_to_rs <= pc_from_fch;
            imm_to_rs <= imm_from_dcd;
            Q1_to_rs <= data_forward_Q1;
            Q2_to_rs <= data_forward_Q2;
            V1_to_rs <= data_forward_V1;
            V2_to_rs <= data_forward_V2;
            
            if (finish_flag_from_fch) begin
                // to ROB
                enable_sign_to_rob <= `TRUE;
                // rd_to_rob <= rd_from_dcd;
                // is_jump_inst_to_rob <= is_jump_inst_from_dcd;
                // is_store_inst_to_rob <= is_store_inst_from_dcd;
                // predicted_jump_sign_to_rob <= predicted_jump_sign_from_fch;
                // pc_to_rob <= pc_from_fch;
                // rollback_pc_to_rob <= rollback_pc_from_fch;

                // to register
                enable_sign_to_reg <= `TRUE;

                if (is_ls_inst_from_dcd) begin
                    // to LS
                    enable_sign_to_ls <= `TRUE;
                    // opnum_to_ls <= opnum_from_dcd;
                    // imm_to_ls <= imm_from_dcd;
                    // Q1_to_ls <= data_forward_Q1;
                    // Q2_to_ls <= data_forward_Q2;
                    // V1_to_ls <= data_forward_V1;
                    // V2_to_ls <= data_forward_V2;
                end
                else begin
                    // to RS
                    enable_sign_to_rs <= `TRUE;
                    // opnum_to_rs <= opnum_from_dcd;
                    // pc_to_rs <= pc_from_fch;
                    // imm_to_rs <= imm_from_dcd;
                    // Q1_to_rs <= data_forward_Q1;
                    // Q2_to_rs <= data_forward_Q2;
                    // V1_to_rs <= data_forward_V1;
                    // V2_to_rs <= data_forward_V2;
                end
            end
        end
    end

endmodule