/*
 * File         : common_defines.v
 * Project      : EE180 Sobel accelerator lab
 * Creator(s)   : Samuel Grossman
 *
 * Standards/Formatting:
 *   4 soft tab, wide column.
 *
 * Description:
 *  Defines common configuration options used throughout the Sobel accelerator.
 *  These options comply with the requirements for projects based on the 
 *  Stream Engine.
 */

`include "sobel_defines.v"

// Calculates ceil(log2(N)); this way is tool-portable, some tools support $clog2, some don't...
`define CLOG2(N)                                ((N <=      1) ?  0 : \
                                                 (N <=      2) ?  1 : \
                                                 (N <=      4) ?  2 : \
                                                 (N <=      8) ?  3 : \
                                                 (N <=     16) ?  4 : \
                                                 (N <=     32) ?  5 : \
                                                 (N <=     64) ?  6 : \
                                                 (N <=    128) ?  7 : \
                                                 (N <=    256) ?  8 : \
                                                 (N <=    512) ?  9 : \
                                                 (N <=   1024) ? 10 : \
                                                 (N <=   2048) ? 11 : \
                                                 (N <=   4096) ? 12 : \
                                                 -1)

// Specifies the number of 16-bit memories to use, in aggregate, as the input buffer
`define NUM_16BIT_MEM_IN                        ((`NUM_SOBEL_ACCELERATORS == 2) ? 2 : \
                                                 (`NUM_SOBEL_ACCELERATORS == 4) ? 4 : \
                                                 (`NUM_SOBEL_ACCELERATORS == 6) ? 4 : \
                                                 (`NUM_SOBEL_ACCELERATORS == 8) ? 8 : \
                                                 -1)

// Specifies the number of 16-bit memories to use, in aggregate, as the output buffer
`define NUM_16BIT_MEM_OUT                       ((`NUM_SOBEL_ACCELERATORS == 2) ? 2 : \
                                                 (`NUM_SOBEL_ACCELERATORS == 4) ? 2 : \
                                                 (`NUM_SOBEL_ACCELERATORS == 6) ? 4 : \
                                                 (`NUM_SOBEL_ACCELERATORS == 8) ? 4 : \
                                                 -1)
