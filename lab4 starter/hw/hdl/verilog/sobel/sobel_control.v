/*
 * File         : sobel_control.v
 * Project      : EE180 Sobel accelerator lab
 * Creator(s)   : Samuel Grossman
 *
 * Standards/Formatting:
 *   4 soft tab, wide column.
 *
 * Description:
 *  Controls the flow of the Sobel accelerator core so that
 *  it processes the entire contents of an input buffer and
 *  fills an output buffer with the results of the computation.
 */

`include "common_defines.v"

module sobel_control
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
    
    // Interface: Sobel Control -> Memory (input and output buffers)
    output  [IOBUF_ADDR_WIDTH-1:0]              sctl2srt_read_addr,                 // input buffer read address
    output  [IOBUF_ADDR_WIDTH-1:0]              sctl2swt_write_addr,                // output buffer write address
    output  [`NUM_SOBEL_ACCELERATORS-1:0]       sctl2swt_write_en,                  // output buffer write enable, per output pixel
    
    // Interface: Sobel Control -> Sobel Image Row Registers
    output  [`SOBEL_ROW_OP_WIDTH-1:0]           sctl2srow_row_op,                   // Sobel row register command
    
    // External command register signals
    input   [IMAGE_DIM_WIDTH-1:0]               stop2sctl_image_n_rows,             // number of rows in the input image data
    input   [IMAGE_DIM_WIDTH-1:0]               stop2sctl_image_n_cols,             // number of columns in the input image data
    
    // External status register signals
    output  [STATUS_REG_WIDTH-1:0]              sctl2stop_status                    // status indicator, contains "done" bit, "error" bit, and accelerator's state
);

// State definitions
localparam  STATE_WIDTH                         = 4;                                // not a state, just says "state signals shall be 4 bits wide"
localparam  STATE_WAIT                          = 'h0;                              // waiting for the host system to send an external command to start the accelerator
localparam  STATE_LOADING_1                     = 'h1;                              // reading in the first row of a new column strip (no calculations yet)
localparam  STATE_LOADING_2                     = 'h2;                              // reading in the second row of a new column strip (no calculations yet)
localparam  STATE_LOADING_3                     = 'h3;                              // reading in the third row of a new column strip (no calculations yet)
localparam  STATE_PROCESSING_CALC               = 'h4;                              // calculating the Sobel convolution and producing an output
localparam  STATE_PROCESSING_LOADSS             = 'h5;                              // loading in the next row in the current column strip
localparam  STATE_PROCESSING_CALC_LAST          = 'h6;                              // calculating the Sobel convolution and producing an output for the last row in the current column strip
localparam  STATE_PROCESSING_LOADSS_LAST        = 'h7;                              // loading in the last row in the current column strip
localparam  STATE_PROCESSING_DONE               = 'h8;                              // completed processing the entire image buffer, waiting for action from the host system
localparam  STATE_ERROR                         = 'hf;                              // an error occurred (should never get here)

// Internal signals
wire        [STATE_WIDTH-1:0]                   state;                          // state signal, driven by register
reg         [STATE_WIDTH-1:0]                   state_next;                     // next state signal, drives register
wire        [IMAGE_DIM_WIDTH-1:0]               control_n_rows;                 // number of rows, from control register
wire        [IMAGE_DIM_WIDTH-1:0]               control_n_cols;                 // number of columns, from control register
wire        [IMAGE_DIM_WIDTH-1:0]               row_counter;                    // row counter signal, driven by register
reg         [IMAGE_DIM_WIDTH-1:0]               row_counter_next;               // next row counter signal, drives register
wire        [IMAGE_DIM_WIDTH-1:0]               col_strip;                      // column strip signal, driven by register
reg         [IMAGE_DIM_WIDTH-1:0]               col_strip_next;                 // next column strip signal, drives register
wire        [IOBUF_ADDR_WIDTH-1:0]              buf_read_offset;                // read offset from the input buffer, driven by register
reg         [IOBUF_ADDR_WIDTH-1:0]              buf_read_offset_next;           // read offset from the input buffer, drives register
wire        [IOBUF_ADDR_WIDTH-1:0]              buf_write_offset;               // write offset to the output buffer, driven by register
reg         [IOBUF_ADDR_WIDTH-1:0]              buf_write_offset_next;          // write offset to the output buffer, drives register
reg                                             buf_write_en;                   // write enable signal, driven combinationally
wire        [IMAGE_DIM_WIDTH-1:0]               buf_write_row_incr;             // specifies the row increment for output, equals input width minus 2, driven combinationally
wire        [IMAGE_DIM_WIDTH-1:0]               next_col_strip;                 // specifies the next column strip to process, equals current column strip + number of accelerators
wire        [IMAGE_DIM_WIDTH-1:0]               max_col_strip;                  // specifies the highest column strip to process before being done, equals the number of columns - number of accelerators
reg         [`SOBEL_ROW_OP_WIDTH-1:0]           row_op;                         // specifies the command to send to the Sobel image row registers
wire        [`NUM_SOBEL_ACCELERATORS-1:0]       pixel_write_en;                 // per-pixel write enable signal
genvar                                          i;

// Output generation
assign      sctl2srt_read_addr                  = buf_read_offset;
assign      sctl2swt_write_addr                 = buf_write_offset;
assign      sctl2srow_row_op                    = row_op;
assign      sctl2stop_status                    = {{STATUS_REG_WIDTH-STATE_WIDTH-2{1'b0}}, state, (state == STATE_ERROR), (state == STATE_PROCESSING_DONE)};
assign      sctl2swt_write_en                   = go ? pixel_write_en : 'h0;

// Registers
dffr #(STATE_WIDTH)                     state_r (                               // main state register
    .clk                                        (clk),
    .r                                          (reset),
    .d                                          (state_next),
    .q                                          (state)
);

dffre #(IMAGE_DIM_WIDTH)                control_n_rows_r (                      // control register: number of rows in input image data
    .clk                                        (clk),
    .r                                          (reset),
    .en                                         (state == STATE_WAIT),
    .d                                          (stop2sctl_image_n_rows),
    .q                                          (control_n_rows)
);

dffre #(IMAGE_DIM_WIDTH)                control_n_cols_r (                      // control register: number of columns in input image data
    .clk                                        (clk),
    .r                                          (reset),
    .en                                         (state == STATE_WAIT),
    .d                                          (stop2sctl_image_n_cols),
    .q                                          (control_n_cols)
);

dffre #(IMAGE_DIM_WIDTH)                row_counter_r (                         // row counter register
    .clk                                        (clk),
    .r                                          (reset),
    .en                                         (go),
    .d                                          (row_counter_next),
    .q                                          (row_counter)
);

dffre #(IMAGE_DIM_WIDTH)                col_strip_r (                           // column strip register
    .clk                                        (clk),
    .r                                          (reset),
    .en                                         (go),
    .d                                          (col_strip_next),
    .q                                          (col_strip)
);

dffre #(IOBUF_ADDR_WIDTH)               buf_read_offset_r (                     // read offset register
    .clk                                        (clk),
    .r                                          (reset),
    .en                                         (go),
    .d                                          (buf_read_offset_next),
    .q                                          (buf_read_offset)
);

dffre #(IOBUF_ADDR_WIDTH)               buf_write_offset_r (                    // write offset register
    .clk                                        (clk),
    .r                                          (reset),
    .en                                         (go),
    .d                                          (buf_write_offset_next),
    .q                                          (buf_write_offset)
);


/* *** *** *** YOUR CODE GOES BELOW THIS LINE *** *** *** */


// *** Row address increment ***
// The value of this signal specifies the width of an output row.
// Insert your code here.
assign      buf_write_row_incr                  = 'h0;

// *** Column strip increment ***
// The value of this signal specifies the start column of the next column strip.
// Insert your code here.
assign      next_col_strip                      = 'h0;

// *** Column strip maximum ***
// The value of this signal is the termination condition.
// What is the highest possible value of col_strip that indicates there are still more input pixels to process?
// Insert your code here.
assign      max_col_strip                       = 'h0;

generate
for (i = 0; i < `NUM_SOBEL_ACCELERATORS; i = i + 1) begin: sobel_write_en

// *** Write enable ***
// If pixel_write_en[i] is set to 1, this tells the memory system that the current pixel at index i from the Sobel accelerator contains valid data to be written.
// Make sure to only set it to 1 when the Sobel accelerator is producing valid data at that pixel position.
assign      pixel_write_en[i]                   = 'h0;

end
endgenerate

// *** State transitions (combinational circuitry) ***
// Insert your state transition code where indicated.
// You should only write to the "state_next" signal in this block, no others.
always @ (*) begin
    // Default behavior is to maintain the current state.
    state_next                                  = state;
    
    case (state)
        STATE_WAIT: begin
            if (go) begin
                // *** Wait state ***
                // Once the host sends the "go" command, the accelerator starts.
                // This state's implementation is complete and provided as an example.
                state_next                      = STATE_LOADING_1;
            end
            
            // Note that here is no need to specify "else" here because the default behavior is to hold current state.
            // You only need to specify the conditions that warrant a state change.
        end
        
        STATE_LOADING_1: begin
            if (go) begin
                // *** Row 1 loading state ***
                // Insert your state transition code here.
                state_next                      = STATE_ERROR;
            end
        end
        
        STATE_LOADING_2: begin
            if (go) begin
                // *** Row 2 loading state ***
                // Insert your state transition code here.
                state_next                      = STATE_ERROR;
            end
        end
        
        STATE_LOADING_3: begin
            if (go) begin
                // *** Row 3 loading state ***
                // Insert your state transition code here.
                state_next                      = STATE_ERROR;
            end
        end
        
        STATE_PROCESSING_CALC: begin
            if (go) begin
                // *** Calculation state ***
                // Insert your state transition code here.
                state_next                      = STATE_ERROR;
            end
        end
        
        STATE_PROCESSING_LOADSS: begin
            if (go) begin
                // *** Next row loading state ***
                // Insert your state transition code here.
                state_next                      = STATE_ERROR;
            end
        end
        
        STATE_PROCESSING_CALC_LAST: begin
            if (go) begin
                // *** Last-row-in-column-strip calculation state ***
                // Insert your state transition code here.
                state_next                      = STATE_ERROR;
            end
        end
        
        STATE_PROCESSING_LOADSS_LAST: begin
            if (go) begin
                // *** Last-row-in-column loading state ***
                // Insert your state transition code here.
                state_next                      = STATE_ERROR;
            end
        end
        
        STATE_PROCESSING_DONE: begin
            if (~go) begin
                // *** Processing completed state ***
                // In this state, the accelerator is waiting for action from the host system.
                // Its implementation is complete as given.
                state_next                      = STATE_WAIT;
            end
        end
        
        STATE_ERROR: begin
            if (go) begin
                // *** Error state ***
                // The accelerator should never get to this state.
                // However, once it is here, it will never leave.
                state_next                      = STATE_ERROR;
            end
        end
        
        default: begin
            if (go) begin
                // *** Catch-all default ***
                // In case of anything unpredicted, will cause an error.
                state_next                      = STATE_ERROR;
            end
        end
    endcase
end

// *** Row register command generation (combinational circuitry) ***
// The job of this block is to send commands to the row register, based on the current state.
// The commands are defined as macros in "sobel_defines.v"; look there to see what the valid commands are.
// When using macros, remember to add the ` character before the name, such as `SOBEL_ROW_OP_HOLD (just SOBEL_ROW_OP_HOLD won't work).
// You should only write to the "row_op" signal in this block, no others.
// Insert your code where indicated.
always @ (*) begin
    // What is the correct default behavior? Place your command here.
    row_op                                      = 'h0;
    
    case (state)
        STATE_WAIT: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            row_op                              = 'h0;
        end
        
        STATE_LOADING_1: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            row_op                              = 'h0;
        end
        
        STATE_LOADING_2: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            row_op                              = 'h0;
        end
        
        STATE_LOADING_3: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            row_op                              = 'h0;
        end
        
        STATE_PROCESSING_CALC: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            row_op                              = 'h0;
        end
        
        STATE_PROCESSING_LOADSS: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            row_op                              = 'h0;
        end
        
        STATE_PROCESSING_CALC_LAST: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            row_op                              = 'h0;
        end
        
        STATE_PROCESSING_LOADSS_LAST: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            row_op                              = 'h0;
        end
        
        STATE_PROCESSING_DONE: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            row_op                              = 'h0;
        end
        
        STATE_ERROR: begin
            // What happens in case of an error? Insert your code here. If nothing changes, you can remove this case completely.
            row_op                              = 'h0;
        end
        
        default: begin
            // What happens in the default (unexpected) case? Insert your code here. If nothing changes, you can remove this case completely.
            row_op                              = 'h0;
        end
    endcase
end

// *** Row counter (combinational circuitry) ***
// The job of this block is to keep track of the row number the accelerator is currently processing.
// How the row counter changes is related to the current state of the accelerator's state machine.
// You should only write to the "row_counter_next" signal in this block, no others.
// Insert your code where indicated.
always @ (*) begin
    // Default behavior is to maintain the current row number.
    row_counter_next                            = row_counter;
    
    case (state)
        STATE_WAIT: begin
            // What should the starting value be? Insert your code here.
            row_counter_next                    = 'h0;
        end
        
        STATE_LOADING_1: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            row_counter_next                    = 'h0;
        end
        
        STATE_LOADING_2: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            row_counter_next                    = 'h0;
        end
        
        STATE_LOADING_3: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            row_counter_next                    = 'h0;
        end
        
        STATE_PROCESSING_CALC: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            row_counter_next                    = 'h0;
        end
        
        STATE_PROCESSING_LOADSS: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            row_counter_next                    = 'h0;
        end
        
        STATE_PROCESSING_CALC_LAST: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            row_counter_next                    = 'h0;
        end
        
        STATE_PROCESSING_LOADSS_LAST: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            row_counter_next                    = 'h0;
        end
        
        STATE_PROCESSING_DONE: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            row_counter_next                    = 'h0;
        end
        
        STATE_ERROR: begin
            // What happens in case of an error? Insert your code here. If nothing changes, you can remove this case completely.
            row_counter_next                    = 'h0;
        end
        
        default: begin
            // What happens in the default (unexpected) case? Insert your code here. If nothing changes, you can remove this case completely.
            row_counter_next                    = 'h0;
        end
    endcase
end

// *** Column strip counter (combinational circuitry) ***
// The job of this block is to keep track of the column strip number the accelerator is currently processing.
// Note that "column strip" refers to the starting pixel, within a given row, that goes to the accelerator's input.
// For example, with 2 accelerators accepting 4 bytes of input, if column strip is 2, then the accelerators expect columns 2, 3, 4, and 5 as input for each row.
// You should only write to the "col_strip_next" signal in this block, no others.
// Insert your code where indicated.
always @ (*) begin
    // Default behavior is to maintain the current column strip.
    col_strip_next                              = col_strip;
    
    case (state)
        STATE_WAIT: begin
            // What should the starting value be? Insert your code here.
            col_strip_next                      = 'h0;
        end
        
        STATE_LOADING_1: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            col_strip_next                      = 'h0;
        end
        
        STATE_LOADING_2: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            col_strip_next                      = 'h0;
        end
        
        STATE_LOADING_3: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            col_strip_next                      = 'h0;
        end
        
        STATE_PROCESSING_CALC: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            col_strip_next                      = 'h0;
        end
        
        STATE_PROCESSING_LOADSS: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            col_strip_next                      = 'h0;
        end
        
        STATE_PROCESSING_CALC_LAST: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            col_strip_next                      = 'h0;
        end
        
        STATE_PROCESSING_LOADSS_LAST: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            col_strip_next                      = 'h0;
        end
        
        STATE_PROCESSING_DONE: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            col_strip_next                      = 'h0;
        end
        
        STATE_ERROR: begin
            // What happens in case of an error? Insert your code here. If nothing changes, you can remove this case completely.
            col_strip_next                      = 'h0;
        end
        
        default: begin
            // What happens in the default (unexpected) case? Insert your code here. If nothing changes, you can remove this case completely.
            col_strip_next                      = 'h0;
        end
    endcase
end

// *** Read address/offset calculation (combinational circuitry) ***
// The job of this block is to calculate the correct read address to send to memory.
// The read address currently being sent to memory is "buf_read_offset", so here we calculate what should be next.
// Recall that the read address equals the pixel offset from the beginning of the image.
// Since images are stored in row-major order, the read address would be equal to (row number * row width) + (column number).
// You should only write to the "buf_read_offset_next" signal in this block, no others.
// Insert your code where indicated.
always @ (*) begin
    // What is the correct default behavior? Place your code here.
    buf_read_offset_next                        = 'h0;
    
    case (state)
        STATE_WAIT: begin
            if (go) begin
                // Once the control signal is asserted, does something need to happen?
                // Think about what the next state is going to be and what data the accelerator expects to get.
                buf_read_offset_next            = 'h0;
            end else begin
                // If there is no control signal, just read from the beginning of the image.
                // This part is provided for you.
                buf_read_offset_next            = 'h0;
            end
        end
        
        STATE_LOADING_1: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            buf_read_offset_next                = 'h0;
        end
        
        STATE_LOADING_2: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            buf_read_offset_next                = 'h0;
        end
        
        STATE_LOADING_3: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            buf_read_offset_next                = 'h0;
        end
        
        STATE_PROCESSING_CALC: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            buf_read_offset_next                = 'h0;
        end
        
        STATE_PROCESSING_LOADSS: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            buf_read_offset_next                = 'h0;
        end
        
        STATE_PROCESSING_CALC_LAST: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            buf_read_offset_next                = 'h0;
        end
        
        STATE_PROCESSING_LOADSS_LAST: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            buf_read_offset_next                = 'h0;
        end
        
        STATE_PROCESSING_DONE: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            buf_read_offset_next                = 'h0;
        end
        
        STATE_ERROR: begin
            // What happens in case of an error? Insert your code here. If nothing changes, you can remove this case completely.
            buf_read_offset_next                = 'h0;
        end
        
        default: begin
            // What happens in the default (unexpected) case? Insert your code here. If nothing changes, you can remove this case completely.
            buf_read_offset_next                = 'h0;
        end
    endcase
end

// *** Write address/offset calculation (combinational circuitry) ***
// The job of this block is to calculate the correct write address to send to memory.
// The write address currently being sent to memory is "buf_write_offset", so here we calculate what should be next.
// Recall that the write address equals the pixel offset from the beginning of the image.
// Also, the size of the output image is different from the size of the input image!
// You should only write to the "buf_write_offset_next" signal in this block, no others.
// Insert your code where indicated.
always @ (*) begin
    // What is the correct default behavior? Place your code here.
    buf_write_offset_next                       = 'h0;
    
    case (state)
        STATE_WAIT: begin
            // What should the starting value be? Insert your code here.
            buf_write_offset_next               = 'h0;
        end
        
        STATE_LOADING_1: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            buf_write_offset_next               = 'h0;
        end
        
        STATE_LOADING_2: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            buf_write_offset_next               = 'h0;
        end
        
        STATE_LOADING_3: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            buf_write_offset_next               = 'h0;
        end
        
        STATE_PROCESSING_CALC: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            buf_write_offset_next               = 'h0;
        end
        
        STATE_PROCESSING_LOADSS: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            buf_write_offset_next               = 'h0;
        end
        
        STATE_PROCESSING_CALC_LAST: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            buf_write_offset_next               = 'h0;
        end
        
        STATE_PROCESSING_LOADSS_LAST: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            buf_write_offset_next               = 'h0;
        end
        
        STATE_PROCESSING_DONE: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            buf_write_offset_next               = 'h0;
        end
        
        STATE_ERROR: begin
            // What happens in case of an error? Insert your code here. If nothing changes, you can remove this case completely.
            buf_write_offset_next               = 'h0;
        end
        
        default: begin
            // What happens in the default (unexpected) case? Insert your code here. If nothing changes, you can remove this case completely.
            buf_write_offset_next               = 'h0;
        end
    endcase
end

// *** Write enable generation (combinational circuitry) ***
// The job of this block is to determine whether the data currently being sent to memory is valid.
// The validity of output data depends on the current state; the accelerator cores are always producing data, but it is sometimes garbage and sometimes valid.
// Unless this signal is set to 1, the output buffer will ignore any attempts to write to it.
// This signal is an overall validity signal that does not take into account individual pixels; for that, look up at the sctl2swt_write_en[] signal family.
// Note that, unlike for read and write addresses, this signal corresponds to the state of affairs in the current cycle when it is assigned.
// So if it is set to 1, it means that the address supplied by "buf_write_offset" is immediately valid in its current form.
// You should only write to the "buf_write_en" signal in this block, no others.
// Insert your code where indicated.
always @ (*) begin
    // What is the correct default behavior? Place your code here.
    buf_write_en                                = 1'b0;
    
    case (state)
        STATE_WAIT: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            buf_write_en                        = 1'b0;
        end
        
        STATE_LOADING_1: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            buf_write_en                        = 1'b0;
        end
        
        STATE_LOADING_2: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            buf_write_en                        = 1'b0;
        end
        
        STATE_LOADING_3: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            buf_write_en                        = 1'b0;
        end
        
        STATE_PROCESSING_CALC: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            buf_write_en                        = 1'b0;
        end
        
        STATE_PROCESSING_LOADSS: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            buf_write_en                        = 1'b0;
        end
        
        STATE_PROCESSING_CALC_LAST: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            buf_write_en                        = 1'b0;
        end
        
        STATE_PROCESSING_LOADSS_LAST: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            buf_write_en                        = 1'b0;
        end
        
        STATE_PROCESSING_DONE: begin
            // What happens in this state? Insert your code here. If nothing changes, you can remove this case completely.
            buf_write_en                        = 1'b0;
        end
        
        STATE_ERROR: begin
            // What happens in case of an error? Insert your code here. If nothing changes, you can remove this case completely.
            buf_write_en                        = 1'b0;
        end
        
        default: begin
            // What happens in the default (unexpected) case? Insert your code here. If nothing changes, you can remove this case completely.
            buf_write_en                        = 1'b0;
        end
    endcase
end

endmodule
