/*
 * File         : sobel_top.v
 * Project      : EE180 Sobel accelerator lab
 * Creator(s)   : Samuel Grossman
 *
 * Standards/Formatting:
 *   4 soft tab, wide column.
 *
 * Description:
 *  Top-level module for the Sobel accelerator.
 */

`include "common_defines.v"

module sobel_top
#(
    parameter   IOBUF_ADDR_WIDTH                = 32,                               // input and output buffer address width
    parameter   IMAGE_DIM_WIDTH                 = 10,                               // image size control register width
    parameter   STATUS_REG_WIDTH                = 32                                // status register width
)
(
    // Clock and reset ports
    input                                       clk,
    input                                       reset,
    
    // System-wide control signals
    input                                       go,
    
    // Interface to data input buffer
    input   [(16*`NUM_16BIT_MEM_IN)-1:0]        mem2stop_read_data,
    output  [(32*`NUM_16BIT_MEM_IN)-1:0]        stop2mem_read_addr,

    // Interface to data output buffer
    output  [(16*`NUM_16BIT_MEM_OUT)-1:0]       stop2mem_write_data,
    output  [(32*`NUM_16BIT_MEM_OUT)-1:0]       stop2mem_write_addr,
    output  [(2*`NUM_16BIT_MEM_OUT)-1:0]        stop2mem_write_en,
    
    // External command register signals
    input   [IMAGE_DIM_WIDTH-1:0]               pipe2stop_image_n_rows,
    input   [IMAGE_DIM_WIDTH-1:0]               pipe2stop_image_n_cols,
    
    // External status register signals
    output  [STATUS_REG_WIDTH-1:0]              stop2pipe_status
);

// Interface: Sobel Control -> Memory (input and output buffers)
wire        [31:0]                              sctl2srt_read_addr;             // input buffer read address
wire        [31:0]                              sctl2swt_write_addr;            // output buffer write address
wire        [`NUM_SOBEL_ACCELERATORS-1:0]       sctl2swt_write_en;              // output buffer write enable, per output pixel

// Interface: Sobel Control -> Sobel Image Row Registers
wire        [`SOBEL_ROW_OP_WIDTH-1:0]           sctl2srow_row_op;               // command, specifies what to do with the incoming data, if anything

// Interface: Memory (input buffer) -> Sobel Image Row Registers
wire        [`SOBEL_IDATA_WIDTH-1:0]            srt2srow_read_data;             // memory read data, contains a new block of pixels

// Interface: Sobel Image Row Registers -> Sobel Accelerator Core
wire        [`SOBEL_IDATA_WIDTH-1:0]            srow2sacc_row1_data;            // row 1 output data
wire        [`SOBEL_IDATA_WIDTH-1:0]            srow2sacc_row2_data;            // row 2 output data
wire        [`SOBEL_IDATA_WIDTH-1:0]            srow2sacc_row3_data;            // row 3 output data

// Interface: Sobel Accelerator Core -> Memory (output buffer)
wire        [`SOBEL_ODATA_WIDTH-1:0]            sacc2swt_write_data;            // result of Sobel convolution calculation

// Hardware instance: read transform, for handling 2-byte aligned reads
sobel_read_transform #(IOBUF_ADDR_WIDTH) read_transform(
    .clk                                        (clk),
    .reset                                      (reset),
    .sctl2srt_read_addr                         (sctl2srt_read_addr),
    .srt2mem_read_addr                          (stop2mem_read_addr),
    .mem2srt_read_data                          (mem2stop_read_data),
    .srt2srow_read_data                         (srt2srow_read_data)
);

// Hardware instance: write transform, for handling 2-byte aligned writes with byte-enable
sobel_write_transform #(IOBUF_ADDR_WIDTH) write_transform(
    .swt2mem_write_data                         (stop2mem_write_data),
    .swt2mem_write_addr                         (stop2mem_write_addr),
    .swt2mem_write_en                           (stop2mem_write_en),
    .sctl2swt_write_addr                        (sctl2swt_write_addr),
    .sacc2swt_write_data                        (sacc2swt_write_data),
    .sctl2swt_write_en                          (sctl2swt_write_en)
);

// Hardware instance: control, for controlling the progress of the entire Sobel accelerator system
sobel_control #(IOBUF_ADDR_WIDTH, IMAGE_DIM_WIDTH, STATUS_REG_WIDTH) control(
    .clk                                        (clk),
    .reset                                      (reset),
    .go                                         (go),
    .sctl2srt_read_addr                         (sctl2srt_read_addr),
    .sctl2swt_write_addr                        (sctl2swt_write_addr),
    .sctl2swt_write_en                          (sctl2swt_write_en),
    .sctl2srow_row_op                           (sctl2srow_row_op),
    .stop2sctl_image_n_rows                     (pipe2stop_image_n_rows),
    .stop2sctl_image_n_cols                     (pipe2stop_image_n_cols),
    .sctl2stop_status                           (stop2pipe_status)
);

// Hardware instance: row registers, for holding the row data currently being processed by the accelerator cores
sobel_image_rowregs                     row_reg (
    .clk                                        (clk),
    .reset                                      (reset),
    .go                                         (go),
    .sctl2srow_row_op                           (sctl2srow_row_op),
    .srt2srow_read_data                         (srt2srow_read_data),
    .srow2sacc_row1_data                        (srow2sacc_row1_data),
    .srow2sacc_row2_data                        (srow2sacc_row2_data),
    .srow2sacc_row3_data                        (srow2sacc_row3_data)
);

// Hardware instance: accelerator cores, for executing the Sobel convolutions
sobel_accelerator                       accelerator (
    .srow2sacc_row1_data                        (srow2sacc_row1_data),
    .srow2sacc_row2_data                        (srow2sacc_row2_data),
    .srow2sacc_row3_data                        (srow2sacc_row3_data),
    .sacc2swt_write_data                        (sacc2swt_write_data)
);

endmodule
