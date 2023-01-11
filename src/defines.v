// basic type
`define INST_SIZE 32
`define INST_TYPE 31:0
`define ADDR_TYPE 31:0
`define STATUS_TYPE 2:0
`define DATA_TYPE 31:0
`define MEMDATA_TYPE 7:0
`define INT_TYPE 31:0

// parameter
// ICache
`define ICACHE_SIZE 256
`define ICACHE_INST_BLOCK_SIZE 128
`define ICACHE_FIRST_INST_RANGE 31:0
`define ICACHE_SECOND_INST_RANGE 63:32
`define ICACHE_THIRD_INST_RANGE 95:64
`define ICACHE_FOURTH_INST_RANGE 127:96
`define ICACHE_INDEX_RANGE 11:4
`define ICACHE_TAG_RANGE 31:12
`define ICACHE_OFFSET_RANGE 3:2

// Predictor
`define PREDICTOR_BIT 2
`define PREDICTOR_SIZE 256
`define PREDICTOR_ADDR_RANGE 9:2
`define STRONG_NOT_JUMP  2'b00
`define WEAK_NOT_JUMP 2'b01
`define WEAK_JUMP 2'b10
`define STRONG_JUMP 2'b11

// Ram
`define RAM_LOAD 1'b0
`define RAM_STORE 1'b1
`define RAM_IO_ADDR 32'h30000

// Fetcher
`define INST_SIZE 32'h4
`define PC_TAG_AND_INDEX_RANGE 31:4
`define MEM_BLOCK_BIT 32'h16

// Register
`define ZERO_REG 5'h0
`define REG_SIZE 32
`define REG_POS_TYPE 4:0

// Reorder Buffer(ROB)
// INVALID_ROB -> INVALID 
// VALID ROB ID -> 5'd1 - 5d'16
`define INVALID_ROB 4'h0
`define ROB_SIZE 16
`define ROB_ID_TYPE 4:0
`define ROB_POS_TYPE 3: 0

// RS
`define RS_SIZE 16
`define RS_ID_TYPE 4:0
`define ZERO_RS 5'h0
`define INVALID_RS 5'h10

// LS Buffer
`define LS_SIZE 16
`define LS_ID_TYPE 4:0
`define ZERO_LS 5'h0
`define INVALID_LS 5'h10

// constant
`define FALSE 1'b0
`define TRUE 1'b1
`define NULL 32'h0
`define NULLBLOCK 127'h0
`define PC_BIT 32'h4
`define RAM_PC_BIT 32'h1

// Decode 
`define OPNUM_TYPE 5:0
`define OPNUM_NULL    6'd0

`define OPNUM_LUI     6'd1
`define OPNUM_AUIPC   6'd2

`define OPNUM_JAL     6'd3
`define OPNUM_JALR    6'd4

`define OPNUM_BEQ     6'd5
`define OPNUM_BNE     6'd6
`define OPNUM_BLT     6'd7 
`define OPNUM_BGE     6'd8
`define OPNUM_BLTU    6'd9 
`define OPNUM_BGEU    6'd10 

`define OPNUM_LB      6'd11 
`define OPNUM_LH      6'd12 
`define OPNUM_LW      6'd13 
`define OPNUM_LBU     6'd14 
`define OPNUM_LHU     6'd15 
`define OPNUM_SB      6'd16 
`define OPNUM_SH      6'd17 
`define OPNUM_SW      6'd18 

`define OPNUM_ADD     6'd19 
`define OPNUM_SUB     6'd20 
`define OPNUM_SLL     6'd21 
`define OPNUM_SLT     6'd22 
`define OPNUM_SLTU    6'd23 
`define OPNUM_XOR     6'd24 
`define OPNUM_SRL     6'd25 
`define OPNUM_SRA     6'd26
`define OPNUM_OR      6'd27 
`define OPNUM_AND     6'd28

`define OPNUM_ADDI    6'd29
`define OPNUM_SLTI    6'd30
`define OPNUM_SLTIU   6'd31
`define OPNUM_XORI    6'd32
`define OPNUM_ORI     6'd33
`define OPNUM_ANDI    6'd34
`define OPNUM_SLLI    6'd35
`define OPNUM_SRLI    6'd36
`define OPNUM_SRAI    6'd37

// range
`define OPCODE_RANGE 6:0
`define FUNC3_RANGE 14:12
`define FUNC7_RANGE 31:25
`define RD_RANGE 11:7
`define RS1_RANGE 19:15
`define RS2_RANGE 24:20

// OPCODE
`define OPCODE_LUI 7'b0110111
`define OPCODE_AUIPC 7'b0010111
`define OPCODE_JAL 7'b1101111
`define OPCODE_JALR 7'b1100111
`define OPCODE_BR 7'b1100011
`define OPCODE_L 7'b0000011
`define OPCODE_S 7'b0100011
`define OPCODE_ARITHI 7'b0010011
`define OPCODE_ARITH 7'b0110011

// func3
`define FUNC3_JALR 3'b000

`define FUNC3_BEQ  3'b000
`define FUNC3_BNE  3'b001
`define FUNC3_BLT  3'b100
`define FUNC3_BGE  3'b101
`define FUNC3_BLTU 3'b110
`define FUNC3_BGEU 3'b111

`define FUNC3_LB 3'b000
`define FUNC3_LH 3'b001
`define FUNC3_LW 3'b010
`define FUNC3_LBU 3'b100
`define FUNC3_LHU 3'b101

`define FUNC3_SB 3'b000
`define FUNC3_SH 3'b001
`define FUNC3_SW 3'b010

`define FUNC3_ADDI  3'b000
`define FUNC3_SLTI  3'b010
`define FUNC3_SLTIU 3'b011
`define FUNC3_XORI  3'b100
`define FUNC3_ORI   3'b110
`define FUNC3_ANDI  3'b111
`define FUNC3_SLLI  3'b001
`define FUNC3_SRLI  3'b101
`define FUNC3_SRAI  3'b101

`define FUNC3_ADD 3'b000
`define FUNC3_SUB 3'b000
`define FUNC3_SLL 3'b001
`define FUNC3_SLT 3'b010
`define FUNC3_SLTU 3'b011
`define FUNC3_XOR 3'b100
`define FUNC3_SRL 3'b101
`define FUNC3_SRA 3'b101
`define FUNC3_OR 3'b110
`define FUNC3_AND 3'b111

// func7 
`define FUNC7_NORM 7'b0000000
`define FUNC7_SPEC 7'b0100000