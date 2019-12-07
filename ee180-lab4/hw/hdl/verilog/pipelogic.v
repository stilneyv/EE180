/*
 * Simple module which takes a string of bytes over an AXI stream, adds a
 * 32-bit value to each group of 4 bytes, and then sends them on an output
 * AXI stream.
 *
 * Ready/valid signals are used for flow control on the AXI stream.  An
 * AXI-Lite bus (via an IPIF wrapper) controls the value that gets added.
 *
 * Pieces of this file are based on the generated AXI interface templates
 * from XPS peripheral generator.
 *
 * Steven Bell <sebell@stanford.edu>
 * 31 January 2013
 */

`uselib lib=unisims_ver
`uselib lib=proc_common_v3_00_a

`include "common_defines.v"

/*
 Registers for sobel design:
  Input stream
   - Buffer ID
   - Starting address
  Output stream
   - Buffer ID
   - Starting address
   - length (in words)
  Compute engine
   - address in input buffer
   - address in output buffer
   - length
   - command register (for start)
   - status register
*/

module pipelogic
#(
    parameter IPIF_NUM_REG = 7,
    parameter IPIF_DWIDTH = 32,
    parameter AXIS_DWIDTH = 32
)
(
    // AXI Stream interface
    input aclk,                                     // clock
    input aresetn,                                  // active low reset

    output wire axis_ready_in,                      // ready to accept data in
    input axis_valid_in,                            // data input is valid
    input [AXIS_DWIDTH-1:0] axis_data_in,           // data input
    input axis_last_in,                             // flag for last transfer in packet

    input axis_ready_out,                           // ready to receive data out
    output wire axis_valid_out,                     // data output is valid
    output wire [AXIS_DWIDTH-1:0] axis_data_out,    // data output
    output wire axis_last_out,                      // flag for last transfer in packet

    // IPIF (AXI Lite wrapper) interface
    input [IPIF_DWIDTH-1:0] ipif_data_in,           // IPIF data input
    input [IPIF_DWIDTH/8-1:0] ipif_be,              // IPIF byte enables
    input [IPIF_NUM_REG-1:0] ipif_read_ce,          // IPIF read chip enable
    input [IPIF_NUM_REG-1:0] ipif_write_ce,         // IPIF write chip enable
    output wire [IPIF_DWIDTH-1:0] ipif_data_out,    // IPIF data output
    output wire ipif_read_ack,                      // IPIF read transfer acknowledgement
    output wire ipif_write_ack,                     // IPIF write transfer acknowledgement
    output wire ipif_error                          // IPIF error response

);

localparam BUF_SIZE = 65536;
localparam ADDR_WIDTH = 16;
localparam NUM_IN_MUX_BITS = `CLOG2((16*`NUM_16BIT_MEM_IN)/AXIS_DWIDTH);
localparam NUM_OUT_MUX_BITS = `CLOG2((16*`NUM_16BIT_MEM_OUT)/AXIS_DWIDTH);

wire [IPIF_DWIDTH-1:0] write_buf_select, command, status, test;
wire [IPIF_DWIDTH-1:0] ul_status, ul_test;
wire [ADDR_WIDTH-1:0] start_addr_in, start_addr_out, write_addr, read_addr;
wire [ADDR_WIDTH:0] packet_size_out;
wire set_packet_size;
wire axis_write_en;

// Delay by one cycle since the packet size is also delayed by one cycle in the
// corresponding ipif register.
reg set_packet_size_d;
always @(posedge aclk)
    set_packet_size_d <= set_packet_size;

axis_addr #(ADDR_WIDTH) axis_addr (
    .aclk(aclk),
    .aresetn(aresetn),
    .ready_in(axis_ready_in),
    .valid_in(axis_valid_in),
    .last_in(axis_last_in),
    .ready_out(axis_ready_out),
    .valid_out(axis_valid_out),
    .last_out(axis_last_out),
    .read_addr(read_addr),
    .write_addr(write_addr),
    .write_en(axis_write_en),
    .start_addr_in(start_addr_in),
    .start_addr_out(start_addr_out),
    .packet_size_out(packet_size_out),
    .set_packet_size(set_packet_size_d)
);

wire [(32*`NUM_16BIT_MEM_IN)-1:0] ul_read_addr;
wire [(16*`NUM_16BIT_MEM_IN)-1:0] ul_read_data;
wire [(32*`NUM_16BIT_MEM_OUT)-1:0] ul_write_addr;
wire [(16*`NUM_16BIT_MEM_OUT)-1:0] ul_write_data;
wire [31:0] instr_addr;
wire [31:0] instr;
wire [(2*`NUM_16BIT_MEM_OUT)-1:0] ul_write_en;

// Instruction Memory
wire instr_mem_we = (axis_write_en & write_buf_select[0]);
wire [13:0] instr_mem_addr = instr_mem_we ? write_addr : instr_addr;
dataram2 #(16384, 14, 32) instr_mem (
    .clk(aclk),
    .addr(instr_mem_addr),
    .we(instr_mem_we),
    .din(axis_data_in),
    .dout(instr)
);

// Input Buffer
wire [ADDR_WIDTH-1:0] input_buffer_addr[`NUM_16BIT_MEM_IN-1:0];
wire [15:0] input_buffer_data[`NUM_16BIT_MEM_IN-1:0];
wire input_buffer_we[`NUM_16BIT_MEM_IN-1:0];

generate
    genvar ibuf_num;
    
    if (AXIS_DWIDTH >= (16*`NUM_16BIT_MEM_IN)) begin
        
        for (ibuf_num = 0; ibuf_num < `NUM_16BIT_MEM_IN; ibuf_num = ibuf_num + 1) begin : input_buffers
            assign input_buffer_addr[ibuf_num] = input_buffer_we[ibuf_num] ? write_addr : ul_read_addr[((ibuf_num+1)*32)-1:(ibuf_num*32)];
            assign input_buffer_data[ibuf_num] = axis_data_in[((ibuf_num+1)*16)-1:(ibuf_num*16)];
            assign input_buffer_we[ibuf_num] =  axis_write_en & write_buf_select[1];
        
            dataram2 #(BUF_SIZE/`NUM_16BIT_MEM_IN, ADDR_WIDTH-`CLOG2(`NUM_16BIT_MEM_IN), AXIS_DWIDTH/2) buf_0 (
                .clk(aclk),
                .addr(input_buffer_addr[ibuf_num]),
                .we(input_buffer_we[ibuf_num]),
                .din(input_buffer_data[ibuf_num]),
                .dout(ul_read_data[((ibuf_num+1)*16)-1:(ibuf_num*16)])
            );
        end
        
    end else begin
        
        for (ibuf_num = 0; ibuf_num < `NUM_16BIT_MEM_IN; ibuf_num = ibuf_num + 1) begin : input_buffers
            assign input_buffer_addr[ibuf_num] = input_buffer_we[ibuf_num] ? {{NUM_IN_MUX_BITS{1'b0}}, write_addr[ADDR_WIDTH-1:NUM_IN_MUX_BITS]} : ul_read_addr[((ibuf_num+1)*32)-1:(ibuf_num*32)];
            assign input_buffer_data[ibuf_num] = axis_data_in[((ibuf_num%(AXIS_DWIDTH/16)+1)*16)-1:((ibuf_num%(AXIS_DWIDTH/16))*16)];
`ifdef SOBEL_READ_LITTLE_ENDIAN
            assign input_buffer_we[ibuf_num] =  axis_write_en & write_buf_select[1] & (write_addr[NUM_IN_MUX_BITS-1:0] == ((ibuf_num)/(AXIS_DWIDTH/16)));
`else
            assign input_buffer_we[ibuf_num] =  axis_write_en & write_buf_select[1] & (write_addr[NUM_IN_MUX_BITS-1:0] == ((`NUM_16BIT_MEM_IN-1-ibuf_num)/(AXIS_DWIDTH/16)));
`endif
            
            dataram2 #(BUF_SIZE/`NUM_16BIT_MEM_IN, ADDR_WIDTH-`CLOG2(`NUM_16BIT_MEM_IN), AXIS_DWIDTH/2) buf_0 (
                .clk(aclk),
                .addr(input_buffer_addr[ibuf_num]),
                .we(input_buffer_we[ibuf_num]),
                .din(input_buffer_data[ibuf_num]),
                .dout(ul_read_data[((ibuf_num+1)*16)-1:(ibuf_num*16)])
            );
        end
        
    end
endgenerate


// Output Buffer
wire [(AXIS_DWIDTH/2)-1:0] intermediate_data_out[`NUM_16BIT_MEM_OUT-1:0];
wire [ADDR_WIDTH-1:0] output_buffer_addr[`NUM_16BIT_MEM_OUT-1:0];

generate
    genvar obuf_num;
    
    for (obuf_num = 0; obuf_num < `NUM_16BIT_MEM_OUT; obuf_num = obuf_num + 1) begin : output_buffers
        
        if (AXIS_DWIDTH >= (16*`NUM_16BIT_MEM_OUT)) begin
            assign output_buffer_addr[obuf_num] = (ul_write_en[((obuf_num+1)*2)-1] | ul_write_en[(obuf_num*2)]) ? ul_write_addr[((obuf_num+1)*32)-1:(obuf_num*32)] : read_addr;
        end else begin
            assign output_buffer_addr[obuf_num] = (ul_write_en[((obuf_num+1)*2)-1] | ul_write_en[(obuf_num*2)]) ? ul_write_addr[((obuf_num+1)*32)-1:(obuf_num*32)] : {{NUM_OUT_MUX_BITS{1'b0}}, read_addr[ADDR_WIDTH-1:NUM_OUT_MUX_BITS]};
        end
            
        dataram3 #(.ADDR_WIDTH(ADDR_WIDTH-`CLOG2(`NUM_16BIT_MEM_OUT)), .COL_WIDTH(8), .N_COLS((AXIS_DWIDTH/2)/8)) buf_1 (
            .clk(aclk),
            .addr(output_buffer_addr[obuf_num]),
            .we(ul_write_en[((obuf_num+1)*2)-1:(obuf_num*2)]),
            .din(ul_write_data[((obuf_num+1)*16)-1:(obuf_num*16)]),
            .dout(intermediate_data_out[obuf_num])
        );
        
    end
endgenerate

generate
    genvar oblock_num;
    
    for (oblock_num = 0; oblock_num < (AXIS_DWIDTH/16); oblock_num = oblock_num + 1) begin : output_blocks
        
        if (AXIS_DWIDTH >= (16*`NUM_16BIT_MEM_OUT)) begin
            assign axis_data_out[((oblock_num+1)*16)-1:(oblock_num*16)] = intermediate_data_out[oblock_num];
        end else begin
            assign axis_data_out[((oblock_num+1)*16)-1:(oblock_num*16)] = intermediate_data_out[oblock_num + {read_addr[NUM_OUT_MUX_BITS-1:0], {(`CLOG2(AXIS_DWIDTH/16)){1'b0}}}];
        end
    end
endgenerate

userlogic #(BUF_SIZE, ADDR_WIDTH, AXIS_DWIDTH) ul (
    .clk(aclk),
    .rst_n(aresetn),
    .instr(instr),
    .instr_addr(instr_addr),
    .read_data(ul_read_data),
    .read_addr(ul_read_addr),
    .write_data(ul_write_data),
    .write_addr(ul_write_addr),
    .write_en(ul_write_en),
    .command(command),
    .status(ul_status),
    .test(ul_test)
);




//-------------------------
// IPIF register read/write
//-------------------------

wire [IPIF_DWIDTH-1:0] slv_regs [IPIF_NUM_REG-1:0];

localparam IPIF_REG_SEL_WIDTH = `CLOG2(IPIF_NUM_REG);

// give the registers meaning
assign status           = slv_regs[0];  // offset 24
assign test             = slv_regs[1];  // offset 20
assign start_addr_in    = slv_regs[2];  // offset 16
assign start_addr_out   = slv_regs[3];  // offset 12
assign packet_size_out  = slv_regs[4];  // offset 8
assign write_buf_select = slv_regs[5];  // offset 4
assign command          = slv_regs[6];  // offset 0

// Note: if adding registers to this design, ensure that ipif ce index for
//       set_packet_size matches the slv_regs index for packet_size_out.
assign set_packet_size = ipif_write_ce[4];

wire [3:0] status_be = 32'hFFFF;
ipif_reg #(IPIF_DWIDTH) status_reg (
    .aclk(aclk),
    .aresetn(aresetn),
    .en(1'b1),
    .be(status_be),
    .d(ul_status),
    .q(slv_regs[0])
);

wire [3:0] test_be = 32'hFFFF;
ipif_reg #(IPIF_DWIDTH) test_reg (
    .aclk(aclk),
    .aresetn(aresetn),
    .en(1'b1),
    .be(test_be),
    .d(ul_test),
    .q(slv_regs[1])
);

generate
    genvar reg_num;
    for (reg_num = 2; reg_num < IPIF_NUM_REG; reg_num = reg_num + 1) begin : ipif_regs
        ipif_reg #(IPIF_DWIDTH) ipif_reg (
            .aclk(aclk),
            .aresetn(aresetn),
            .en(ipif_write_ce[reg_num]),
            .be(ipif_be),
            .d(ipif_data_in),
            .q(slv_regs[reg_num])
        );
    end
endgenerate

wire [IPIF_REG_SEL_WIDTH-1:0] reg_read_sel;
encoder #(IPIF_NUM_REG, IPIF_REG_SEL_WIDTH) reg_read_sel_enc (.onehot(ipif_read_ce), .binary(reg_read_sel));

assign ipif_data_out = slv_regs[reg_read_sel];
assign ipif_read_ack = |ipif_read_ce;
assign ipif_write_ack = |ipif_write_ce;
assign ipif_error = 1'b0;

endmodule
