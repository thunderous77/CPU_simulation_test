`include "defines.v"

// `include "riscv\src\defines.v"

module LS_EX (
    input wire clk,
    input wire rst,
    input wire rdy,

    // from & to ls
    input enable_sign_from_ls,
    input wire [`OPNUM_TYPE] opnum_from_ls,
    input wire [`ADDR_TYPE] addr_from_ls,
    input wire [`DATA_TYPE] store_data_from_ls,
    input wire [`ROB_ID_TYPE] rob_id_from_ls,
    output wire full_sign_to_ls,

    // to Memctrl
    input wire finish_sign_from_memctrl,
    input wire [`DATA_TYPE] load_data_from_memctrl,    
    output reg enable_sign_to_memctrl,
    output reg [`ADDR_TYPE] addr_to_memctrl,
    output reg [`DATA_TYPE] store_data_to_memctrl,
    output reg [2:0] size_to_memctrl,
    output reg load_store_sign_to_memctrl,

    // from rob
    input wire rollback_sign_from_rob,

    // global output
    output reg valid_sign,
    output reg [`DATA_TYPE] data,
    output wire [`ROB_ID_TYPE] rob_id
);

    parameter STATUS_IDLE = 0, STATUS_LB = 1, STATUS_LH = 2, STATUS_LW = 3, STATUS_LBU = 4,  STATUS_LHU = 5, STATUS_STORE = 6;
    reg [2:0] status;

    assign full_sign_to_ls = (status != STATUS_IDLE || enable_sign_from_ls);
    assign rob_id = rob_id_from_ls;

    // debug
    // integer outfile;
    // initial begin
    //     outfile = $fopen("ls_ex.out");
    // end

    always @(posedge clk) begin
        if (rst) begin
            enable_sign_to_memctrl <= `FALSE;
            valid_sign <= `FALSE;
            status <= STATUS_IDLE;
        end
        else if (~rdy) begin
        end
        else begin
            if (status != STATUS_IDLE) begin
                enable_sign_to_memctrl <= `FALSE;
                if (rollback_sign_from_rob && status != STATUS_STORE) status = STATUS_IDLE;
                else begin
                    if (finish_sign_from_memctrl) begin
                        if (status != STATUS_STORE) begin
                            valid_sign <= `TRUE;
                            case (status)
                                STATUS_LB: data <= {{25{load_data_from_memctrl[7]}},load_data_from_memctrl[6:0]};
                                STATUS_LH: data <= {{17{load_data_from_memctrl[15]}},load_data_from_memctrl[14:0]};
                                STATUS_LW: data <= load_data_from_memctrl;
                                STATUS_LBU: data <= {24'b0,load_data_from_memctrl[7:0]};
                                STATUS_LHU: data <= {16'b0,load_data_from_memctrl[15:0]};
                            endcase
                            // $fdisplay(outfile, "time = %d, opnum = %d,load_value = %d, mem_addr = %d", $time, opnum_from_ls, load_data_from_memctrl, addr_from_ls);
                        end
                        status <= STATUS_IDLE;
                    end
                end
            end
            else begin
                valid_sign <= `FALSE;
                if (enable_sign_from_ls == `FALSE || opnum_from_ls == `OPNUM_NULL) enable_sign_to_memctrl <=`FALSE;
                else begin
                    enable_sign_to_memctrl <= `TRUE;
                    case (opnum_from_ls)
                        `OPNUM_LB: begin
                            addr_to_memctrl <= addr_from_ls;
                            load_store_sign_to_memctrl <= `RAM_LOAD;
                            size_to_memctrl <= 1;
                            status <= STATUS_LB;
                        end

                        `OPNUM_LH: begin
                            addr_to_memctrl <= addr_from_ls;
                            load_store_sign_to_memctrl <= `RAM_LOAD;
                            size_to_memctrl <= 2;
                            status <= STATUS_LH;
                        end

                        `OPNUM_LW: begin
                            addr_to_memctrl <= addr_from_ls;
                            load_store_sign_to_memctrl <= `RAM_LOAD;
                            size_to_memctrl <= 4;
                            status <= STATUS_LW;
                        end

                        `OPNUM_LBU: begin
                            addr_to_memctrl <= addr_from_ls;
                            load_store_sign_to_memctrl <= `RAM_LOAD;
                            size_to_memctrl <= 2;
                            status <= STATUS_LBU;
                        end

                        `OPNUM_LHU: begin
                            addr_to_memctrl <= addr_from_ls;
                            load_store_sign_to_memctrl <= `RAM_LOAD;
                            size_to_memctrl <= 4;
                            status <= STATUS_LHU;
                        end

                        `OPNUM_SB: begin
                            addr_to_memctrl <= addr_from_ls;
                            store_data_to_memctrl <= store_data_from_ls;
                            load_store_sign_to_memctrl <= `RAM_STORE;
                            size_to_memctrl <= 1;
                            status <= STATUS_STORE;
                        end

                        `OPNUM_SH: begin
                            addr_to_memctrl <= addr_from_ls;
                            store_data_to_memctrl <= store_data_from_ls;
                            load_store_sign_to_memctrl <= `RAM_STORE;
                            size_to_memctrl <= 2;
                            status <= STATUS_STORE;
                        end

                        `OPNUM_SW: begin
                            addr_to_memctrl <= addr_from_ls;
                            store_data_to_memctrl <= store_data_from_ls;
                            load_store_sign_to_memctrl <= `RAM_STORE;
                            size_to_memctrl <= 4;
                            status <= STATUS_STORE;
                        end
                    endcase
                    // if (opnum_from_ls>=`OPNUM_SB) $fdisplay(outfile, "opnum = %d, store_value = %d, mem_addr = %d", opnum_from_ls, store_data_from_ls, addr_from_ls);
                end
            end
        end
    end

endmodule