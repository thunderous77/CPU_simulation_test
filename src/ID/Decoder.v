// `include "/mnt/d/Sam/program/CPU-2022/riscv/src/defines.v"

`include "defines.v"

module Decoder(
    // from & to cmd
    input wire [`INST_TYPE] inst,
    output reg is_jump_inst,
    output reg is_ls_inst,
    output reg is_store_inst,
    output reg [`OPNUM_TYPE] opnum,
    output reg [`REG_POS_TYPE] rd,
    output reg [`REG_POS_TYPE] rs1,
    output reg [`REG_POS_TYPE] rs2,
    output reg [`DATA_TYPE] imm
);
    integer jalr_pc = 0;

    always @(*) begin
        opnum = `OPNUM_NULL;
        rd = inst[`RD_RANGE];
        rs1 = inst[`RS1_RANGE];
        rs2 = inst[`RS2_RANGE];
        imm = `NULL;
        is_jump_inst = `FALSE;
        is_ls_inst = `FALSE;
        is_store_inst = `FALSE;

        case (inst[`OPCODE_RANGE])
        `OPCODE_ARITH: begin // R-Type
            if (inst[`FUNC3_RANGE] == `FUNC3_SUB && inst[`FUNC7_RANGE] == `FUNC7_SPEC) 
                opnum = `OPNUM_SUB;
            else if (inst[`FUNC3_RANGE] == `FUNC3_SRAI && inst[`FUNC7_RANGE] == `FUNC7_SPEC) 
                opnum = `OPNUM_SRA;
            else begin
                case (inst[`FUNC3_RANGE])
                    `FUNC3_ADD:  opnum = `OPNUM_ADD;
                    `FUNC3_SLT:  opnum = `OPNUM_SLT;
                    `FUNC3_SLTU: opnum = `OPNUM_SLTU;
                    `FUNC3_XOR:  opnum = `OPNUM_XOR;
                    `FUNC3_OR:   opnum = `OPNUM_OR;
                    `FUNC3_AND:  opnum = `OPNUM_AND;
                    `FUNC3_SLL:  opnum = `OPNUM_SLL;
                    `FUNC3_SRL:  opnum = `OPNUM_SRL;
                endcase
            end
        end

        `OPCODE_JALR, `OPCODE_L, `OPCODE_ARITHI: begin // I-Type
            imm = {{21{inst[31]}}, inst[30:20]};
            case (inst[`OPCODE_RANGE])
                `OPCODE_JALR: begin
                    opnum = `OPNUM_JALR;
                    is_jump_inst = `TRUE;
                end
                `OPCODE_L: begin
                    is_ls_inst = `TRUE;
                    case (inst[`FUNC3_RANGE])
                        `FUNC3_LB: opnum = `OPNUM_LB;
                        `FUNC3_LH: opnum = `OPNUM_LH;
                        `FUNC3_LW: opnum = `OPNUM_LW;
                        `FUNC3_LBU: opnum = `OPNUM_LBU;
                        `FUNC3_LHU: opnum = `OPNUM_LHU;
                    endcase
                end    
                `OPCODE_ARITHI: begin
                    if (inst[`FUNC3_RANGE] == `FUNC3_SRAI && inst[`FUNC7_RANGE] == `FUNC7_SPEC) 
                        opnum = `OPNUM_SRAI;
                    else begin
                        case (inst[`FUNC3_RANGE])
                            `FUNC3_ADDI:  opnum = `OPNUM_ADDI;
                            `FUNC3_SLTI:  opnum = `OPNUM_SLTI;
                            `FUNC3_SLTIU: opnum = `OPNUM_SLTIU;
                            `FUNC3_XORI:  opnum = `OPNUM_XORI;
                            `FUNC3_ORI:   opnum = `OPNUM_ORI;
                            `FUNC3_ANDI:  opnum = `OPNUM_ANDI;
                            `FUNC3_SLLI:  opnum = `OPNUM_SLLI;
                            `FUNC3_SRLI:  opnum = `OPNUM_SRLI;
                        endcase
                    end
                    // shamt
                    if (opnum == `OPNUM_SLLI || opnum == `OPNUM_SRLI || opnum == `OPNUM_SRAI) begin
                        imm = imm[4:0];
                    end    
                end 
            endcase
        end

        `OPCODE_S: begin // S-Type
            is_ls_inst = `TRUE;
            is_store_inst = `TRUE;
            rd = `ZERO_REG; // no rd
            imm = {{21{inst[31]}}, inst[30:25], inst[`RD_RANGE]};
            case (inst[`FUNC3_RANGE])
                `FUNC3_SB:  opnum = `OPNUM_SB;
                `FUNC3_SH:  opnum = `OPNUM_SH;
                `FUNC3_SW:  opnum = `OPNUM_SW;
            endcase
        end

        `OPCODE_BR: begin // B-Type
            rd = `ZERO_REG;
            imm = {{20{inst[31]}}, inst[7:7], inst[30:25], inst[11:8], 1'b0};
            is_jump_inst = `TRUE;
            case (inst[`FUNC3_RANGE])
                `FUNC3_BEQ:  opnum = `OPNUM_BEQ;
                `FUNC3_BNE:  opnum = `OPNUM_BNE;
                `FUNC3_BLT:  opnum = `OPNUM_BLT;
                `FUNC3_BGE:  opnum = `OPNUM_BGE;
                `FUNC3_BLTU: opnum = `OPNUM_BLTU;
                `FUNC3_BGEU: opnum = `OPNUM_BGEU;
            endcase
        end

        `OPCODE_LUI, `OPCODE_AUIPC: begin // U-Type
            imm = {inst[31:12], 12'b0};
            if (inst[`OPCODE_RANGE] == `OPCODE_LUI)
                opnum = `OPNUM_LUI;
            else 
                opnum = `OPNUM_AUIPC;
        end

        `OPCODE_JAL: begin // J-Type
            imm = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
            opnum = `OPNUM_JAL;
            is_jump_inst = `TRUE;
        end

        default begin
            opnum = `OPNUM_NULL;
            imm = `NULL;
        end    
    endcase

    end
endmodule