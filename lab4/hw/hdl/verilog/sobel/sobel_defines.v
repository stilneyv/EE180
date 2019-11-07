/*
 * File         : sobel_defines.v
 * Project      : EE180 Sobel accelerator lab
 * Creator(s)   : Samuel Grossman
 *
 * Standards/Formatting:
 *   4 soft tab, wide column.
 *
 * Description:
 *  Defines macros and constants used throughout the Sobel accelerator.
 */

`define NUM_SOBEL_ACCELERATORS                  2                               // specifies the number of Sobel accelerators to instantiate

/** ** DO NOT EDIT BELOW THIS LINE ** **/

// Input and output data widths for the Sobel accelerator cores, in aggregate
`define SOBEL_ODATA_WIDTH                       (8*`NUM_SOBEL_ACCELERATORS)
`define SOBEL_IDATA_WIDTH                       (`SOBEL_ODATA_WIDTH+16)

// Command definitions for the row register
// Note that the default behavior of the row register is to clear the entire contents.
// To avoid this, be sure to always send it one of these valid commands.
`define SOBEL_ROW_OP_WIDTH                      2                               // specifes the width of the row operation signal, not an operation in and of itself
`define SOBEL_ROW_OP_HOLD                       `SOBEL_ROW_OP_WIDTH'h1          // row operation: keep contents the same
`define SOBEL_ROW_OP_SHIFT_ROW                  `SOBEL_ROW_OP_WIDTH'h2          // row operation: load new data into row 3, move old row 3 to row 2, move old row 2 to row 1, discard old row 1
