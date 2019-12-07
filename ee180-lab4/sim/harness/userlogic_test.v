`timescale 1 ns / 10 ps

`include "common_defines.v"

module userlogic_test();

    localparam AXIS_DWIDTH = 32;
    localparam BUF_SIZE = 32768;
    localparam ADDR_WIDTH = 15;
    
    localparam NUM_READ_OUT_MUX_BITS = `CLOG2((16*`NUM_16BIT_MEM_OUT)/AXIS_DWIDTH);
    
    genvar k;

    reg clk;
    reg rst_n;

    // User logic command, status, and test registers.
    reg  [31:0] ul_command = 32'h0;
    wire [31:0] ul_status;
    wire [31:0] ul_test;

    // Testbench parameters.
    integer read_instr_mem;
    integer read_input_buffer;
    integer write_output_buffer;
    integer write_test_result;
    integer dump_vars;

    reg  [1024*8:1] instr_mem_filename;
    reg  [1024*8:1] input_buffer_filename;
    reg  [1024*8:1] output_buffer_filename;
    reg  [1024*8:1] test_result_filename;
    reg  [1024*8:1] dump_vars_filename;
    reg  [9:0] image_n_rows;
    reg  [9:0] image_n_columns;

    reg  [32:1] num_cycles = 32'hFFFFFFFF;
    reg  [32:1] cycle_count = 0;

    // Used to dump output buffer to file.
    integer i, outfile;
    reg  [32:0] out_start_addr = 0;
    reg  [32:0] out_end_addr = (BUF_SIZE * 4);
    reg  [ADDR_WIDTH-1:0] read_addr = 0;
    wire [AXIS_DWIDTH-1:0] data_out;

    // Initialize testbench parameters.
    integer result;
    initial begin

        read_instr_mem = $value$plusargs("instr_mem=%s", instr_mem_filename);
        read_input_buffer = $value$plusargs("in_buf=%s", input_buffer_filename);
        write_output_buffer = $value$plusargs("out_buf=%s", output_buffer_filename);
        write_test_result = $value$plusargs("test_result=%s", test_result_filename);
        dump_vars = $value$plusargs("dumpvars=%s", dump_vars_filename);
        
        // Extract image width and height from the plus arguments.
        if (!$value$plusargs("image_rows=%d", image_n_rows)) begin
            $error("No image height is specified. Specify a height using +image_rows=<height>.");
            $finish;
        end
        if (!$value$plusargs("image_columns=%d", image_n_columns)) begin
            $error("No image width is specified. Specify a width using +image_columns=<height>.");
            $finish;
        end

        // Fill instruction memory and input buffer.
        if (read_instr_mem) begin
            $display("Instruction Memory: %0s", instr_mem_filename);
            $readmemh(instr_mem_filename, instr_mem.mem);
        end else begin
            $display("No instruction memory");
        end

        if (read_input_buffer) begin
            // because the number of input buffer memory instances is variable, the input buffer is read in the code where they are generated
            $display("Input Data Buffer: %0s", input_buffer_filename);
        end else begin
            $display("No input data buffer");
        end

        if (write_output_buffer) begin

            if ($test$plusargs("out_start")) begin
                result = $value$plusargs("out_start=%h", out_start_addr);
            end

            if ($test$plusargs("out_end")) begin
                result = $value$plusargs("out_end=%h", out_end_addr);
            end

            $display("Output buffer: %0s", output_buffer_filename);
            $display("  Dumping range: 0x%h - 0x%h", out_start_addr, out_end_addr);

            // Address are word-aligned in the buffer memories
            out_start_addr = out_start_addr >> 2;
            out_end_addr = out_end_addr >> 2;

        end else begin
            $display("No output buffer");
        end

        if ($test$plusargs("cycles")) begin
            result = $value$plusargs("cycles=%d", num_cycles);
        end

        $display("Running userlogic for maximum of %0d cycles", num_cycles);

    end

    initial begin

        // Initialize testbench signals
        clk = 1'b0;
        rst_n = 1'b0;

        // Create waveform dump
        if (dump_vars) begin
            $dumpfile(dump_vars_filename);
            $dumpvars(0, userlogic_test);
        end

        // Turn off reset after a few cycles
        #20 rst_n = 1'b1;

        // Run
        #10 ul_command = { 10'h0, image_n_columns, image_n_rows, 1'b0, 1'b1};

        cycle_count = num_cycles;
        while (cycle_count > 0 & ~ul_status[0] & ~ul_status[1]) begin
            cycle_count = cycle_count - 1;
            #10;
        end

        $display("Userlogic ran for %0d cycles", num_cycles - cycle_count);
        $display("status register = 0x%x", ul_status);
        $display("test register   = 0x%x", ul_test);

        ul_command = 32'h0;

        // Dump the output buffer.
        if (write_output_buffer) begin
            outfile = $fopen(output_buffer_filename, "w");
            for (i = out_start_addr; i < out_end_addr; i = i + 1) begin
                read_addr = i;
                #10;
                $fwrite(outfile, "%h\n", data_out);
            end
            $fclose(outfile);
        end

        // Write the test result.
        if (write_test_result) begin
            i = $fopen(test_result_filename, "w");
            $fwrite(i, "%0d", ul_test);
            $fclose(i);
        end

        $finish;
    end

    initial forever begin
        #5 clk = ~clk;
    end

    /* Signals used to connect the instruction memory and buffers to
     * userlogic. */
    wire [(32*`NUM_16BIT_MEM_IN)-1:0] ul_read_addr;
    wire [(16*`NUM_16BIT_MEM_IN)-1:0] ul_read_data;
    wire [(32*`NUM_16BIT_MEM_OUT)-1:0] ul_write_addr;
    wire [(16*`NUM_16BIT_MEM_OUT)-1:0] ul_write_data;
    wire [31:0] ul_instr_addr;
    wire [31:0] ul_instr;
    wire [(2*`NUM_16BIT_MEM_OUT)-1:0] ul_write_en;

    // Instruction Memory
    dataram2 #(65536, 16, 32) instr_mem (
        .clk(clk),
        .addr(ul_instr_addr[15:0]),
        .we(1'b0),
        .din({32{1'b0}}),
        .dout(ul_instr)
    );

    // Input Buffer - read only by user logic
    wire [(32*`NUM_16BIT_MEM_IN)-1:0] intermediate_read_data;
    
    generate
    for (k = 0; k < `NUM_16BIT_MEM_IN; k = k + 1) begin: input_buffer_gen
    
    wire [ADDR_WIDTH-1:0] adjusted_ul_read_addr = (ul_read_addr[((k+1)*32)-(32-ADDR_WIDTH)-1:(k*32)] << (`CLOG2(16*`NUM_16BIT_MEM_IN/AXIS_DWIDTH))) + ((`NUM_16BIT_MEM_IN - k - 1) / 2);
    
    dataram2 #(BUF_SIZE, ADDR_WIDTH, AXIS_DWIDTH) input_buffer (
        .clk(clk),
        .addr(adjusted_ul_read_addr),
        .we(1'b0),
        .din('h0),
        .dout(intermediate_read_data[((k+1)*32)-1:(k*32)])
    );
    
    assign ul_read_data[((k+1)*16)-1:(k*16)] = intermediate_read_data[((k+1)*32)-(((k+1)%2)*16)-1:(k*32)+((k%2)*16)];
    
    initial begin
        #1
        if (read_input_buffer) begin
                $readmemh(input_buffer_filename, input_buffer.mem);
        end
    end
    
    end
    endgenerate

    // Output Buffer - write only by user logic
    wire [(AXIS_DWIDTH/2)-1:0] intermediate_data_out[`NUM_16BIT_MEM_OUT-1:0];
    wire [31:0] output_buffer_addr[`NUM_16BIT_MEM_OUT-1:0];
    
    generate
    for (k = 0; k < `NUM_16BIT_MEM_OUT; k = k + 1) begin: output_buffer_gen
    
    if (AXIS_DWIDTH >= (16*`NUM_16BIT_MEM_OUT)) begin
        assign output_buffer_addr[k] = (ul_write_en[((k+1)*2)-1] | ul_write_en[(k*2)]) ? ul_write_addr[((k+1)*32)-1:(k*32)] : read_addr;
    end else begin
        assign output_buffer_addr[k] = (ul_write_en[((k+1)*2)-1] | ul_write_en[(k*2)]) ? ul_write_addr[((k+1)*32)-1:(k*32)] : (read_addr >> NUM_READ_OUT_MUX_BITS);
    end
        
    dataram3 #(.ADDR_WIDTH(ADDR_WIDTH), .COL_WIDTH(8), .N_COLS((AXIS_DWIDTH/2)/8)) output_buffer (
        .clk(clk),
        .addr(output_buffer_addr[k][ADDR_WIDTH-1:0]),
        .we(ul_write_en[((k+1)*2)-1:(k*2)]),
        .din(ul_write_data[((k+1)*16)-1:(k*16)]),
        .dout(intermediate_data_out[k])
    );
    
    end
    endgenerate
    
    generate
    for (k = 0; k < (AXIS_DWIDTH/16); k = k + 1) begin: data_out_gen
        
        if (AXIS_DWIDTH >= (16*`NUM_16BIT_MEM_OUT)) begin
            assign data_out[((k+1)*16)-1:(k*16)] = intermediate_data_out[k];
        end else begin
`ifdef SOBEL_WRITE_LITTLE_ENDIAN
            assign data_out[((k+1)*16)-1:(k*16)] = intermediate_data_out[k + (AXIS_DWIDTH/16)*(read_addr[NUM_READ_OUT_MUX_BITS-1:0])];
`else
            assign data_out[((k+1)*16)-1:(k*16)] = intermediate_data_out[k + (AXIS_DWIDTH/16)*({NUM_READ_OUT_MUX_BITS{1'b1}} - read_addr[NUM_READ_OUT_MUX_BITS-1:0])];
`endif
        end
        
    end
    endgenerate
    

    // User Logic
    userlogic #(BUF_SIZE, ADDR_WIDTH, AXIS_DWIDTH) ul (
        .clk(clk),
        .rst_n(rst_n),
        .instr(ul_instr),
        .instr_addr(ul_instr_addr),
        .read_data(ul_read_data),
        .read_addr(ul_read_addr),
        .write_data(ul_write_data),
        .write_addr(ul_write_addr),
        .write_en(ul_write_en),
        .command(ul_command),
        .status(ul_status),
        .test(ul_test)
    );

endmodule
