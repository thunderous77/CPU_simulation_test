// RISCV32I CPU top module
// port modification allowed for debugging purposes

module cpu(
    input wire clk_in,            // system clock signal
    input wire rst_in,            // reset signal
    input wire rdy_in,            // ready signal, pause cpu when low

    input wire[7:0] mem_din,        // data input bus
    output wire[7:0] mem_dout,        // data output bus
    output wire[31:0] mem_a,            // address bus (only 17:0 is used)
    output wire mem_wr,            // write/read signal (1 for write)

    input wire io_buffer_full, // 1 if uart buffer is full

    output wire[31:0] dbgreg_dout        // cpu register output (debugging demo)
);
    // implementation goes here

    // Specifications:
    // - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
    // - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
    // - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
    // - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
    // - 0x30000 read: read a byte from input
    // - 0x30000 write: write a byte to output (write 0x00 is ignored)
    // - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
    // - 0x30004 write: indicates program stop (will output '\0' through uart tx)

    // Memctrl & Fetcher
    wire [`ADDR_TYPE] pc_from_fch_to_memctrl;
    wire [`ICACHE_INST_BLOCK_SIZE-1:0] inst_block_from_memctrl_to_fch;
    wire enable_sign_from_fch_to_memctrl;
    wire rollback_sign_from_fch_to_memctrl;
    wire finish_sign_from_memctrl_to_fch;

    // Memctrl & LS_EX
    wire enable_sign_from_ls_ex_to_memctrl;
    wire load_store_sign_from_ls_ex_to_memctrl;
    wire finish_sign_from_memctrl_to_ls_ex;
    wire [2:0] size_from_ls_ex_to_memctrl;
    wire [`DATA_TYPE] store_data_from_ls_ex_to_memctrl;
    wire [`DATA_TYPE] load_data_from_memctrl_to_ls_ex;
    wire [`ADDR_TYPE] addr_from_ls_ex_to_memctrl;

    // Fetcher & Predictor
    wire predicted_jump_sign_from_pdt_to_fch;
    wire [`ADDR_TYPE] predicted_jump_target_pc_from_pdt_to_fch;
    wire [`ADDR_TYPE] predict_pc_from_fch_to_pdt;
    wire [`INST_TYPE] predict_inst_from_fch_to_pdt;
    
    // Fetcher & Commander
    wire finish_sign_from_fch_to_cmd;
    wire [`INST_TYPE] inst_from_fch_to_cmd;
    wire [`ADDR_TYPE] pc_from_fch_to_cmd;
    wire [`ADDR_TYPE] rollback_pc_from_fch_to_cmd;
    wire predicted_jump_sign_from_fch_to_cmd;

    // Fetcher & ROB
    wire [`ADDR_TYPE] rollback_pc_from_rob_to_fch;

    // full sign to Fetcher
    wire full_sign_from_rs, full_sign_from_ls, full_sign_from_rob;
    wire full_sign_to_fch = (full_sign_from_ls || full_sign_from_rs || full_sign_from_rob);

    // ROB & Predictor
    wire jump_sign_from_rob_to_pdt;
    wire enable_sign_from_rob_to_pdt;
    wire [`ADDR_TYPE] jump_target_pc_from_rob_to_pdt;

    // ROB & Register
    wire [`DATA_TYPE] V_from_rob_to_reg;
    wire [`ROB_ID_TYPE] Q_from_rob_to_reg;
    wire [`REG_POS_TYPE] rd_from_rob_to_reg;

    // ROB & Commander
    wire [`ROB_ID_TYPE] Q1_from_cmd_to_rob;
    wire [`ROB_ID_TYPE] Q2_from_cmd_to_rob;
    wire Q1_ready_sign_from_rob_to_cmd;
    wire Q2_ready_sign_from_rob_to_cmd;
    wire [`DATA_TYPE] V1_from_rob_to_cmd;
    wire [`DATA_TYPE] V2_from_rob_to_cmd;
    wire enable_sign_from_cmd_to_rob;
    wire is_jump_inst_from_cmd_to_rob;
    wire is_store_inst_from_cmd_to_rob;
    wire predicted_jump_sign_from_cmd_to_rob;
    wire [`REG_POS_TYPE] rd_from_cmd_to_rob;
    wire [`ADDR_TYPE] pc_from_cmd_to_rob;
    wire [`ADDR_TYPE] rollback_pc_from_cmd_to_rob;
    wire [`ROB_ID_TYPE] rob_id_from_rob_to_cmd;

    // ROB & LS
    wire [`ROB_ID_TYPE] head_io_rob_id_from_rob_to_ls;
    wire [`ROB_ID_TYPE] io_rob_id_from_ls_to_rob;
    wire [`ROB_ID_TYPE] commit_rob_id_from_rob_to_ls;

    // Commander & Register
    wire [`ROB_ID_TYPE] Q1_from_reg_to_cmd;
    wire [`ROB_ID_TYPE] Q2_from_reg_to_cmd;
    wire [`DATA_TYPE] V1_from_reg_to_cmd;
    wire [`DATA_TYPE] V2_from_reg_to_cmd;
    wire enable_sign_from_cmd_to_reg;
    wire [`REG_POS_TYPE] rd_from_cmd_to_reg;
    wire [`ROB_ID_TYPE] rd_rob_id_from_cmd_to_reg;
    wire [`REG_POS_TYPE] rs1_from_cmd_to_reg;
    wire [`REG_POS_TYPE] rs2_from_cmd_to_reg;

    // Commander & RS
    wire enable_sign_from_cmd_to_rs;
    wire [`OPNUM_TYPE] opnum_from_cmd_to_rs;
    wire [`DATA_TYPE] V1_from_cmd_to_rs;
    wire [`DATA_TYPE] V2_from_cmd_to_rs;
    wire [`ROB_ID_TYPE] Q1_from_cmd_to_rs;
    wire [`ROB_ID_TYPE] Q2_from_cmd_to_rs;
    wire [`ADDR_TYPE] pc_from_cmd_to_rs;
    wire [`DATA_TYPE] imm_from_cmd_to_rs;
    wire [`ROB_ID_TYPE] rob_id_from_cmd_to_rs;

    // Commander & LS
    wire enable_sign_from_cmd_to_ls;
    wire [`OPNUM_TYPE] opnum_from_cmd_to_ls;
    wire [`DATA_TYPE] V1_from_cmd_to_ls;
    wire [`DATA_TYPE] V2_from_cmd_to_ls;
    wire [`ROB_ID_TYPE] Q1_from_cmd_to_ls;
    wire [`ROB_ID_TYPE] Q2_from_cmd_to_ls;
    wire [`DATA_TYPE] imm_from_cmd_to_ls;
    wire [`ROB_ID_TYPE] rob_id_from_cmd_to_ls;

    // RS & RS_EX
    wire [`OPNUM_TYPE] opnum_from_rs_to_rs_ex;
    wire [`DATA_TYPE] V1_from_rs_to_rs_ex;
    wire [`DATA_TYPE] V2_from_rs_to_rs_ex;
    wire [`DATA_TYPE] imm_from_rs_to_rs_ex;
    wire [`ADDR_TYPE] pc_from_rs_to_rs_ex;
    wire [`ROB_ID_TYPE] rob_id_from_rs_to_rs_ex;

    // LSB & LS_EX
    wire full_sign_from_ls_ex_to_ls;
    wire enable_sign_from_ls_to_ls_ex;
    wire [`OPNUM_TYPE] opnum_from_ls_to_ls_ex;
    wire [`ADDR_TYPE] addr_from_ls_to_ls_ex;
    wire [`DATA_TYPE] store_data_from_ls_to_ls_ex;
    wire [`ROB_ID_TYPE] rob_id_from_ls_to_ls_ex;

    // Global
    // from RS_EX
    wire valid_sign_from_rs_ex;
    wire jump_sign_from_rs_ex;
    wire [`ADDR_TYPE] jump_target_pc_from_rs_ex;
    wire [`DATA_TYPE] data_from_rs_ex;
    wire [`ROB_ID_TYPE] rob_id_from_rs_ex;

    // from LS_EX
    wire valid_sign_from_ls_ex;
    wire [`DATA_TYPE] data_from_ls_ex;
    wire [`ROB_ID_TYPE] rob_id_from_ls_ex;

    // from ROB
    wire commit_sign_from_rob;
    wire rollback_sign_from_rob;

    MemCtrl memctrl (
        .clk(clk_in),
        .rst(rst_in),
        .rdy(rdy_in),
        .uart_full_sign_from_ram(io_buffer_full),
        .data_from_ram(mem_din),
        .data_to_ram(mem_dout),
        .addr_to_ram(mem_a),
        .load_store_sign_to_ram(mem_wr),
        .pc_from_fch(pc_from_fch_to_memctrl),
        .enable_sign_from_fch(enable_sign_from_fch_to_memctrl),
        .rollback_sign_from_fch(rollback_sign_from_fch_to_memctrl),
        .finish_sign_to_fch(finish_sign_from_memctrl_to_fch),
        .inst_block_to_fch(inst_block_from_memctrl_to_fch),
        .store_data_from_ls_ex(store_data_from_ls_ex_to_memctrl),
        .addr_from_ls_ex(addr_from_ls_ex_to_memctrl),
        .enable_sign_from_ls_ex(enable_sign_from_ls_ex_to_memctrl),
        .load_store_sign_from_ls_ex(load_store_sign_from_ls_ex_to_memctrl),
        .size_from_ls_ex(size_from_ls_ex_to_memctrl),
        .finish_sign_to_ls_ex(finish_sign_from_memctrl_to_ls_ex),
        .load_data_to_ls_ex(load_data_from_memctrl_to_ls_ex)
    );

    ROB rob (
        .clk(clk_in),
        .rst(rst_in),
        .rdy(rdy_in),
        .Q1_from_cmd(Q1_from_cmd_to_rob),
        .Q2_from_cmd(Q2_from_cmd_to_rob),
        .Q1_ready_sign_to_cmd(Q1_ready_sign_from_rob_to_cmd),
        .Q2_ready_sign_to_cmd(Q2_ready_sign_from_rob_to_cmd),
        .V1_to_cmd(V1_from_rob_to_cmd),
        .V2_to_cmd(V2_from_rob_to_cmd),
        .enable_sign_from_cmd(enable_sign_from_cmd_to_rob),
        .is_jump_inst_from_cmd(is_jump_inst_from_cmd_to_rob),
        .is_store_inst_from_cmd(is_store_inst_from_cmd_to_rob),
        .predicted_jump_sign_from_cmd(predicted_jump_sign_from_cmd_to_rob),
        .rd_from_cmd(rd_from_cmd_to_rob),
        .pc_from_cmd(pc_from_cmd_to_rob),
        .rollback_pc_from_cmd(rollback_pc_from_cmd_to_rob),
        .rob_id_to_cmd(rob_id_from_rob_to_cmd),
        .rd_to_reg(rd_from_rob_to_reg),
        .Q_to_reg(Q_from_rob_to_reg),
        .V_to_reg(V_from_rob_to_reg),
        .full_sign_to_fch(full_sign_from_rob),
        .rollback_pc_to_fch(rollback_pc_from_rob_to_fch),
        .enable_sign_to_pdt(enable_sign_from_rob_to_pdt),
        .jump_sign_to_pdt(jump_sign_from_rob_to_pdt),
        .jump_target_pc_to_pdt(jump_target_pc_from_rob_to_pdt),
        .commit_rob_id_to_ls(commit_rob_id_from_rob_to_ls),
        .io_rob_id_from_ls(io_rob_id_from_ls_to_rob),
        .head_io_rob_id_to_ls(head_io_rob_id_from_rob_to_ls),
        .rob_id_from_rs_ex(rob_id_from_rs_ex),
        .valid_sign_from_rs_ex(valid_sign_from_rs_ex),
        .data_from_rs_ex(data_from_rs_ex),
        .jump_target_pc_from_rs_ex(jump_target_pc_from_rs_ex),
        .jump_sign_from_rs_ex(jump_sign_from_rs_ex),
        .valid_sign_from_ls_ex(valid_sign_from_ls_ex),
        .rob_id_from_ls_ex(rob_id_from_ls_ex),
        .data_from_ls_ex(data_from_ls_ex),
        .rollback_sign(rollback_sign_from_rob),
        .commit_sign(commit_sign_from_rob)
    );

    Predictor predictor (
        .clk(clk_in),
        .rst(rst_in),
        .predict_pc_from_fch(predict_pc_from_fch_to_pdt),
        .predict_inst_from_fch(predict_inst_from_fch_to_pdt),
        .predicted_jump_sign_to_fch(predicted_jump_sign_from_pdt_to_fch),
        .predicted_jump_target_pc_to_fch(predicted_jump_target_pc_from_pdt_to_fch),
        .jump_sign_from_rob(jump_sign_from_rob_to_pdt),
        .enable_sign_from_rob(enable_sign_from_rob_to_pdt),
        .jump_target_pc_from_rob(jump_target_pc_from_rob_to_pdt)
    );

    Register register (
        .clk(clk_in),
        .rst(rst_in),
        .enable_sign_from_cmd(enable_sign_from_cmd_to_reg),
        .rd_from_cmd(rd_from_cmd_to_reg),
        .rd_rob_id_from_cmd(rd_rob_id_from_cmd_to_reg),
        .rs1_from_cmd(rs1_from_cmd_to_reg),
        .rs2_from_cmd(rs2_from_cmd_to_reg),
        .V1_to_cmd(V1_from_reg_to_cmd),
        .V2_to_cmd(V2_from_reg_to_cmd),
        .Q1_to_cmd(Q1_from_reg_to_cmd),
        .Q2_to_cmd(Q2_from_reg_to_cmd),
        .commit_sign_from_rob(commit_sign_from_rob),
        .rollback_sign_from_rob(rollback_sign_from_rob),
        .V_from_rob(V_from_rob_to_reg),
        .Q_from_rob(Q_from_rob_to_reg),
        .rd_from_rob(rd_from_rob_to_reg)
    );

    Fetcher fetcher (
        .clk(clk_in),
        .rst(rst_in),
        .rdy(rdy_in),
        .pc_to_cmd(pc_from_fch_to_cmd),
        .rollback_pc_to_cmd(rollback_pc_from_fch_to_cmd),
        .predicted_jump_sign_to_cmd(predicted_jump_sign_from_fch_to_cmd),
        .finish_sign_to_cmd(finish_sign_from_fch_to_cmd),
        .inst_to_cmd(inst_from_fch_to_cmd),
        .predicted_jump_target_pc_from_pdt(predicted_jump_target_pc_from_pdt_to_fch),
        .predicted_jump_sign_from_pdt(predicted_jump_sign_from_pdt_to_fch),
        .predict_pc_to_pdt(predict_pc_from_fch_to_pdt),
        .predict_inst_to_pdt(predict_inst_from_fch_to_pdt),
        .finish_sign_from_memctrl(finish_sign_from_memctrl_to_fch),
        .inst_block_from_memctrl(inst_block_from_memctrl_to_fch),
        .pc_to_memctrl(pc_from_fch_to_memctrl),
        .enable_sign_to_memctrl(enable_sign_from_fch_to_memctrl),
        .rollback_sign_to_memctrl(rollback_sign_from_fch_to_memctrl),
        .rollback_sign_from_rob(rollback_sign_from_rob),
        .pc_from_rob(rollback_pc_from_rob_to_fch),
        .full_sign(full_sign_to_fch)
    );

    Commander commander (
        .clk(clk_in),
        .rst(rst_in),
        .rdy(rdy_in),
        .finish_flag_from_fch(finish_sign_from_fch_to_cmd),
        .inst_from_fch(inst_from_fch_to_cmd),
        .pc_from_fch(pc_from_fch_to_cmd),
        .predicted_jump_sign_from_fch(predicted_jump_sign_from_fch_to_cmd),
        .rollback_pc_from_fch(rollback_pc_from_fch_to_cmd),
        .rollback_sign_from_rob(rollback_sign_from_rob),
        .Q1_ready_sign_from_rob(Q1_ready_sign_from_rob_to_cmd),
        .Q2_ready_sign_from_rob(Q2_ready_sign_from_rob_to_cmd),
        .V1_from_rob(V1_from_rob_to_cmd),
        .V2_from_rob(V2_from_rob_to_cmd),
        .Q1_to_rob(Q1_from_cmd_to_rob),
        .Q2_to_rob(Q2_from_cmd_to_rob),
        .rob_id_from_rob(rob_id_from_rob_to_cmd),
        .enable_sign_to_rob(enable_sign_from_cmd_to_rob),
        .rd_to_rob(rd_from_cmd_to_rob),
        .is_jump_inst_to_rob(is_jump_inst_from_cmd_to_rob),
        .is_store_inst_to_rob(is_store_inst_from_cmd_to_rob),
        .predicted_jump_sign_to_rob(predicted_jump_sign_from_cmd_to_rob),
        .pc_to_rob(pc_from_cmd_to_rob),
        .rollback_pc_to_rob(rollback_pc_from_cmd_to_rob),
        .Q1_from_reg(Q1_from_reg_to_cmd),
        .Q2_from_reg(Q2_from_reg_to_cmd),
        .V1_from_reg(V1_from_reg_to_cmd),
        .V2_from_reg(V2_from_reg_to_cmd),
        .rs1_to_reg(rs1_from_cmd_to_reg),
        .rs2_to_reg(rs2_from_cmd_to_reg),
        .enable_sign_to_reg(enable_sign_from_cmd_to_reg),
        .rd_to_reg(rd_from_cmd_to_reg),
        .rd_rob_id_to_reg(rd_rob_id_from_cmd_to_reg),
        .enable_sign_to_rs(enable_sign_from_cmd_to_rs),
        .opnum_to_rs(opnum_from_cmd_to_rs),
        .V1_to_rs(V1_from_cmd_to_rs),
        .V2_to_rs(V2_from_cmd_to_rs),
        .Q1_to_rs(Q1_from_cmd_to_rs),
        .Q2_to_rs(Q2_from_cmd_to_rs),
        .pc_to_rs(pc_from_cmd_to_rs),
        .imm_to_rs(imm_from_cmd_to_rs),
        .rob_id_to_rs(rob_id_from_cmd_to_rs),
        .rob_id_from_rs_ex(rob_id_from_rs_ex),
        .valid_sign_from_rs_ex(valid_sign_from_rs_ex),
        .data_from_rs_ex(data_from_rs_ex),
        .enable_sign_to_ls(enable_sign_from_cmd_to_ls),
        .opnum_to_ls(opnum_from_cmd_to_ls),
        .V1_to_ls(V1_from_cmd_to_ls),
        .V2_to_ls(V2_from_cmd_to_ls),
        .Q1_to_ls(Q1_from_cmd_to_ls),
        .Q2_to_ls(Q2_from_cmd_to_ls),
        .imm_to_ls(imm_from_cmd_to_ls),
        .rob_id_to_ls(rob_id_from_cmd_to_ls),
        .rob_id_from_ls_ex(rob_id_from_ls_ex),
        .valid_sign_from_ls_ex(valid_sign_from_ls_ex),
        .data_from_ls_ex(data_from_ls_ex)
    );

    RS rs (
        .clk(clk_in),
        .rst(rst_in),
        .rdy(rdy_in),
        .enable_sign_from_cmd(enable_sign_from_cmd_to_rs),
        .opnum_from_cmd(opnum_from_cmd_to_rs),
        .V1_from_cmd(V1_from_cmd_to_rs),
        .V2_from_cmd(V2_from_cmd_to_rs),
        .Q1_from_cmd(Q1_from_cmd_to_rs),
        .Q2_from_cmd(Q2_from_cmd_to_rs),
        .pc_from_cmd(pc_from_cmd_to_rs),
        .imm_from_cmd(imm_from_cmd_to_rs),
        .rob_id_from_cmd(rob_id_from_cmd_to_rs),
        .valid_sign_from_rs_ex(valid_sign_from_rs_ex),
        .rob_id_from_rs_ex(rob_id_from_rs_ex),
        .data_from_rs_ex(data_from_rs_ex),
        .opnum_to_rs_ex(opnum_from_rs_to_rs_ex),
        .V1_to_rs_ex(V1_from_rs_to_rs_ex),
        .V2_to_rs_ex(V2_from_rs_to_rs_ex),
        .pc_to_rs_ex(pc_from_rs_to_rs_ex),
        .imm_to_rs_ex(imm_from_rs_to_rs_ex),
        .rob_id_to_rs_ex(rob_id_from_rs_to_rs_ex),
        .valid_sign_from_ls_ex(valid_sign_from_ls_ex),
        .rob_id_from_ls_ex(rob_id_from_ls_ex),
        .data_from_ls_ex(data_from_ls_ex),
        .rollback_sign_from_rob(rollback_sign_from_rob),
        .full_sign_to_if(full_sign_from_rs)
    );

    RS_EX rs_ex (
        .opnum_from_rs(opnum_from_rs_to_rs_ex),
        .V1_from_rs(V1_from_rs_to_rs_ex),
        .V2_from_rs(V2_from_rs_to_rs_ex),
        .imm_from_rs(imm_from_rs_to_rs_ex),
        .pc_from_rs(pc_from_rs_to_rs_ex),
        .rob_id_from_rs(rob_id_from_rs_to_rs_ex),
        .data(data_from_rs_ex),
        .jump_target_pc(jump_target_pc_from_rs_ex),
        .jump_sign(jump_sign_from_rs_ex),
        .valid_sign(valid_sign_from_rs_ex),
        .rob_id(rob_id_from_rs_ex)
    );

    LS ls (
        .clk(clk_in),
        .rst(rst_in),
        .rdy(rdy_in),
        .enable_sign_from_cmd(enable_sign_from_cmd_to_ls),
        .opnum_from_cmd(opnum_from_cmd_to_ls),
        .V1_from_cmd(V1_from_cmd_to_ls),
        .V2_from_cmd(V2_from_cmd_to_ls),
        .Q1_from_cmd(Q1_from_cmd_to_ls),
        .Q2_from_cmd(Q2_from_cmd_to_ls),
        .imm_from_cmd(imm_from_cmd_to_ls),
        .rob_id_from_cmd(rob_id_from_cmd_to_ls),
        .rollback_sign_from_rob(rollback_sign_from_rob),
        .commit_sign_from_rob(commit_sign_from_rob),
        .commit_rob_id_from_rob(commit_rob_id_from_rob_to_ls),
        .head_io_rob_id_from_rob(head_io_rob_id_from_rob_to_ls),
        .io_rob_id_to_rob(io_rob_id_from_ls_to_rob),
        .rob_id_from_rs_ex(rob_id_from_rs_ex),
        .data_from_rs_ex(data_from_rs_ex),
        .valid_sign_from_rs_ex(valid_sign_from_rs_ex),
        .full_sign_from_ls_ex(full_sign_from_ls_ex_to_ls),
        .valid_sign_from_ls_ex(valid_sign_from_ls_ex),
        .rob_id_from_ls_ex(rob_id_from_ls_ex),
        .data_from_ls_ex(data_from_ls_ex),
        .rob_id_to_ls_ex(rob_id_from_ls_to_ls_ex),
        .enable_sign_to_ls_ex(enable_sign_from_ls_to_ls_ex),
        .opnum_to_ls_ex(opnum_from_ls_to_ls_ex),
        .addr_to_ls_ex(addr_from_ls_to_ls_ex),
        .store_data_to_ls_ex(store_data_from_ls_to_ls_ex),
        .full_sign_to_fch(full_sign_from_ls)
    );

    LS_EX ls_ex (
        .clk(clk_in),
        .rst(rst_in),
        .rdy(rdy_in),
        .enable_sign_from_ls(enable_sign_from_ls_to_ls_ex),
        .opnum_from_ls(opnum_from_ls_to_ls_ex),
        .addr_from_ls(addr_from_ls_to_ls_ex),
        .store_data_from_ls(store_data_from_ls_to_ls_ex),
        .rob_id_from_ls(rob_id_from_ls_to_ls_ex),
        .full_sign_to_ls(full_sign_from_ls_ex_to_ls),
        .finish_sign_from_memctrl(finish_sign_from_memctrl_to_ls_ex),
        .load_data_from_memctrl(load_data_from_memctrl_to_ls_ex),
        .enable_sign_to_memctrl(enable_sign_from_ls_ex_to_memctrl),
        .addr_to_memctrl(addr_from_ls_ex_to_memctrl),
        .store_data_to_memctrl(store_data_from_ls_ex_to_memctrl),
        .size_to_memctrl(size_from_ls_ex_to_memctrl),
        .load_store_sign_to_memctrl(load_store_sign_from_ls_ex_to_memctrl),
        .rollback_sign_from_rob(rollback_sign_from_rob),
        .valid_sign(valid_sign_from_ls_ex),
        .data(data_from_ls_ex),
        .rob_id(rob_id_from_ls_ex)
    );

endmodule