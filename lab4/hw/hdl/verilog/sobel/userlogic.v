/*
 * File         : userlogic.v
 * Project      : EE180 Sobel accelerator lab
 * Creator(s)   : Samuel Grossman
 *
 * Standards/Formatting:
 *   4 soft tab, wide column.
 *
 * Description:
 *  Wraps the Sobel accelerator controller in an interface that
 *  complies with Stream Engine.
 */

`include "common_defines.v"

module userlogic
#(
    parameter   BUF_SIZE                        = 4096,
    parameter   ADDR_WIDTH                      = 12,
    parameter   AXIS_DWIDTH                     = 32
)
(
    // Clock and reset ports
    input                                       clk,
    input                                       rst_n,

    // Interface to instruction memory (MIPS only, not used here)
    input   [31:0]                              instr,
    output  [31:0]                              instr_addr,

    // Interface to data input buffer
    input   [(16*`NUM_16BIT_MEM_IN)-1:0]        read_data,
    output  [(32*`NUM_16BIT_MEM_IN)-1:0]        read_addr,

    // Interface to data output buffer
    output  [(16*`NUM_16BIT_MEM_OUT)-1:0]       write_data,
    output  [(32*`NUM_16BIT_MEM_OUT)-1:0]       write_addr,
    output  [(2*`NUM_16BIT_MEM_OUT)-1:0]        write_en,

    // External shared registers
    input   [31:0]                              command,
    output  [31:0]                              status,
    output  [31:0]                              test
);

// Internal signals
wire                                            sobel_reset;
wire                                            sobel_go;
wire        [9:0]                               sobel_image_n_rows;
wire        [9:0]                               sobel_image_n_cols;

// Internal concurrent assignments
assign      sobel_reset                         = (~rst_n) | command[1];
assign      sobel_image_n_rows                  = command[11:2] + 10'h2;
assign      sobel_image_n_cols                  = command[21:12] + 10'h2;

// Registers
dffr #(1)                               go_r (
    .clk                                        (clk),
    .r                                          (sobel_reset),
    .d                                          (command[0]),
    .q                                          (sobel_go)
);

// Sobel hardware instance
sobel_top #(32, 10, 32)                 sobel (
    .clk                                        (clk),
    .reset                                      (sobel_reset),
    .go                                         (sobel_go),
    .mem2stop_read_data                         (read_data),
    .stop2mem_read_addr                         (read_addr),
    .stop2mem_write_data                        (write_data),
    .stop2mem_write_addr                        (write_addr),
    .stop2mem_write_en                          (write_en),
    .pipe2stop_image_n_rows                     (sobel_image_n_rows),
    .pipe2stop_image_n_cols                     (sobel_image_n_cols),
    .stop2pipe_status                           (status)
);

// Output generation
assign      instr_addr                          = 32'h0;
assign      test                                = 32'h0;

endmodule
