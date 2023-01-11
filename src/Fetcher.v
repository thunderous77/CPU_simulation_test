`include "defines.v"

// `include "riscv\src\defines.v"

module Fetcher(
    input wire clk,
    input wire rst,
    input wire rdy,

    // to commmander
    output reg [`ADDR_TYPE] pc_to_cmd,
    output reg [`ADDR_TYPE] rollback_pc_to_cmd,
    output reg predicted_jump_sign_to_cmd,
    output reg finish_sign_to_cmd,
    output reg [`INST_TYPE] inst_to_cmd,

    // from & to predictor
    input wire [`ADDR_TYPE] predicted_jump_target_pc_from_pdt,
    input wire predicted_jump_sign_from_pdt,
    output wire [`ADDR_TYPE] predict_pc_to_pdt,
    output wire [`INST_TYPE] predict_inst_to_pdt,

    // from & to memctrl
    input wire finish_sign_from_memctrl,
    input wire [`ICACHE_INST_BLOCK_SIZE-1:0] inst_block_from_memctrl,
    output reg [`ADDR_TYPE] pc_to_memctrl,
    output reg enable_sign_to_memctrl,
    output reg rollback_sign_to_memctrl,

    // from rob
    input wire rollback_sign_from_rob,
    input wire [`ADDR_TYPE] pc_from_rob,

    // from mutiple modules
    input wire full_sign
    
);

    // direct mapped icache
    reg valid [`ICACHE_SIZE-1:0];
    reg [`ICACHE_TAG_RANGE] tag_store[`ICACHE_SIZE-1:0];
    reg [`ICACHE_INST_BLOCK_SIZE-1:0] inst_block_in_cache[`ICACHE_SIZE-1:0];

    wire hit = valid[pc[`ICACHE_INDEX_RANGE]] && (tag_store[pc[`ICACHE_INDEX_RANGE]] == pc[`ICACHE_TAG_RANGE]); 
    wire [`INST_TYPE] ret_inst = (hit) ? (pc[`ICACHE_OFFSET_RANGE] == 0 ? inst_block_in_cache[pc[`ICACHE_INDEX_RANGE]][`ICACHE_FIRST_INST_RANGE]
                                       : (pc[`ICACHE_OFFSET_RANGE] == 1 ? inst_block_in_cache[pc[`ICACHE_INDEX_RANGE]][`ICACHE_SECOND_INST_RANGE]
                                       : (pc[`ICACHE_OFFSET_RANGE] == 2 ? inst_block_in_cache[pc[`ICACHE_INDEX_RANGE]][`ICACHE_THIRD_INST_RANGE]
                                       : inst_block_in_cache[pc[`ICACHE_INDEX_RANGE]][`ICACHE_FOURTH_INST_RANGE]))) : `NULL;

    // pc reg
    reg [`ADDR_TYPE] pc;

    // to predictor
    assign predict_pc_to_pdt = pc;
    assign predict_inst_to_pdt = ret_inst;

    // status--IDLE/FETCH
    parameter
    IDLE = 0, FETCH = 1;
    reg status;

    //debug
    // integer outfile;
    // initial begin
    //     outfile = $fopen("fetch.out");
    // end

    always @(posedge clk) begin
        // $fdisplay(outfile, "time = %d", $time);
        if (rst) begin
            // pc initilize
            pc <= `NULL;
            pc <= `NULL;
            // icache initialize
            for (integer i = 0; i < `ICACHE_SIZE; i = i + 1) begin
                valid[i] <= `FALSE;
                tag_store[i] <= `NULL;
                inst_block_in_cache[i] <= `NULL;
            end
            // output initialize
            pc_to_cmd <= `NULL;
            pc_to_memctrl <= `NULL;
            inst_to_cmd <= `NULL;
            finish_sign_to_cmd <= `FALSE;
            enable_sign_to_memctrl <= `FALSE;
            rollback_sign_to_memctrl <= `FALSE;
            // status initialize
            status <= IDLE;
        end
        else if (!rdy) begin
        end
        else if (rollback_sign_from_rob) begin
            finish_sign_to_cmd <= `FALSE;
            pc <= pc_from_rob;
            pc <= pc_from_rob;
            status <= IDLE;
            enable_sign_to_memctrl <= `FALSE;
            rollback_sign_to_memctrl <= `TRUE;
        end
        else begin
            if (hit && full_sign == `FALSE) begin
                // $fdisplay(outfile, "time = %d, pc = %x", $time, pc);
                // $fdisplay(outfile, "pc = %x", pc);
                pc_to_cmd <= pc;
                predicted_jump_sign_to_cmd <= predicted_jump_sign_from_pdt;
                pc <= pc + (predicted_jump_sign_from_pdt ? predicted_jump_target_pc_from_pdt : `PC_BIT);
                rollback_pc_to_cmd <= pc +`PC_BIT;
                inst_to_cmd <= ret_inst;
                finish_sign_to_cmd <= `TRUE;
            end
            else finish_sign_to_cmd <= `FALSE;
                
            enable_sign_to_memctrl <= `FALSE;
            rollback_sign_to_memctrl <= `FALSE;

            if (status == IDLE && ~hit) begin
                enable_sign_to_memctrl <= `TRUE;
                // fetch instruction from xxx00, xxx01, xxx10, xxx11
                pc_to_memctrl <= pc[`PC_TAG_AND_INDEX_RANGE] << 4;
                status <= FETCH;
            end
            else begin
                if (finish_sign_from_memctrl) begin
                    status <= IDLE;
                    valid[pc[`ICACHE_INDEX_RANGE]] <= `TRUE;
                    tag_store[pc[`ICACHE_INDEX_RANGE]] <= pc[`ICACHE_TAG_RANGE];
                    inst_block_in_cache[pc[`ICACHE_INDEX_RANGE]] <= inst_block_from_memctrl;            
                end
            end
        end
    end

    

endmodule