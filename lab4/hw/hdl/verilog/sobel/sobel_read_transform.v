/*
 * File         : sobel_read_transform.v
 * Project      : EE180 Sobel accelerator lab
 * Creator(s)   : Samuel Grossman
 *
 * Standards/Formatting:
 *   4 soft tab, wide column.
 *
 * Description:
 *  Enables support for unaligned reads of the correct Endian-ness. Accepts
 *  read addresses provided by the Sobel accelerator, generates memory read
 *  addresses for each of the individual memory blocks, and transforms read
 *  data received from memory to the correct byte order.
 */

`include "common_defines.v"

module sobel_read_transform
#(
    parameter   ADDR_WIDTH                      = 32
)
(
    // Clock and reset ports
    input                                       clk,
    input                                       reset,
    
    // Memory address ports
    input   [ADDR_WIDTH-1:0]                    sctl2srt_read_addr,
    output  [(ADDR_WIDTH*`NUM_16BIT_MEM_IN)-1:0] srt2mem_read_addr,
    
    // Memory read data ports
    input   [(16*`NUM_16BIT_MEM_IN)-1:0]        mem2srt_read_data,
    output  [`SOBEL_IDATA_WIDTH-1:0]            srt2srow_read_data
);

// Derived constant values
`define NUM_READ_TRANSFORM_BITS                 ((`NUM_16BIT_MEM_IN == 2) ? 1 : \
                                                 (`NUM_16BIT_MEM_IN == 4) ? 2 : \
                                                 (`NUM_16BIT_MEM_IN == 8) ? 3 : \
                                                 -1)

// Internal signals
wire        [`NUM_READ_TRANSFORM_BITS-1:0]      read_transform;                 // driven by a register, specifies how to transform the read data due to address alignment
wire        [15:0]                              unpacked_read_data[`NUM_16BIT_MEM_IN-1:0];
wire        [(16*`NUM_16BIT_MEM_IN)-1:0]        transformed_read_data;
wire        [`NUM_READ_TRANSFORM_BITS-1:0]      read_addr_transform_addcheck[`NUM_16BIT_MEM_IN-1:0];
wire        [`NUM_READ_TRANSFORM_BITS-1:0]      read_data_transform_index[`NUM_16BIT_MEM_IN-1:0];
genvar                                          i;

// Internal concurrent assignments
generate
for (i = 0; i < `NUM_16BIT_MEM_IN; i = i + 1) begin: unpack_read_data

assign      unpacked_read_data[i]               = mem2srt_read_data[((i+1)*16)-1:(i*16)];
                                                                                // unpacks supplied memory read data into 16-bit blocks

assign      read_data_transform_index[i]        = i - read_transform;
assign      transformed_read_data[((i+1)*16)-1:(i*16)] = unpacked_read_data[read_data_transform_index[i]];
                                                                                // rearranges read data to correspond to the alignment of the address
end
endgenerate

// Output generation
`ifdef SOBEL_READ_LITTLE_ENDIAN
assign      srt2srow_read_data                  = transformed_read_data[(16*`NUM_16BIT_MEM_IN)-1:(16*`NUM_16BIT_MEM_IN)-`SOBEL_IDATA_WIDTH];
                                                                                // direct assignment, no Endian-ness flip (assumed incoming data is little Endian)
`else
generate
for (i = 0; i < (`SOBEL_IDATA_WIDTH/8); i = i + 1) begin: flip_endian_read_data

assign      srt2srow_read_data[((i+1)*8)-1:(i*8)] = transformed_read_data[(16*`NUM_16BIT_MEM_IN)-(i*8)-1:(16*`NUM_16BIT_MEM_IN)-(i*8)-8];
                                                                                // by default, flip Endian-ness to use big Endian

end
endgenerate
`endif

generate
for (i = 0; i < `NUM_16BIT_MEM_IN; i = i + 1) begin: transform_read_address

assign      read_addr_transform_addcheck[i]     = i + sctl2srt_read_addr[`NUM_READ_TRANSFORM_BITS:1];
assign      srt2mem_read_addr[((i+1)*ADDR_WIDTH)-1:(i*ADDR_WIDTH)] = {{`NUM_READ_TRANSFORM_BITS+1{1'b0}}, sctl2srt_read_addr[ADDR_WIDTH-1:`NUM_READ_TRANSFORM_BITS+1]} + {{ADDR_WIDTH-1{1'b0}}, (read_addr_transform_addcheck[i] < i)};
                                                                                // all read addresses get +1 if the data in that position will be rotated to the end due to unalignment of reads
                                                                                // for position x, the equation is (x + read_address_bits_of_interest < x), taking advantage of overflow addition
                                                                                // note that nothing is ever < 0 in this context, so for x == 0 there is never any +1 to the address
end
endgenerate

// Registers
dffr #(`NUM_READ_TRANSFORM_BITS)        read_transform_r (                      // registers the correct read address bits so that the transform indicator corresponds to when data is available
    .clk                                        (clk),
    .r                                          (reset),
    .d                                          (sctl2srt_read_addr[`NUM_READ_TRANSFORM_BITS:1]),
    .q                                          (read_transform)
);

endmodule
