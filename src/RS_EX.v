`include "defines.v"

// `include "riscv\src\defines.v"

module RS_EX (
    // from rs
    input wire [`OPNUM_TYPE] opnum_from_rs,
    input wire [`DATA_TYPE] V1_from_rs,
    input wire [`DATA_TYPE] V2_from_rs,
    input wire [`DATA_TYPE] imm_from_rs,
    input wire [`ADDR_TYPE] pc_from_rs,
    input wire [`ROB_ID_TYPE] rob_id_from_rs,

    // global output
    output reg [`DATA_TYPE] data,
    output reg [`ADDR_TYPE] jump_target_pc,
    output reg jump_sign,
    output reg valid_sign,
    output reg [`ROB_ID_TYPE] rob_id
);

    always @(*) begin
        rob_id = rob_id_from_rs;
        valid_sign = (opnum_from_rs != `OPNUM_NULL);
        data = `NULL;
        jump_sign = `FALSE;
        jump_target_pc = `NULL;
        case (opnum_from_rs)
            `OPNUM_LUI: data = imm_from_rs;

            `OPNUM_AUIPC: data = pc_from_rs + imm_from_rs;

            `OPNUM_JAL: begin
                jump_target_pc = pc_from_rs + imm_from_rs;
                data = pc_from_rs + 4;
                jump_sign = `TRUE;
            end    

            `OPNUM_JALR: begin
                jump_target_pc = V1_from_rs + imm_from_rs;
                data = pc_from_rs + 4;
                jump_sign = `TRUE;
            end

            `OPNUM_BEQ: begin
                jump_target_pc = pc_from_rs + imm_from_rs;
                jump_sign = (V1_from_rs == V2_from_rs);
            end    

            `OPNUM_BNE: begin
                jump_target_pc = pc_from_rs + imm_from_rs;
                jump_sign = (V1_from_rs != V2_from_rs);   
            end     

            `OPNUM_BLT: begin
                jump_target_pc = pc_from_rs + imm_from_rs;
                jump_sign = ($signed(V1_from_rs) < $signed(V2_from_rs));
            end    

            `OPNUM_BGE: begin
                jump_target_pc = pc_from_rs + imm_from_rs;
                jump_sign = ($signed(V1_from_rs) >= $signed(V2_from_rs));
            end    

            `OPNUM_BLTU: begin
                jump_target_pc = pc_from_rs + imm_from_rs;
                jump_sign = (V1_from_rs < V2_from_rs);
            end    

            `OPNUM_BGEU: begin
                jump_target_pc = pc_from_rs + imm_from_rs;
                jump_sign = (V1_from_rs >= V2_from_rs);
            end    

            `OPNUM_ADD: data = V1_from_rs + V2_from_rs;

            `OPNUM_SUB: data = V1_from_rs - V2_from_rs;

            `OPNUM_SLL: data = (V1_from_rs << V2_from_rs);

            `OPNUM_SLT: data = ($signed(V1_from_rs) < $signed(V2_from_rs));

            `OPNUM_SLTU: data = (V1_from_rs < V2_from_rs);

            `OPNUM_XOR: data = V1_from_rs ^ V2_from_rs;

            `OPNUM_SRL: data = (V1_from_rs >> V2_from_rs);

            `OPNUM_SRA: data = (V1_from_rs >>> V2_from_rs);

            `OPNUM_OR: data = (V1_from_rs | V2_from_rs);

            `OPNUM_AND: data = (V1_from_rs & V2_from_rs);

            `OPNUM_ADDI: data = V1_from_rs + imm_from_rs;

            `OPNUM_SLLI: data = (V1_from_rs << imm_from_rs);

            `OPNUM_SLTI: data = ($signed(V1_from_rs) < $signed(imm_from_rs));

            `OPNUM_SLTIU: data = (V1_from_rs < imm_from_rs);

            `OPNUM_XORI:  data = V1_from_rs ^ imm_from_rs;   

            `OPNUM_SRLI: data = (V1_from_rs >> imm_from_rs);

            `OPNUM_SRAI: data = (V1_from_rs >>> imm_from_rs);

            `OPNUM_ORI: data = (V1_from_rs | imm_from_rs);
            
            `OPNUM_ANDI: data = (V1_from_rs & imm_from_rs);
        endcase

        if (opnum_from_rs >= `OPNUM_BEQ && opnum_from_rs <= `OPNUM_BGEU) data = jump_sign;
    end

endmodule