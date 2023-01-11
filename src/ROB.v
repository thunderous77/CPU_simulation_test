`include "defines.v"

module ROB(
    input wire clk,
    input wire rst,
    input wire rdy,

    // data from & to commmander
    input wire [`ROB_ID_TYPE] Q1_from_cmd,
    input wire [`ROB_ID_TYPE] Q2_from_cmd,
    output wire Q1_ready_sign_to_cmd,
    output wire Q2_ready_sign_to_cmd,
    output wire [`DATA_TYPE] V1_to_cmd,
    output wire [`DATA_TYPE] V2_to_cmd,

    // instruction information from & to commmander
    input wire enable_sign_from_cmd,
    input wire is_jump_inst_from_cmd,
    input wire is_store_inst_from_cmd,
    input wire predicted_jump_sign_from_cmd,
    input wire [`REG_POS_TYPE] rd_from_cmd,
    input wire [`ADDR_TYPE] pc_from_cmd,
    input wire [`ADDR_TYPE] rollback_pc_from_cmd,
    output wire [`ROB_ID_TYPE] rob_id_to_cmd,

    // to register
    output reg [`REG_POS_TYPE] rd_to_reg,
    output reg [`ROB_ID_TYPE] Q_to_reg,
    output reg [`DATA_TYPE] V_to_reg,

    // to fetcher
    output wire full_sign_to_fch,
    output reg [`ADDR_TYPE] rollback_pc_to_fch,

    // to predictor
    output reg enable_sign_to_pdt,
    output reg jump_sign_to_pdt,
    output reg [`ADDR_TYPE] jump_target_pc_to_pdt,

    // to LS
    input wire [`ROB_ID_TYPE] io_rob_id_from_ls,
    output reg [`ROB_ID_TYPE] commit_rob_id_to_ls,
    output wire [`ROB_ID_TYPE] head_io_rob_id_to_ls,

    // from rs_ex
    input wire [`ROB_ID_TYPE] rob_id_from_rs_ex,
    input wire valid_sign_from_rs_ex,
    input wire [`DATA_TYPE] data_from_rs_ex,
    input wire [`ADDR_TYPE] jump_target_pc_from_rs_ex,
    input wire jump_sign_from_rs_ex,

    // from ls_ex
    input wire valid_sign_from_ls_ex,
    input wire [`ROB_ID_TYPE] rob_id_from_ls_ex,
    input wire [`DATA_TYPE] data_from_ls_ex,

    // global output
    output reg rollback_sign,
    output reg commit_sign
);
    // tail -> first empty rob
    reg [`ROB_POS_TYPE] head, tail;
    wire [`ROB_POS_TYPE] next_head = (head == `ROB_SIZE - 1) ? 0 : head + 1,
                         next_tail = (tail == `ROB_SIZE - 1) ? 0 : tail + 1;
    
    reg [`ROB_SIZE-1:0] busy, ready, is_io_inst, predicted_jump_sign, is_jump_inst, is_store_inst, jump_sign;
    reg [`ADDR_TYPE] pc [`ROB_SIZE-1:0];
    reg [`ADDR_TYPE] jump_target_pc [`ROB_SIZE-1:0];
    reg [`ADDR_TYPE] rollback_pc [`ROB_SIZE-1:0];
    reg [`REG_POS_TYPE] rd [`ROB_SIZE-1:0];
    reg [`DATA_TYPE] data [`ROB_SIZE-1:0];

    reg [`ROB_SIZE-1:0] rob_element_cnt;
    wire is_add_rob = enable_sign_from_cmd ? 1 : 0;
    wire is_commit_rob = (busy[head] && (ready[head] || is_store_inst[head])) ? 1 : 0;

    assign full_sign_to_fch = (rob_element_cnt >= `ROB_SIZE - 5);

    assign Q1_ready_sign_to_cmd = (Q1_from_cmd == `INVALID_ROB) ? `FALSE : ready[Q1_from_cmd - 1];
    assign Q2_ready_sign_to_cmd = (Q2_from_cmd == `INVALID_ROB) ? `FALSE : ready[Q2_from_cmd - 1];
    assign V1_to_cmd = (Q1_from_cmd == `INVALID_ROB) ? `NULL : data[Q1_from_cmd - 1];
    assign V2_to_cmd = (Q2_from_cmd == `INVALID_ROB) ? `NULL : data[Q2_from_cmd - 1];
    
    assign rob_id_to_cmd = tail + 1;

    assign head_io_rob_id_to_ls = (busy[head] && is_io_inst[head]) ? head + 1 : `INVALID_ROB;

    // test predictor
    integer jump_cnt = 0, wrong_predict_cnt = 0;

    always @(posedge clk) begin
        if (rst || rollback_sign) begin
            rob_element_cnt = `INVALID_ROB;
            head <= `INVALID_ROB;
            tail <= `INVALID_ROB;
            for (integer i = 0; i < `ROB_SIZE; i = i + 1) begin
                busy[i] <= `FALSE;
                ready[i] <= `FALSE;
                predicted_jump_sign[i] <= `FALSE;
                is_io_inst[i] <= `FALSE;
                is_jump_inst[i] <= `FALSE;
                is_store_inst[i] <= `FALSE;
                jump_sign[i] <= `FALSE;
                rd[i] <= `ZERO_REG;
                data[i] <= `NULL;
                jump_target_pc[i] <= `NULL;
                rollback_pc[i] <= `NULL;
                pc[i] <= `NULL;
            end
            commit_sign <= `FALSE;
            rollback_sign <= `FALSE;
            enable_sign_to_pdt <= `FALSE;
        end
        else if (!rdy) begin
        end
        else begin
            commit_sign <= `FALSE;
            rollback_sign <= `FALSE;
            enable_sign_to_pdt <= `FALSE;
            rob_element_cnt <= rob_element_cnt + is_add_rob - is_commit_rob;

            if (busy[head] && (ready[head] || is_store_inst[head])) begin
                // commit to register                
                commit_sign <= `TRUE;
                rd_to_reg <= rd[head];
                Q_to_reg <= head + 1;
                V_to_reg <= data[head];
                commit_rob_id_to_ls <= head + 1;

                if (is_jump_inst[head]) begin
                    enable_sign_to_pdt <= `TRUE;
                    jump_target_pc_to_pdt <= pc[head];
                    jump_sign_to_pdt <= jump_sign[head];
                    if (jump_sign[head] ^ predicted_jump_sign[head]) begin
                        rollback_sign <= `TRUE;
                        rollback_pc_to_fch <= jump_sign[head] ? jump_target_pc[head] : rollback_pc[head];
                    end
                end

                // move head to next_head
                busy[head] <= `FALSE;
                ready[head] <= `FALSE;
                is_io_inst[head] <= `FALSE;                is_jump_inst[head] <= `FALSE;
                is_store_inst[head] <= `FALSE;
                predicted_jump_sign[head] <= `FALSE;
                head <= next_head;
            end

            // update
            if (busy[rob_id_from_ls_ex - 1] && valid_sign_from_ls_ex) begin
                ready[rob_id_from_ls_ex - 1] <= `TRUE;
                data[rob_id_from_ls_ex - 1] <= data_from_ls_ex;
            end
            if (busy[rob_id_from_rs_ex - 1] && valid_sign_from_rs_ex) begin
                ready[rob_id_from_rs_ex - 1] <= `TRUE;
                data[rob_id_from_rs_ex - 1] <= data_from_rs_ex;
                jump_target_pc[rob_id_from_rs_ex - 1] <= jump_target_pc_from_rs_ex;
                jump_sign[rob_id_from_rs_ex - 1] <= jump_sign_from_rs_ex;
            end

            // commit immediately
            if (io_rob_id_from_ls != `INVALID_ROB && busy[io_rob_id_from_ls - 1]) is_io_inst[io_rob_id_from_ls - 1] <= `TRUE;

            // add
            if (enable_sign_from_cmd) begin
                busy[tail] <= `TRUE;
                predicted_jump_sign[tail] <= predicted_jump_sign_from_cmd;
                pc[tail] <= pc_from_cmd;
                rd[tail] <= rd_from_cmd;
                data[tail] <= `NULL;
                jump_target_pc[tail] <= `NULL;
                rollback_pc[tail] <= rollback_pc_from_cmd;
                ready[tail] <= `FALSE;
                is_io_inst[tail] <= `FALSE;
                is_jump_inst[tail] <= is_jump_inst_from_cmd;
                is_store_inst[tail] <= is_store_inst_from_cmd;
                jump_sign[tail] <= `FALSE;
                tail <= next_tail;
            end
        end
    end

endmodule