//=============================================================================
// EE108B Lab 2
//
// Instruction fetch module. Maintains PC and updates it. Reads from the
// instruction ROM.
//=============================================================================

module instruction_fetch (
    input clk,
    input rst,
    input en,
    input jump_target,
    input [31:0] pc_id,
    input [25:0] instr_id,  // Lower 26 bits of the instruction
    input [31:0] b_addr,
    input jump_branch,
    input jump_reg,
    input [31:0] jr_pc,

    output [31:0] pc
    // output [31:0] instr
);

    // normal pc + 4
    wire [31:0] pc_id_p4 = pc_id + 3'h4;
    // determines theoretical branch addr, either use val in decode or just pc + 4
    wire [31:0] b_tar = (jump_branch) ? b_addr : (pc + 3'h4); 
    // determines theoretical jump addr using the instr vals
    wire [31:0] j_addr = {pc_id_p4[31:28], instr_id, 2'b0};

    reg [31:0] pc_next;

    always @* begin
        if (jump_branch)
            pc_next = b_tar;
        else if (jump_target)
            pc_next = j_addr;
        else if (jump_reg)          // for jump reg stuff, jr_pc calc in decode
            pc_next = jr_pc;
        else
            pc_next = pc + 3'h4;
    end


    dffare #(32) pc_reg (.clk(clk), .r(rst), .en(en), .d(pc_next), .q(pc));

endmodule
