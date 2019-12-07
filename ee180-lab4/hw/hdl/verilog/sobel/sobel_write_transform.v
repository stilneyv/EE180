/*
 * File         : sobel_write_transform.v
 * Project      : EE180 Sobel accelerator lab
 * Creator(s)   : Samuel Grossman
 *
 * Standards/Formatting:
 *   4 soft tab, wide column.
 *
 * Description:
 *  Enables support for unaligned writes of the correct Endian-ness. Accepts
 *  write addresses and data provided by the Sobel accelerator, generates
 *  memory write addresses for each of the individual memory blocks, and
 *  transforms write data to the correct byte order.
 */

`include "common_defines.v"

module sobel_write_transform
#(
    parameter   ADDR_WIDTH                      = 32
)
(
    // Memory write ports
    output  [(16*`NUM_16BIT_MEM_OUT)-1:0]        swt2mem_write_data,
    output  [(ADDR_WIDTH*`NUM_16BIT_MEM_OUT)-1:0] swt2mem_write_addr,
    output  [(2*`NUM_16BIT_MEM_OUT)-1:0]         swt2mem_write_en,
    
    // Untransformed write input ports
    input   [ADDR_WIDTH-1:0]                    sctl2swt_write_addr,
    input   [`SOBEL_ODATA_WIDTH-1:0]            sacc2swt_write_data,
    input   [`NUM_SOBEL_ACCELERATORS-1:0]       sctl2swt_write_en
);

// Derived constant values
`define NUM_WRITE_TRANSFORM_BITS                ((`NUM_16BIT_MEM_OUT == 2) ? 1 : \
                                                 (`NUM_16BIT_MEM_OUT == 4) ? 2 : \
                                                 (`NUM_16BIT_MEM_OUT == 8) ? 3 : \
                                                 -1)

`define NUM_WRITE_ADDR_TRUNCATE_BITS            (`CLOG2(`NUM_16BIT_MEM_OUT+1))

// Internal signals
wire        [`NUM_WRITE_TRANSFORM_BITS-1:0]     write_transform;                // specifies how to transform the write data due to address alignment
wire        [(16*`NUM_16BIT_MEM_OUT)-1:0]       transformed_write_data;
wire        [15:0]                              unpacked_write_data[`NUM_16BIT_MEM_OUT-1:0];
wire        [`NUM_WRITE_TRANSFORM_BITS:0]       write_check[`NUM_16BIT_MEM_OUT-1:0];
wire        [`NUM_WRITE_TRANSFORM_BITS:0]       write_sub_check_transform[`NUM_16BIT_MEM_OUT-1:0];
wire                                            write_check_compare[`NUM_16BIT_MEM_OUT-1:0];
wire        [`NUM_WRITE_TRANSFORM_BITS:0]       write_en_base_index[`NUM_16BIT_MEM_OUT-1:0];
wire                                            write_addr_plusone[`NUM_16BIT_MEM_OUT-1:0];
wire        [`NUM_WRITE_TRANSFORM_BITS-1:0]     write_data_index[`NUM_16BIT_MEM_OUT-1:0];
genvar                                          i;

// Internal concurrent assignments
assign      write_transform                     = sctl2swt_write_addr[`NUM_WRITE_TRANSFORM_BITS:1];

generate
for (i = 0; i < `NUM_16BIT_MEM_OUT; i = i + 1) begin: unpack_write_data

assign      unpacked_write_data[i]              = (i < (`SOBEL_ODATA_WIDTH/16)) ? sacc2swt_write_data[((i+1)*16)-1:(i*16)] : 'h0;
                                                                                // unpacks supplied output write data into 16-bit blocks
end
endgenerate

generate
for (i = 0; i < `NUM_16BIT_MEM_OUT; i = i + 1) begin: write_transform_internal

assign      write_check[i]                   = (`NUM_SOBEL_ACCELERATORS/2);

`ifdef SOBEL_WRITE_LITTLE_ENDIAN                                                // in little Endian mode, count normally and do a direct un-flipped assignment
assign      transformed_write_data[((i+1)*16)-1:(i*16)] = unpacked_write_data[write_data_index[i]];
assign      write_sub_check_transform[i]     = i - {1'b0, write_transform};
`else                                                                           // in big Endian mode, count backwards and flip the byte order within 16-bit blocks
assign      transformed_write_data[((i+1)*16)-1:(i*16)] = {unpacked_write_data[write_data_index[i]][7:0], unpacked_write_data[write_data_index[i]][15:8]};
assign      write_sub_check_transform[i]     = (`NUM_16BIT_MEM_OUT-i-1) - {1'b0, write_transform};
`endif

assign      write_check_compare[i]           = ({1'b0, write_sub_check_transform[i][`NUM_WRITE_TRANSFORM_BITS-1:0]} < write_check[i]);
assign      write_data_index[i]              = write_check_compare[i] ? write_sub_check_transform[i][`NUM_WRITE_TRANSFORM_BITS:0] : 'h0;
assign      write_en_base_index[i]           = write_check_compare[i] ? {write_data_index[i], 1'b0} : 'h0;
assign      write_addr_plusone[i]            = write_sub_check_transform[i][`NUM_WRITE_TRANSFORM_BITS];

end
endgenerate

// Output generation
assign      swt2mem_write_data                  = transformed_write_data;

generate
for (i = 0; i < `NUM_16BIT_MEM_OUT; i = i + 1) begin: write_transform_address_output

assign      swt2mem_write_addr[((i+1)*ADDR_WIDTH)-1:(i*ADDR_WIDTH)] = {{`NUM_WRITE_ADDR_TRUNCATE_BITS{1'b0}}, sctl2swt_write_addr[ADDR_WIDTH-1:`NUM_WRITE_ADDR_TRUNCATE_BITS]} + {{ADDR_WIDTH-1{1'b0}}, write_addr_plusone[i]};

end
endgenerate

generate
for (i = 0; i < (2*`NUM_16BIT_MEM_OUT); i = i + 1) begin: write_transform_en_output

assign      swt2mem_write_en[i]                 = write_check_compare[i/2] & sctl2swt_write_en[write_en_base_index[i/2] + (i%2)];

end
endgenerate

endmodule
