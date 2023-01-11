`include "defines.v"

// `include "riscv\src\defines.v"

module LS (
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
    input wire [`DATA_TYPE] imm_from_cmd,
    input wire [`ROB_ID_TYPE] rob_id_from_cmd,

    // from ROB
    input wire rollback_sign_from_rob,
    input wire commit_sign_from_rob,
    input wire [`ROB_ID_TYPE] commit_rob_id_from_rob,
    input wire [`ROB_ID_TYPE] head_io_rob_id_from_rob,
    output wire [`ROB_ID_TYPE] io_rob_id_to_rob,

    // from RS_EX
    input wire [`ROB_ID_TYPE] rob_id_from_rs_ex,
    input wire [`DATA_TYPE] data_from_rs_ex,
    input wire valid_sign_from_rs_ex,

    // from & to LS_EX
    input wire full_sign_from_ls_ex,
    input wire valid_sign_from_ls_ex,
    input wire [`ROB_ID_TYPE] rob_id_from_ls_ex,
    input wire [`DATA_TYPE] data_from_ls_ex,
    output reg [`ROB_ID_TYPE] rob_id_to_ls_ex,
    output reg enable_sign_to_ls_ex,
    output reg [`OPNUM_TYPE] opnum_to_ls_ex,
    output reg [`ADDR_TYPE] addr_to_ls_ex,
    output reg [`DATA_TYPE] store_data_to_ls_ex,

    // to fetcher
    output wire full_sign_to_fch
);

    reg [`LS_ID_TYPE] head, tail,store_tail;
    wire [`LS_ID_TYPE] next_head = (head == `LS_SIZE - 1) ? 0 : head + 1;
    wire [`LS_ID_TYPE] next_tail = (tail == `LS_SIZE - 1) ? 0 : tail + 1;

    // use for rollback
    reg [`LS_ID_TYPE] rollback_tail, tmp;
    wire [`LS_ID_TYPE] next_rollback_tail = (rollback_tail == `LS_SIZE - 1) ? 0 : rollback_tail + 1;
    wire [`LS_ID_TYPE] next_tmp = (tmp == `LS_SIZE - 1) ? 0 : tmp + 1;


    reg [`LS_SIZE-1:0] busy;
    reg [`LS_SIZE-1:0] commit;
    reg [`OPNUM_TYPE] opnum [`LS_SIZE-1:0];
    reg [`ROB_ID_TYPE] Q1 [`LS_SIZE-1:0];
    reg [`ROB_ID_TYPE] Q2 [`LS_SIZE-1:0];
    reg [`DATA_TYPE] imm [`LS_SIZE-1:0];
    reg [`DATA_TYPE] V1 [`LS_SIZE-1:0];
    reg [`DATA_TYPE] V2 [`LS_SIZE-1:0];
    reg [`ROB_ID_TYPE] rob_id [`LS_SIZE-1:0];

    wire [`ADDR_TYPE] head_addr = V1[head] + imm[head];

    reg [3:0] ls_element_cnt;
    wire insert_cnt = (enable_sign_from_cmd ? 1 : 0);
    wire head_ready = busy[head] && full_sign_from_ls_ex == `FALSE && Q1[head] == `INVALID_ROB && Q2[head] == `INVALID_ROB;
    wire head_is_load = opnum[head] <= `OPNUM_LHU;
    wire commit_cnt = (head_ready && ((opnum[head] <= `OPNUM_LHU && (head_addr != `RAM_IO_ADDR || head_io_rob_id_from_rob == rob_id[head])) || commit[head])) ? 1 : 0;

    // calculate
    wire [`ROB_ID_TYPE] real_Q1 = (valid_sign_from_rs_ex && Q1_from_cmd == rob_id_from_rs_ex) ? `INVALID_ROB : ((valid_sign_from_ls_ex && Q1_from_cmd == rob_id_from_ls_ex) ? `INVALID_ROB : Q1_from_cmd);
    wire [`ROB_ID_TYPE] real_Q2 = (valid_sign_from_rs_ex && Q2_from_cmd == rob_id_from_rs_ex) ? `INVALID_ROB : ((valid_sign_from_ls_ex && Q2_from_cmd == rob_id_from_ls_ex) ? `INVALID_ROB : Q2_from_cmd);
    wire [`DATA_TYPE] real_V1 = (valid_sign_from_rs_ex && Q1_from_cmd == rob_id_from_rs_ex) ? data_from_rs_ex : ((valid_sign_from_ls_ex && Q1_from_cmd == rob_id_from_ls_ex) ? data_from_ls_ex : V1_from_cmd);
    wire [`DATA_TYPE] real_V2 = (valid_sign_from_rs_ex && Q2_from_cmd == rob_id_from_rs_ex) ? data_from_rs_ex : ((valid_sign_from_ls_ex && Q2_from_cmd == rob_id_from_ls_ex) ? data_from_ls_ex : V2_from_cmd);

    assign full_sign_to_fch = (ls_element_cnt >= `LS_SIZE - 5);

    assign io_rob_id_to_rob = (head_addr == `RAM_IO_ADDR) ? rob_id[head] : `INVALID_ROB;

    // always @(*) begin
    //     if (rollback_sign_from_rob) begin
    //         rollback_tail = head;
    //         for (tmp = head; tmp != tail; tmp = next_tmp) begin
    //             if (opnum[tmp] > `OPNUM_LHU && commit[tmp]) begin
    //                 // copy the store instruction
    //                 busy[rollback_tail] = busy[tmp];
    //                 commit[rollback_tail] = commit[tmp];
    //                 opnum[rollback_tail] = opnum[tmp];
    //                 Q1[rollback_tail] = Q1[tmp];
    //                 Q2[rollback_tail] = Q2[tmp];
    //                 V1[rollback_tail] = V1[tmp];
    //                 V2[rollback_tail] = V2[tmp];
    //                 imm[rollback_tail] = imm[tmp];
    //                 rob_id[rollback_tail] = rob_id[tmp];

    //                 // move the rollback_tail
    //                 rollback_tail = next_tail;
    //             end 
    //         end

    //         for (tmp = rollback_tail; tmp != tail; tmp = next_tmp) begin
    //             // clear
    //             busy[tmp] = `FALSE;
    //             commit[tmp] = `FALSE;
    //             opnum[tmp] = `OPNUM_NULL;
    //             imm[tmp] = `NULL;
    //             V1[tmp] = `NULL;
    //             V2[tmp] = `NULL;
    //             Q1[tmp] = `INVALID_ROB;
    //             Q2[tmp] = `INVALID_ROB;
    //             rob_id[tmp] = `INVALID_ROB;
    //         end
            
    //         // modify the tail & ls_element_cnt
    //         tail = rollback_tail;
    //         ls_element_cnt = ((tail >= head) ? tail - head + 1 : `LS_SIZE + tail - head + 1);
    //     end    
    // end

    always @(posedge clk) begin
        if (rst || (rollback_sign_from_rob && store_tail == `INVALID_LS)) begin
            ls_element_cnt <= `NULL;
            head <= `ZERO_LS;
            tail <= `ZERO_LS;
            store_tail <= `INVALID_LS;
            for (integer i = 0; i < `LS_SIZE; i = i + 1) begin
                busy[i] <= `FALSE;
                commit[i] <= `FALSE;
                opnum[i] <= `OPNUM_NULL;
                imm[i] <= `NULL;
                V1[i] <= `NULL;
                V2[i] <= `NULL;
                Q1[i] <= `INVALID_ROB;
                Q2[i] <= `INVALID_ROB;
                rob_id[i] <= `INVALID_ROB;
            end
            enable_sign_to_ls_ex <= `FALSE;
        end
        else if (~rdy) begin
        end
        else if (rollback_sign_from_rob) begin
            tail <= (store_tail == `LS_SIZE - 1) ? 0 : store_tail + 1;
            ls_element_cnt <= ((store_tail > head) ? store_tail - head + 1 : `LS_SIZE - head + store_tail + 1);
            for (integer i = 0; i < `LS_SIZE; i = i + 1) begin
                if (~commit[i] || opnum[i] <= `OPNUM_LHU) busy[i] <= `FALSE;
            end
        end
        else begin
            enable_sign_to_ls_ex <= `FALSE;
            ls_element_cnt <= ls_element_cnt - commit_cnt + insert_cnt;

            // $display(opnum[head]);
            if (head_ready) begin
                if (opnum[head] <= `OPNUM_LHU) begin
                    if (head_addr != `RAM_IO_ADDR || head_io_rob_id_from_rob == rob_id[head]) begin
                        busy[head] <= `FALSE;
                        commit[head] <= `FALSE;
                        rob_id_to_ls_ex <= rob_id[head];
                        rob_id[head] <= `INVALID_ROB;
                        enable_sign_to_ls_ex <= `TRUE;
                        opnum_to_ls_ex <= opnum[head];
                        addr_to_ls_ex <= head_addr;
                        head <= next_head;
                    end 
                end
                // store
                else if (commit[head]) begin
                    busy[head] <= `FALSE;
                    commit[head] <= `FALSE;
                    rob_id_to_ls_ex <= rob_id[head];
                    rob_id[head] <= `INVALID_ROB;
                    enable_sign_to_ls_ex <= `TRUE;
                    opnum_to_ls_ex <= opnum[head];
                    addr_to_ls_ex <= head_addr;
                    head <= next_head;
                    store_data_to_ls_ex <= V2[head];
                    if (store_tail == head) store_tail <= `INVALID_LS;
                end
            end

            // update commit sign
            if (commit_sign_from_rob) begin
                for (integer i = 0; i < `LS_SIZE; i = i + 1) begin
                    if (busy[i] && rob_id[i] == commit_rob_id_from_rob && !commit[i]) begin
                        commit[i] <= `TRUE;
                        if (opnum[i] >= `OPNUM_SB) store_tail <= i;
                    end
                end
            end 
            
            // update data
            if (valid_sign_from_rs_ex) begin
                for (integer i = 0; i < `LS_SIZE; i = i + 1) begin
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
                for (integer i = 0; i < `LS_SIZE; i = i + 1) begin
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

            // insert
            if (enable_sign_from_cmd) begin
                busy[tail] <= `TRUE;
                opnum[tail] <= opnum_from_cmd;          
                Q1[tail] <= real_Q1;
                Q2[tail] <= real_Q2;
                V1[tail] <= real_V1;
                V2[tail] <= real_V2;
                imm[tail] <= imm_from_cmd;
                rob_id[tail] <= rob_id_from_cmd;
                commit[tail] <= `FALSE;
                tail <= next_tail;
            end
        end
    end
endmodule