`include "defines.v"

// `include "riscv\src\defines.v"

module Predictor (
    input clk,
    input rst,

    // predict (from fetcher)
    input wire[`ADDR_TYPE] predict_pc_from_fch,
    input wire[`INST_TYPE] predict_inst_from_fch,

    // to fetcher
    output wire predicted_jump_sign_to_fch,
    output wire [`ADDR_TYPE] predicted_jump_target_pc_to_fch,

    // update (from rob)
    input wire jump_sign_from_rob,
    input wire enable_sign_from_rob,
    input wire [`ADDR_TYPE] jump_target_pc_from_rob
);

    // record history of branch
    reg [`PREDICTOR_BIT-1:0] branch_history [`PREDICTOR_SIZE-1:0];

    // use 8bit segmant to represent the whole 32bit address
    wire [`ADDR_TYPE] pc_segmant = jump_target_pc_from_rob[`PREDICTOR_ADDR_RANGE];

    // return jump sign
    assign predicted_jump_sign_to_fch = (predict_inst_from_fch[`OPCODE_RANGE] == `OPCODE_JAL) ? `TRUE :
                            (predict_inst_from_fch[`OPCODE_RANGE] == `OPCODE_BR ? 
                            (branch_history[predict_pc_from_fch[`PREDICTOR_ADDR_RANGE]][1]) : `FALSE);
    
    // return jump pc
    wire [`ADDR_TYPE] jal_pc = {{12{predict_inst_from_fch[31]}}, predict_inst_from_fch[19:12], predict_inst_from_fch[20], predict_inst_from_fch[30:21], 1'b0};
    wire [`ADDR_TYPE] br_pc = {{20{predict_inst_from_fch[31]}}, predict_inst_from_fch[7:7], predict_inst_from_fch[30:25], predict_inst_from_fch[11:8], 1'b0};
    assign predicted_jump_target_pc_to_fch = (predict_inst_from_fch[`OPCODE_RANGE] == `OPCODE_JAL ? jal_pc : br_pc);

    // update
    always @(posedge clk) begin
        if (rst) begin
            for (integer i = 0; i< `PREDICTOR_SIZE; i = i + 1) begin
                branch_history[i] <= `WEAK_NOT_JUMP;
            end
        end
        else if (enable_sign_from_rob) begin
            branch_history[pc_segmant] <= branch_history[pc_segmant] +
            ((jump_sign_from_rob) ? (branch_history[pc_segmant] == `STRONG_JUMP ? 0 : 1) : (branch_history[pc_segmant] ==`STRONG_NOT_JUMP ? 0 : -1));
        end
    end

endmodule