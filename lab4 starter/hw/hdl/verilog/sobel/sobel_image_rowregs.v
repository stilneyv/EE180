/*
 * File         : sobel_image_rowregs.v
 * Project      : EE180 Sobel accelerator lab
 * Creator(s)   : Samuel Grossman
 *
 * Standards/Formatting:
 *   4 soft tab, wide column.
 *
 * Description:
 *  Holds and shifts in Sobel image data for processing by the
 *  accelerator cores.
 */

`include "common_defines.v"

module sobel_image_rowregs
(
    // Clock and reset ports
    input                                       clk,
    input                                       reset,
    
    // System-wide control signals
    input                                       go,
    
    // Interface: Sobel Control -> Sobel Image Row Registers
    input   [`SOBEL_ROW_OP_WIDTH-1:0]           sctl2srow_row_op,                   // command, specifies what to do with the incoming data, if anything
    
    // Interface: Memory (input buffer) -> Sobel Image Row Registers
    input   [`SOBEL_IDATA_WIDTH-1:0]            srt2srow_read_data,                 // memory read data, contains a new block of pixels
    
    // Interface: Sobel Image Row Registers -> Sobel Accelerator Core
    output  [`SOBEL_IDATA_WIDTH-1:0]            srow2sacc_row1_data,                // row 1 output data
    output  [`SOBEL_IDATA_WIDTH-1:0]            srow2sacc_row2_data,                // row 2 output data
    output  [`SOBEL_IDATA_WIDTH-1:0]            srow2sacc_row3_data                 // row 3 output data
);

// Internal signals
wire    [`SOBEL_IDATA_WIDTH-1:0]                row1, row2, row3;                   // current row data, driven by the row registers
reg     [`SOBEL_IDATA_WIDTH-1:0]                row1_next, row2_next, row3_next;    // next values for the row data, drives the row registers

// Output generation
assign      srow2sacc_row1_data                 = row1;
assign      srow2sacc_row2_data                 = row2;
assign      srow2sacc_row3_data                 = row3;

// Registers
dffre #(`SOBEL_IDATA_WIDTH)             row1_r (
    .clk                                        (clk),
    .en                                         (go),
    .d                                          (row1_next),
    .q                                          (row1),
    .r                                          (reset)
);

dffre #(`SOBEL_IDATA_WIDTH)             row2_r (
    .clk                                        (clk),
    .en                                         (go),
    .d                                          (row2_next),
    .q                                          (row2),
    .r                                          (reset)
);

dffre #(`SOBEL_IDATA_WIDTH)             row3_r (
    .clk                                        (clk),
    .en                                         (go),
    .d                                          (row3_next),
    .q                                          (row3),
    .r                                          (reset)
);

// Control signal processing and register operations
always @ (*) begin
    case (sctl2srow_row_op)
        `SOBEL_ROW_OP_HOLD: begin
            row1_next                           = row1;
            row2_next                           = row2;
            row3_next                           = row3;
        end
        
        `SOBEL_ROW_OP_SHIFT_ROW: begin
            row1_next                           = row2;
            row2_next                           = row3;
            row3_next                           = srt2srow_read_data;
        end
        
        default: begin
            row1_next                           = 'h0;
            row2_next                           = 'h0;
            row3_next                           = 'h0;
        end
    endcase
end

endmodule
