`include "defines.v"

// `include "riscv\src\defines.v"

module MemCtrl(
    input wire clk,
    input wire rst,
    input wire rdy,

    // from & to ram
    input wire uart_full_sign_from_ram,
    input wire [`MEMDATA_TYPE] data_from_ram,
    output reg [`MEMDATA_TYPE] data_to_ram,
    output reg [`ADDR_TYPE] addr_to_ram,
    output reg load_store_sign_to_ram,

    // from & to fetcher
    input wire [`ADDR_TYPE] pc_from_fch,
    input wire enable_sign_from_fch,
    input wire rollback_sign_from_fch,
    output reg finish_sign_to_fch,
    output reg [`ICACHE_INST_BLOCK_SIZE-1:0] inst_block_to_fch,

    // from & to LS_EX
    input wire [`DATA_TYPE] store_data_from_ls_ex,
    input wire [`ADDR_TYPE] addr_from_ls_ex,
    input wire enable_sign_from_ls_ex,
    input wire load_store_sign_from_ls_ex,
    input wire [2:0] size_from_ls_ex,
    output reg finish_sign_to_ls_ex,
    output reg [`DATA_TYPE] load_data_to_ls_ex
);

    // memctrl status
    parameter
        IDLE = 0, FETCH = 1, LOAD = 2, STORE = 3;
    reg[1:0] status;

    // ram data
    reg[`ADDR_TYPE] ram_access_pc;
    reg[`DATA_TYPE] store_data;
    reg[`INT_TYPE] ram_current_access, ram_access_end;

    // buffer
    reg load_store_is_buffered, inst_fetch_is_buffered;
    reg[`ADDR_TYPE] buffered_pc;
    reg buffered_load_store_sign;
    reg[2:0] buffered_size;
    reg[`ADDR_TYPE] buffered_addr;
    reg[`ADDR_TYPE] buffered_store_data;

    reg uart_write_is_io,uart_write_lock;

    reg enable_shadow_status, enable_shadow_if_is_buffered, enable_shadow_ls_is_buffered;

    wire [`STATUS_TYPE] real_status =(enable_shadow_status) ? IDLE : status;
    wire real_if_is_buffered = (enable_shadow_if_is_buffered) ? `FALSE : inst_fetch_is_buffered;
    wire real_ls_is_buffered = (enable_shadow_ls_is_buffered) ? `FALSE : load_store_is_buffered;

    always @(*) begin
        enable_shadow_status = `FALSE;
        enable_shadow_if_is_buffered = `FALSE;
        enable_shadow_ls_is_buffered = `FALSE;

        if (rollback_sign_from_fch) begin
            if (status == FETCH || status == LOAD) enable_shadow_status = `TRUE;
            enable_shadow_if_is_buffered = `TRUE;
            if (load_store_is_buffered && buffered_load_store_sign == `RAM_LOAD) enable_shadow_ls_is_buffered = `TRUE;
        end
    end


    always @(posedge clk) begin
        if (rst) begin
            status <= IDLE;
            ram_current_access <= `NULL;
            ram_access_end <= `NULL;
            ram_access_pc <= `NULL;
            inst_block_to_fch <= `NULLBLOCK;
            load_data_to_ls_ex <= `NULL;
            inst_fetch_is_buffered <= `FALSE;
            load_store_is_buffered <= `FALSE;
            uart_write_is_io <= `FALSE;
            uart_write_lock <= `FALSE;
        end
        else if (!rdy) begin
        end
        else begin
            finish_sign_to_fch <= `FALSE;
            finish_sign_to_ls_ex <= `FALSE;
            addr_to_ram <= `NULL;
            load_store_sign_to_ram <= `RAM_LOAD;

            if (enable_shadow_status) status <= IDLE;
            if (enable_shadow_if_is_buffered) inst_fetch_is_buffered <= `FALSE;
            if (enable_shadow_ls_is_buffered) load_store_is_buffered <= `FALSE;

            // conflict -> buffer
            if (real_status != IDLE || (enable_sign_from_fch && enable_sign_from_ls_ex)) begin
                // instruction fetch is of lower priority than load/store
                if (enable_sign_from_fch == `FALSE && enable_sign_from_ls_ex == `TRUE) begin
                    load_store_is_buffered <= `TRUE;
                    buffered_load_store_sign <= load_store_sign_from_ls_ex;
                    buffered_addr <= addr_from_ls_ex;
                    buffered_store_data <= store_data_from_ls_ex;
                    buffered_size <= size_from_ls_ex;
                end
                else if (enable_sign_from_fch == `TRUE) begin
                    inst_fetch_is_buffered <= `TRUE;
                    buffered_pc <= pc_from_fch;
                end
            end

            if (real_status == IDLE) begin
                // initialize
                finish_sign_to_fch <= `FALSE;
                finish_sign_to_ls_ex <= `FALSE;
                inst_block_to_fch <= `NULL;
                load_data_to_ls_ex <= `NULL;

                if (enable_sign_from_ls_ex) begin
                    if (load_store_sign_from_ls_ex == `RAM_STORE) begin
                        ram_current_access <= `NULL;
                        ram_access_end <= size_from_ls_ex;
                        ram_access_pc <= addr_from_ls_ex;
                        store_data <= store_data_from_ls_ex;
                        addr_to_ram <= `NULL;
                        load_store_sign_to_ram <= `RAM_LOAD;
                        status <= STORE;
                        uart_write_is_io <= (addr_from_ls_ex == `RAM_IO_ADDR);
                        uart_write_lock <= `FALSE;
                    end
                    else if (load_store_sign_from_ls_ex == `RAM_LOAD) begin
                        ram_current_access <= `NULL;
                        ram_access_end <= size_from_ls_ex;
                        addr_to_ram <= addr_from_ls_ex;
                        ram_access_pc <= addr_from_ls_ex+`RAM_PC_BIT;
                        load_store_sign_to_ram <= `RAM_LOAD;
                        status <= LOAD;
                    end
                end
                else if (real_ls_is_buffered) begin
                    if (buffered_load_store_sign == `RAM_STORE) begin
                        ram_current_access <= `NULL;
                        ram_access_end <= buffered_size;
                        ram_access_pc <= buffered_addr;
                        store_data <= buffered_store_data;
                        addr_to_ram <= `NULL;
                        load_store_sign_to_ram <= buffered_load_store_sign;
                        status <= STORE;
                    end
                    else if (buffered_load_store_sign == `RAM_LOAD) begin
                        ram_current_access <= `NULL;
                        ram_access_end <= buffered_size;
                        ram_access_pc <= buffered_addr + `RAM_PC_BIT;
                        addr_to_ram <= buffered_addr;
                        load_store_sign_to_ram <= buffered_load_store_sign;
                        status <= LOAD;
                    end
                    load_store_is_buffered <= `FALSE;
                end
                else if (enable_sign_from_fch) begin
                    ram_current_access <= `NULL;
                    ram_access_end <= `ICACHE_INST_BLOCK_SIZE / 8;
                    addr_to_ram <= pc_from_fch;
                    ram_access_pc <= pc_from_fch + `RAM_PC_BIT;
                    load_store_sign_to_ram <= `RAM_LOAD;
                    status <= FETCH;
                end
                else if (real_if_is_buffered) begin
                    ram_current_access <= `NULL;
                    ram_access_end <= `ICACHE_INST_BLOCK_SIZE / 8;
                    addr_to_ram <= buffered_pc;
                    ram_access_pc <= buffered_pc + `RAM_PC_BIT;
                    load_store_sign_to_ram <= `RAM_LOAD;
                    status <= FETCH;
                    inst_fetch_is_buffered <= `FALSE;
                end 
            end
            else if (!(uart_full_sign_from_ram && real_status == STORE)) begin
                if (real_status == FETCH) begin
                    // fetch
                    addr_to_ram <= ram_access_pc;
                    load_store_sign_to_ram <= `RAM_LOAD;
                    // ram_current_access = 0 at the beginning -> wait for a cycle to load the data from ram(compulsory)
                    case (ram_current_access)
                        32'd1: inst_block_to_fch[7:0] <= data_from_ram;
                        32'd2: inst_block_to_fch[15:8] <= data_from_ram;
                        32'd3: inst_block_to_fch[23:16] <= data_from_ram;
                        32'd4: inst_block_to_fch[31:24] <= data_from_ram;
                        32'd5: inst_block_to_fch[39:32] <= data_from_ram;
                        32'd6: inst_block_to_fch[47:40] <= data_from_ram;
                        32'd7: inst_block_to_fch[55:48] <= data_from_ram;
                        32'd8: inst_block_to_fch[63:56] <= data_from_ram;
                        32'd9: inst_block_to_fch[71:64] <= data_from_ram;
                        32'd10: inst_block_to_fch[79:72] <= data_from_ram;
                        32'd11: inst_block_to_fch[87:80] <= data_from_ram;
                        32'd12: inst_block_to_fch[95:88] <= data_from_ram;
                        32'd13: inst_block_to_fch[103:96] <= data_from_ram;
                        32'd14: inst_block_to_fch[111:104] <= data_from_ram;
                        32'd15: inst_block_to_fch[119:112] <= data_from_ram;
                        32'd16: inst_block_to_fch[127:120] <= data_from_ram;
                    endcase
                    ram_access_pc <= (ram_current_access >= ram_access_end-`RAM_PC_BIT) ? `NULL :ram_access_pc + `RAM_PC_BIT;
                    // stop
                    if (ram_current_access == ram_access_end) begin
                        finish_sign_to_fch <= `TRUE;
                        status <= IDLE;
                        ram_access_pc <= `NULL;
                        ram_current_access <= `NULL;
                    end
                    else begin
                        ram_current_access <= ram_current_access+`RAM_PC_BIT;
                    end
                end
                else if (real_status == LOAD) begin
                    // load
                    addr_to_ram <= ram_access_pc;
                    load_store_sign_to_ram <= `RAM_LOAD;
                    case (ram_current_access)
                        32'h1: load_data_to_ls_ex[7:0] <= data_from_ram;
                        32'h2: load_data_to_ls_ex[15:8] <= data_from_ram;
                        32'h3: load_data_to_ls_ex[23:16] <= data_from_ram;
                        32'h4: load_data_to_ls_ex[31:24] <= data_from_ram;
                    endcase
                    ram_access_pc <= (ram_current_access >= ram_access_end-`RAM_PC_BIT) ? `NULL :ram_access_pc+`RAM_PC_BIT;
                    // stop
                    if (ram_current_access == ram_access_end) begin
                        finish_sign_to_ls_ex <= `TRUE;
                        status <= IDLE;
                        ram_access_pc <= `NULL;
                        ram_current_access <= 0;
                    end
                    else begin
                        ram_current_access <= ram_current_access+`RAM_PC_BIT;
                    end
                end
                else if (real_status == STORE) begin
                    if (~uart_write_is_io || ~uart_write_lock) begin
                        uart_write_lock <= `TRUE;
                        // store
                        addr_to_ram <= ram_access_pc;
                        load_store_sign_to_ram <= `RAM_STORE;
                        // exit when ram_current_access == size -> wait the last data to store in ram
                        case (ram_current_access)
                            32'h0: data_to_ram <= store_data_from_ls_ex[7:0];
                            32'h1: data_to_ram <= store_data_from_ls_ex[15:8];
                            32'h2: data_to_ram <= store_data_from_ls_ex[23:16];
                            32'h3: data_to_ram <= store_data_from_ls_ex[31:24];
                        endcase
                        ram_access_pc <= (ram_current_access >= ram_access_end-`RAM_PC_BIT) ? `NULL :ram_access_pc+`RAM_PC_BIT;
                        // stop
                        if (ram_current_access == ram_access_end) begin
                            finish_sign_to_ls_ex <= `TRUE;
                            status <= IDLE;
                            ram_access_pc <= `NULL;
                            ram_current_access <= `NULL;
                            addr_to_ram <= `NULL;
                            load_store_sign_to_ram <= `RAM_LOAD;
                        end
                        else ram_current_access <= ram_current_access+`RAM_PC_BIT;
                    end
                    else uart_write_lock <= `FALSE;
                end
            end
        end
    end

endmodule