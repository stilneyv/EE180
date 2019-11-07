/*
 * File         : sobel_accelerator.v
 * Project      : EE180 Sobel accelerator lab
 * Creator(s)   : Samuel Grossman (modified from Parker's old design)
 *
 * Standards/Formatting:
 *   4 soft tab, wide column.
 *
 * Description:
 *  Runs a Sobel edge detection convolution on an input
 *  image row and outputs the results.
 */

`include "common_defines.v"

module sobel_accelerator
(
    // Interface: Sobel Image Row Registers -> Sobel Accelerator Core
    input   [`SOBEL_IDATA_WIDTH-1:0]            srow2sacc_row1_data,            // row 1 input data to accelerator core
    input   [`SOBEL_IDATA_WIDTH-1:0]            srow2sacc_row2_data,            // row 2 input data to accelerator core
    input   [`SOBEL_IDATA_WIDTH-1:0]            srow2sacc_row3_data,            // row 3 input data to accelerator core
    
    // Interface: Sobel Accelerator Core -> Memory (output buffer)
    output  [`SOBEL_ODATA_WIDTH-1:0]            sacc2swt_write_data             // result of Sobel convolution calculation
);

// Internal signals
reg     [`SOBEL_ODATA_WIDTH-1:0]                sobel_out;                          // the accelerator's output, N pixels wide
wire    [`SOBEL_IDATA_WIDTH-1:0]                row1, row2, row3;                   // current row pixel values for calculating the Sobel convolution
reg [11:0] sobel_sum[`NUM_SOBEL_ACCELERATORS-1:0];                                  // for holding the complete (sobel_sum) and partial (conv[xy]*) Sobel convolution sums
reg [11:0] convx[`NUM_SOBEL_ACCELERATORS-1:0], convx11 [`NUM_SOBEL_ACCELERATORS-1:0], convx12 [`NUM_SOBEL_ACCELERATORS-1:0], convx13 [`NUM_SOBEL_ACCELERATORS-1:0], convx31 [`NUM_SOBEL_ACCELERATORS-1:0], convx32 [`NUM_SOBEL_ACCELERATORS-1:0], convx33 [`NUM_SOBEL_ACCELERATORS-1:0];
reg [11:0] convy[`NUM_SOBEL_ACCELERATORS-1:0], convy11 [`NUM_SOBEL_ACCELERATORS-1:0], convy13 [`NUM_SOBEL_ACCELERATORS-1:0], convy21 [`NUM_SOBEL_ACCELERATORS-1:0], convy23 [`NUM_SOBEL_ACCELERATORS-1:0], convy31 [`NUM_SOBEL_ACCELERATORS-1:0], convy33 [`NUM_SOBEL_ACCELERATORS-1:0];

// Internal concurrent assignments
assign      row1                                = srow2sacc_row1_data;
assign      row2                                = srow2sacc_row2_data;
assign      row3                                = srow2sacc_row3_data;

// Output generation
assign      sacc2swt_write_data                 = sobel_out;


/* *** *** *** YOUR CODE GOES BELOW THIS LINE *** *** *** */

// *** Extra signal declarations ***
// If you need any extra signals to help with the convolution, declare them here. Otherwise, you may remove these comments.
// Note that you will need to use "reg" (not "wire") for any signals written to inside the "always" block.



// *** Sobel convolution implementation ***
// The provided implementation is incomplete. You will need to finish it.
// See below comments for more information on how to do so.
generate
    genvar c;
    
    // *** Generation of Sobel accelerator cores ***
    // This block programatically creates all the Sobel accelerator cores.
    // Control flow constructs, like this "for" loop, are executed at synthesis time.
    // The genvar "c" is just an integer. In the context of the "for" loop, it identifies each Sobel accelerator core.
    // For example, "convx11[0]" means "the signal convx11 for accelerator core 0," and so on.
    // Each of these signals is created essentially as a 2D array, the first dimension specifying the element width and the second specifying the number of elements.
    // For example, "convx11[2][1:0]" selects bits [1:0] of signal convx11[2].
    for (c = 0; c < `NUM_SOBEL_ACCELERATORS; c = c + 1) begin: convolve
        always @(*) begin
            // *** Calculation of the horizontal Sobel convolution ***
            // Each "convx" value corresponds to an input to that calculation, a different pixel in the 9-by-9 grid.
            // These values must be combined in a way that faithfully implements the Sobel convolution algorithm.
            convx11[c] = { 4'b0, row1[(c+3)*8-1:(c+2)*8]       };
            convx12[c] = { 3'b0, row1[(c+2)*8-1:(c+1)*8], 1'b0 };             // this value is being multiplied by 2
            convx13[c] = { 4'b0, row1[(c+1)*8-1:c*8]           };
            convx31[c] = { 4'b0, row3[(c+3)*8-1:(c+2)*8]       };
            convx32[c] = { 3'b0, row3[(c+2)*8-1:(c+1)*8], 1'b0 };             // this value is being multiplied by 2
            convx33[c] = { 4'b0, row3[(c+1)*8-1:c*8]           };
            
            // Combine the values above in a way that faithfully implements Sobel.
            // You may declare more signals as needed.
            convx[c]   = 'h0; 
            
            // *** Calculation of the vertical Sobel convolution ***
            // Each "convy" value corresponds to an input to that calculation, a different pixel in the 9-by-9 grid.
            // These values must be combined in a way that faithfully implements the Sobel convolution algorithm.
            convy11[c] = { 4'b0, row1[(c+3)*8-1:(c+2)*8]       };
            convy13[c] = { 4'b0, row1[(c+1)*8-1:c*8]           };
            convy21[c] = { 3'b0, row2[(c+3)*8-1:(c+2)*8], 1'b0 };             // this value is being multiplied by 2
            convy23[c] = { 3'b0, row2[(c+1)*8-1:c*8],     1'b0 };             // this value is being multiplied by 2
            convy31[c] = { 4'b0, row3[(c+3)*8-1:(c+2)*8]       };
            convy33[c] = { 4'b0, row3[(c+1)*8-1:c*8]           };
            
            // Combine the values above in a way that faithfully implements Sobel.
            // You may declare more signals as needed.
            convy[c]   = 'h0;
            
            // *** Calculation of the overall Sobel convolution result ***
            // The horizontal and vertical convolutions must be combined in a way that faithfully implements the Sobel convolution algorithm.
            sobel_sum[c] = 'h0;
            
            // *** Writing out the Sobel convolution result ***
            // This line should place the output of the Sobel convolution (the lines above) into the correct location in the output byte vector.
            // It currently does that without modifications. You may need to change it or keep it as is, depending on your implementation.
            sobel_out[(c+1)*8-1:(c)*8] = sobel_sum[c][7:0];
        end
    end
endgenerate

endmodule
