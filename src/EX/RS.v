`include "defines.v"

// `include "riscv\src\defines.v"

module RS (
    input wire clk,
    input wire rst,
    input wire rdy,

    // from cmd
    input wire enable_sign_from_cmd,
    input wire [`OPNUM_TYPE] opnum_from_cmd,
    input wire [`DATA_TYPE] V1_from_cmd,
    input wire [`DATA_TYPE] V2_from_cmd,
    input wire [`ROB_ID_TYPE] Q1_from_cmd,
    input wire [`ROB_ID_TYPE] Q2_from_cmd,
    input wire [`ADDR_TYPE] pc_from_cmd,
    input wire [`DATA_TYPE] imm_from_cmd,
    input wire [`ROB_ID_TYPE] rob_id_from_cmd,

    // from & to RS_EX
    input wire valid_sign_from_rs_ex,
    input wire [`ROB_ID_TYPE] rob_id_from_rs_ex,
    input wire [`DATA_TYPE] data_from_rs_ex,
    output reg [`OPNUM_TYPE] opnum_to_rs_ex,
    output reg [`DATA_TYPE] V1_to_rs_ex,
    output reg [`DATA_TYPE] V2_to_rs_ex,
    output reg [`DATA_TYPE] pc_to_rs_ex,
    output reg [`DATA_TYPE] imm_to_rs_ex,
    output reg [`ROB_ID_TYPE] rob_id_to_rs_ex,
    
    // from LS_EX
    input wire valid_sign_from_ls_ex,
    input wire [`ROB_ID_TYPE] rob_id_from_ls_ex,
    input wire [`DATA_TYPE] data_from_ls_ex,

    // from ROB
    input wire rollback_sign_from_rob,

    // to fetcher
    output wire full_sign_to_if
);

    // store
    reg [`RS_SIZE - 1 : 0] busy;
    reg [`ADDR_TYPE] pc [`RS_SIZE-1:0]; 
    reg [`OPNUM_TYPE] opnum [`RS_SIZE-1:0];
    reg [`DATA_TYPE] imm [`RS_SIZE-1:0];
    reg [`DATA_TYPE] V1 [`RS_SIZE-1:0];
    reg [`DATA_TYPE] V2 [`RS_SIZE-1:0];
    reg [`ROB_ID_TYPE] Q1 [`RS_SIZE-1:0];
    reg [`ROB_ID_TYPE] Q2 [`RS_SIZE-1:0];
    reg [`ROB_ID_TYPE] rob_id [`RS_SIZE-1:0];

    // station index
    wire [`RS_ID_TYPE] free_station;
    wire [`RS_ID_TYPE] next_station;

    // calculate
    wire [`ROB_ID_TYPE] real_Q1 = (valid_sign_from_rs_ex && Q1_from_cmd == rob_id_from_rs_ex) ? `INVALID_ROB : ((valid_sign_from_ls_ex && Q1_from_cmd == rob_id_from_ls_ex) ? `INVALID_ROB : Q1_from_cmd);
    wire [`ROB_ID_TYPE] real_Q2 = (valid_sign_from_rs_ex && Q2_from_cmd == rob_id_from_rs_ex) ? `INVALID_ROB : ((valid_sign_from_ls_ex && Q2_from_cmd == rob_id_from_ls_ex) ? `INVALID_ROB : Q2_from_cmd);
    wire [`DATA_TYPE] real_V1 = (valid_sign_from_rs_ex && Q1_from_cmd == rob_id_from_rs_ex) ? data_from_rs_ex : ((valid_sign_from_ls_ex && Q1_from_cmd == rob_id_from_ls_ex) ? data_from_ls_ex : V1_from_cmd);
    wire [`DATA_TYPE] real_V2 = (valid_sign_from_rs_ex && Q2_from_cmd == rob_id_from_rs_ex) ? data_from_rs_ex : ((valid_sign_from_ls_ex && Q2_from_cmd == rob_id_from_ls_ex) ? data_from_ls_ex : V2_from_cmd);

    assign full_sign_to_if = (free_station == `INVALID_RS);
    assign free_station = ~busy[0] ? 0 : (~busy[1] ? 1 : (~busy[2] ? 2 : (~busy[3] ? 3 :(~busy[4] ? 4 : (~busy[5] ? 5 : (~busy[6] ? 6 : (~busy[7] ? 7 : (~busy[8] ? 8 :
                         (~busy[9] ? 9 : (~busy[10] ? 10 : (~busy[11] ? 11 : (~busy[11] ? 11 : (~busy[12] ? 12 : (~busy[13] ? 13 : (~busy[14] ? 14 : (~busy[15] ? 15 : `INVALID_RS))))))))))))))));
    assign next_station = (busy[0] && Q1[0] == `INVALID_ROB && Q2[0] == `INVALID_ROB) ? 0 : ((busy[1] && Q1[1] == `INVALID_ROB && Q2[1] == `INVALID_ROB) ? 1 : ((busy[2] && Q1[2] == `INVALID_ROB && Q2[2] == `INVALID_ROB) ? 2 : ((busy[3] && Q1[3] == `INVALID_ROB && Q2[3] == `INVALID_ROB) ? 3 :
                    ((busy[4] && Q1[4] == `INVALID_ROB && Q2[4] == `INVALID_ROB) ? 4 : ((busy[5] && Q1[5] == `INVALID_ROB && Q2[5] == `INVALID_ROB) ? 5 : ((busy[6] && Q1[6] == `INVALID_ROB && Q2[6] == `INVALID_ROB) ? 6 : ((busy[7] && Q1[7] == `INVALID_ROB && Q2[7] == `INVALID_ROB) ? 7 :
                    ((busy[8] && Q1[8] == `INVALID_ROB && Q2[8] == `INVALID_ROB) ? 8 : ((busy[9] && Q1[9] == `INVALID_ROB && Q2[9] == `INVALID_ROB) ? 9 : ((busy[10] && Q1[10] == `INVALID_ROB && Q2[10] == `INVALID_ROB) ? 10 : ((busy[11] && Q1[11] == `INVALID_ROB && Q2[11] == `INVALID_ROB) ? 11 :
                    ((busy[12] && Q1[12] == `INVALID_ROB && Q2[12] == `INVALID_ROB) ? 12 : ((busy[13] && Q1[13] == `INVALID_ROB && Q2[13] == `INVALID_ROB) ? 13 : ((busy[14] && Q1[14] == `INVALID_ROB && Q2[14] == `INVALID_ROB) ? 14 : ((busy[15] && Q1[15] == `INVALID_ROB && Q2[15] == `INVALID_ROB) ? 15 : `INVALID_RS)))))))))))))));
    
    always @(posedge clk) begin
        if (rst || rollback_sign_from_rob) begin
            for (integer i = 0; i < `RS_SIZE; i = i + 1) begin
                busy[i] <= `FALSE;
                pc[i] <= `NULL;
                opnum[i] <= `OPNUM_NULL;
                imm[i] <= `NULL;
                V1[i] <= `NULL;
                V2[i] <= `NULL;
                Q1[i] <= `INVALID_ROB;
                Q2[i] <= `INVALID_ROB;
                rob_id[i] <= `INVALID_ROB;
            end
        end
        else if (~rdy) begin
        end
        else begin
            if (next_station == `INVALID_RS) begin
                opnum_to_rs_ex <= `OPNUM_NULL;
                rob_id_to_rs_ex <= `INVALID_ROB;
            end
            else begin
                busy[next_station] <= `FALSE;
                opnum_to_rs_ex <= opnum[next_station];
                V1_to_rs_ex <= V1[next_station];
                V2_to_rs_ex <= V2[next_station];
                pc_to_rs_ex <= pc[next_station];
                imm_to_rs_ex <= imm[next_station];
                rob_id_to_rs_ex <= rob_id[next_station];
            end

            if (valid_sign_from_rs_ex) begin
                for (integer i = 0; i < `RS_SIZE; i = i + 1) begin
                    if (Q1[i] == rob_id_from_rs_ex) begin
                        V1[i] <= data_from_rs_ex;
                        Q1[i] <= `INVALID_ROB;
                    end
                    if (Q2[i] == rob_id_from_rs_ex) begin
                        V2[i] <= data_from_rs_ex;
                        Q2[i] <= `INVALID_ROB;
                    end
                end
            end

            if (valid_sign_from_ls_ex) begin
                for (integer i = 0; i < `RS_SIZE; i = i + 1) begin
                    if (Q1[i] == rob_id_from_ls_ex) begin
                        V1[i] <= data_from_ls_ex;
                        Q1[i] <= `INVALID_ROB;
                    end
                    if (Q2[i] == rob_id_from_ls_ex) begin
                        V2[i] <= data_from_ls_ex;
                        Q2[i] <= `INVALID_ROB;
                    end
                end
            end

            if (enable_sign_from_cmd && free_station != `INVALID_RS) begin
                busy[free_station]  <= `TRUE;
                opnum[free_station] <= opnum_from_cmd;  
                Q1[free_station] <= real_Q1;
                Q2[free_station] <= real_Q2;
                V1[free_station] <= real_V1;
                V2[free_station] <= real_V2;
                pc[free_station] <= pc_from_cmd;
                imm[free_station] <= imm_from_cmd;
                rob_id[free_station] <= rob_id_from_cmd;
            end
        end
    end

endmodule