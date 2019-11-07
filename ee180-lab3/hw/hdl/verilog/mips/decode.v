//=============================================================================
// EE108B Lab 2
//
// Decode module. Determines what to do with an instruction.
//=============================================================================

`include "mips_defines.v"

module decode (
    input [31:0] pc,
    input [31:0] instr,
    input [31:0] rs_data_in,
    input [31:0] rt_data_in,

    output wire [4:0] reg_write_addr,
    output wire [31:0] b_addr,
    output wire jump_branch,
    output wire jump_target,
    output wire jump_reg,
    output wire [31:0] jr_pc,
    output reg [3:0] alu_opcode,
    output wire [31:0] alu_op_x,
    output wire [31:0] alu_op_y,
    output wire mem_we,
    output wire [31:0] mem_write_data,
    output wire mem_read,
    output wire mem_byte,
    output wire mem_signextend,
    output wire reg_we,
    output wire movn,
    output wire movz,
    output wire [4:0] rs_addr,
    output wire [4:0] rt_addr,
    output wire atomic_id,
    input  atomic_ex,
    output wire mem_sc_mask_id,
    output wire mem_sc_id,

    output wire stall,

    input reg_we_ex,
    input [4:0] reg_write_addr_ex,
    input [31:0] alu_result_ex,
    input mem_read_ex,

    input reg_we_mem,
    input [4:0] reg_write_addr_mem,
    input [31:0] reg_write_data_mem
);

//******************************************************************************
// instruction field
//******************************************************************************

    wire [5:0] op = instr[31:26];
    assign rs_addr = instr[25:21];
    assign rt_addr = instr[20:16];
    wire [4:0] rd_addr = instr[15:11];
    wire [4:0] shamt = instr[10:6];
    wire [5:0] funct = instr[5:0];
    wire [15:0] immediate = instr[15:0];

    wire [31:0] rs_data, rt_data;
    wire [31:0] rs_data_ex, rt_data_ex;     // used later

//******************************************************************************
// branch instructions decode
//******************************************************************************

    wire isBEQ    = (op == `BEQ);
    wire isBGEZNL = (op == `BLTZ_GEZ) & (rt_addr == `BGEZ);
    wire isBGEZAL = (op == `BLTZ_GEZ) & (rt_addr == `BGEZAL);
    wire isBGEZ = (op == `BLTZ_GEZ) & ((rt_addr == `BGEZ) | (rt_addr == `BGEZAL));
    wire isBGTZ   = (op == `BGTZ) & (rt_addr == 5'b00000);
    wire isBLEZ   = (op == `BLEZ) & (rt_addr == 5'b00000);
    wire isBLTZNL = (op == `BLTZ_GEZ) & (rt_addr == `BLTZ);
    wire isBLTZAL = (op == `BLTZ_GEZ) & (rt_addr == `BLTZAL);
    wire isBLTZ = (op == `BLTZ_GEZ) & ((rt_addr == `BLTZ) | (rt_addr == `BLTZAL));
    wire isBNE    = (op == `BNE);
    wire isBranchLink = (isBGEZ & (rt_addr == `BGEZAL)) | (isBLTZ & (rt_addr == `BLTZAL));


//******************************************************************************
// jump instructions decode
//******************************************************************************

    wire isJ    = (op == `J);
    wire isJAL  = (op == `JAL);
    wire isJALR = (op == `SPECIAL) & (funct == `JALR);  
    wire isJR   = (op == `SPECIAL) & (funct == `JR);
    
    // determine if the next pc will need to be stored
    wire isLink = isJALR | isJAL | isBranchLink;

//******************************************************************************
// shift instruction decode
//******************************************************************************

    wire isSLL = (op == `SPECIAL) & (funct == `SLL);
    wire isSRA = (op == `SPECIAL) & (funct == `SRA);
    wire isSRL = (op == `SPECIAL) & (funct == `SRL);
    wire isSLLV = (op == `SPECIAL) & (funct == `SLLV);
    wire isSRAV = (op == `SPECIAL) & (funct == `SRAV);
    wire isSRLV = (op == `SPECIAL) & (funct == `SRLV);
    
    wire isShiftImm = isSLL | isSRA | isSRL;
    wire isShift = isShiftImm | isSLLV | isSRAV | isSRLV;

//******************************************************************************
// ALU instructions decode / control signal for ALU datapath
//******************************************************************************

    always @* begin
        casex({op, funct})
            {`ADDI, `DC6}:      alu_opcode = `ALU_ADD;
            {`ADDIU, `DC6}:     alu_opcode = `ALU_ADDU;
            {`ANDI, `DC6}:      alu_opcode = `ALU_AND;
            {`SLTI, `DC6}:      alu_opcode = `ALU_SLT;
            {`SLTIU, `DC6}:     alu_opcode = `ALU_SLTU;
            {`ORI, `DC6}:       alu_opcode = `ALU_OR;
            {`XORI, `DC6}:		alu_opcode = `ALU_XOR;
			{`LB, `DC6}:        alu_opcode = `ALU_ADD;
            {`LL, `DC6}:        alu_opcode = `ALU_ADD;
            {`LW, `DC6}:        alu_opcode = `ALU_ADD;
            {`LBU, `DC6}:       alu_opcode = `ALU_ADD;
            {`SB, `DC6}:        alu_opcode = `ALU_ADD;
            {`SC, `DC6}:        alu_opcode = `ALU_ADD;
            {`SW, `DC6}:        alu_opcode = `ALU_ADD;
            {`BEQ, `DC6}:       alu_opcode = `ALU_SUBU;
            {`BNE, `DC6}:       alu_opcode = `ALU_SUBU;
            {`SPECIAL, `ADD}:   alu_opcode = `ALU_ADD;
            {`SPECIAL, `ADDU}:  alu_opcode = `ALU_ADDU;
            {`SPECIAL, `SUB}:   alu_opcode = `ALU_SUB;
            {`SPECIAL, `SUBU}:  alu_opcode = `ALU_SUBU;
            {`SPECIAL, `AND}:   alu_opcode = `ALU_AND;
			{`SPECIAL, `XOR}:	alu_opcode = `ALU_XOR;
			{`SPECIAL, `OR}:    alu_opcode = `ALU_OR;
            {`SPECIAL, `NOR}:   alu_opcode = `ALU_NOR;
			{`SPECIAL, `MOVN}:  alu_opcode = `ALU_PASSX;
            {`SPECIAL, `MOVZ}:  alu_opcode = `ALU_PASSX;
            {`SPECIAL2, `MUL}:   alu_opcode = `ALU_MUL;         // SPECIAL2 bc that's what coincide with signals and mips_defines
            {`SPECIAL, `SLT}:   alu_opcode = `ALU_SLT;
            {`SPECIAL, `SLTU}:  alu_opcode = `ALU_SLTU;
            {`SPECIAL, `SLL}:   alu_opcode = `ALU_SLL;
            {`SPECIAL, `SRL}:   alu_opcode = `ALU_SRL;
            {`SPECIAL, `SLLV}:  alu_opcode = `ALU_SLL;
            {`SPECIAL, `SRLV}:  alu_opcode = `ALU_SRL;
			{`SPECIAL, `SRAV}:  alu_opcode = `ALU_SRA;
			{`SPECIAL, `SRA}:   alu_opcode = `ALU_SRA;
			// compare rs data to 0, only care about 1 operand
            {`BGTZ, `DC6}:      alu_opcode = `ALU_PASSX;
            {`BLEZ, `DC6}:      alu_opcode = `ALU_PASSX;
            {`BLTZ_GEZ, `DC6}: begin
                if (isBranchLink)
                    alu_opcode = `ALU_PASSY; // pass link address for mem stage
                else
                    alu_opcode = `ALU_PASSX;
            end
            // pass link address to be stored in $ra
            {`JAL, `DC6}:       alu_opcode = `ALU_PASSY;
            {`SPECIAL, `JALR}:  alu_opcode = `ALU_PASSY;
            // or immediate with 0
            {`LUI, `DC6}:       alu_opcode = `ALU_PASSY;
            default:            alu_opcode = `ALU_PASSX;
    	endcase
    end

//******************************************************************************
// Compute value for 32 bit immediate data
//******************************************************************************

    wire use_imm = &{op != `SPECIAL, op != `SPECIAL2, op != `BNE, op != `BEQ}; // where to get 2nd ALU operand from: 0 for RtData, 1 for Immediate

    reg [31:0] imm;

    wire [31:0] imm_sign_extend = {{16{immediate[15]}}, immediate};
    wire [31:0] imm_upper = {immediate, 16'b0};
	wire [31:0] imm_zero_extend = {16'b0, immediate};

	always @(*) begin
		if (op == `LUI)
			imm = imm_upper;
		else if (|{op == `ORI, op == `ANDI, op == `XORI})
			imm = imm_zero_extend;
		else 
			imm = imm_sign_extend;
	end

//******************************************************************************
// forwarding and stalling logic
//******************************************************************************

    // if writing to rs and rs is not zero, forward from X stage
    wire forward_rs_ex = &{rs_addr == reg_write_addr_ex, rs_addr != `ZERO, reg_we_ex};
    // if writing to rt and rt is not zero, forward from X stage
    wire forward_rt_ex = &{rt_addr == reg_write_addr_ex, rt_addr != `ZERO, reg_we_ex}; 

    // if writing to rs and rs is not zero, forward from mem stage if not already doing it from X
    wire forward_rs_mem = &{rs_addr == reg_write_addr_mem, rs_addr != `ZERO, reg_we_mem, !forward_rs_ex};   // implementing fwd_idrs_ex
    // if writing to rt and rt is not zero, forward from mem stage if not already doing it from X
    wire forward_rt_mem = &{rt_addr == reg_write_addr_mem, rt_addr != `ZERO, reg_we_mem, !forward_rt_ex};   //implementing fwd_idrt_ex 

    // decide what data to forward, if comes from ALU or data in
    assign rs_data_ex = forward_rs_ex ? alu_result_ex : rs_data_in;
    assign rt_data_ex = forward_rt_ex ? alu_result_ex : rt_data_in;
    
    // if forwarding from mem, use reg_write_data_mem, otherwise use data previously determined
    assign rs_data = forward_rs_mem ? reg_write_data_mem : rs_data_ex;
    assign rt_data = forward_rt_mem ? reg_write_data_mem : rt_data_ex; //edit to implement fwd_idrt_mem

    // determines dependencies
    wire rs_mem_dependency = &{rs_addr == reg_write_addr_ex, mem_read_ex, rs_addr != `ZERO};
    wire rt_mem_dependency = &{rt_addr == reg_write_addr_ex, mem_read_ex, rt_addr != `ZERO};

    wire isLUI = op == `LUI;
    wire isALUImm = |{op == `ADDI, op == `ADDIU, op == `SLTI, op == `SLTIU, op == `ANDI, op == `ORI};

    // is it coming from rs or rt?
    wire from_rs = ~|{isLUI, jump_target, isShiftImm};
    wire from_rt = ~|{isALUImm, mem_read, isLUI, jump_target};

    // decide how to stall
    assign stall = (rs_mem_dependency & from_rs) | (rt_mem_dependency & from_rt) ;

    assign jr_pc = rs_data;
    assign mem_write_data = rt_data;

//******************************************************************************
// Determine ALU inputs and register writeback address
//******************************************************************************

    // for shift operations, use either shamt field or lower 5 bits of rs
    // otherwise use rs

    wire [31:0] shift_amount = isShiftImm ? shamt : rs_data[4:0];
    // either the first operand is the shift amount or the data is rs
    assign alu_op_x = isShift ? shift_amount : rs_data;

    // second operand for ALU is pc + 8 for jump and link instructions or if not, the imm or rt
    assign alu_op_y = (isJAL | isJALR) ? (pc + 4'h8) : (use_imm) ? imm : rt_data; 
    // decides where to write for reg_write operations, aka using RA, rt, or rd
    assign reg_write_addr = (op == `SC) ? rt_addr : (isJAL | isJALR) ? `RA : (use_imm) ? rt_addr : rd_addr; 

    // determine when to write back to a register (any operation that isn't an
    // unconditional store, non-linking branch, or non-linking jump)
    assign reg_we = ~|{(mem_we & (op != `SC)), isJ, isJR, isBGEZNL, isBGTZ, isBLEZ, isBLTZNL, isBNE, isBEQ};

    // determine whether a register write is conditional
    assign movn = &{op == `SPECIAL, funct == `MOVN};
    assign movz = &{op == `SPECIAL, funct == `MOVZ};

//******************************************************************************
// Memory control
//******************************************************************************
    assign mem_we = |{op == `SW, op == `SB, op == `SC};                  // write to memory
    assign mem_read = |{op == `LW, op == `LB, op == `LBU, op == `LL};    // use memory data for writing to a register
    assign mem_byte = |{op == `SB, op == `LB, op == `LBU};               // memory operations use only one byte
    assign mem_signextend = ~|{op == `LBU};                   // sign extend sub-word memory reads

//******************************************************************************
// Load linked / Store conditional
//******************************************************************************
    assign mem_sc_id = (op == `SC);

     // 'mem_sc_mask_id' is high when a store conditional should not store
    assign mem_sc_mask_id = ~atomic_ex & mem_sc_id; // don't store if not atomic

    // 'atomic_id' is high when a load-linked has not been followed by a store
    assign atomic_id = (op == `LL) ? 1'b1 : mem_we ? 1'b0 : atomic_ex;

//******************************************************************************
// Branch resolution
//******************************************************************************

    wire isEqual = rs_data == rt_data;
    wire isZero = ~|rs_data;
    wire isNeg = rs_data[31];
    wire isPos = ~(isZero | isNeg);

    assign jump_branch = |{isBEQ & isEqual,
                           isBNE & ~isEqual,
                           isBGEZ & ~isNeg,
                           isBGTZ & isPos,
                           isBLEZ & ~isPos,
                           isBLTZ & isNeg};
    
    assign jump_target = isJ | isJAL;
    assign jump_reg = isJALR | isJR;                            // jumping w register val

    // determine next branch address pc + 4 + imm * 4
    assign b_addr = pc + 3'h4 + (imm_sign_extend << 2);         // immediate is in words, not bytes, so x4 

endmodule
