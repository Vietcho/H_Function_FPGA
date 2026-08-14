`timescale 1ns / 1ps

module H_function_core_tb;

    // ==============================================================
    // Parameters
    // ==============================================================
    parameter DATA_WIDTH  = 32;
    parameter W_ADDR_BITS = 4;
    parameter R_ADDR_BITS = 1;

    parameter CLK_PERIOD = 10;

    // ==============================================================
    // C-model file paths
    // ==============================================================
    // Forward slashes are used so the absolute Windows paths work
    // cleanly in Vivado/XSim without backslash escaping.
    parameter INPUT_FILE_PATH =
        "D:/TAI_LIEU/DU_AN_XU_LY_TINHIEU/XU_LY_TIN_HIEU_FPGA/IP_FPGA/H_function/C_Modeling/input_data.txt";

    parameter GOLDEN_FILE_PATH =
        "D:/TAI_LIEU/DU_AN_XU_LY_TINHIEU/XU_LY_TIN_HIEU_FPGA/IP_FPGA/H_function/C_Modeling/golden_output.txt";

    // ==============================================================
    // Memory map
    // ==============================================================
    localparam [W_ADDR_BITS-1:0] A_BASE_ADDR     = 4'd0;
    localparam [W_ADDR_BITS-1:0] B_BASE_ADDR     = 4'd1;
    localparam [W_ADDR_BITS-1:0] C_BASE_ADDR     = 4'd2;
    localparam [W_ADDR_BITS-1:0] D_BASE_ADDR     = 4'd3;
    localparam [W_ADDR_BITS-1:0] E_BASE_ADDR     = 4'd4;
    localparam [W_ADDR_BITS-1:0] F_BASE_ADDR     = 4'd5;

    localparam [W_ADDR_BITS-1:0] LOAD_BASE_ADDR  = 4'd6;
    localparam [W_ADDR_BITS-1:0] START_BASE_ADDR = 4'd7;
    localparam [W_ADDR_BITS-1:0] STOP_BASE_ADDR  = 4'd8;

    localparam [R_ADDR_BITS-1:0] H_BASE_ADDR          = 1'b0;
    localparam [R_ADDR_BITS-1:0] READ_READY_BASE_ADDR = 1'b1;

    // ==============================================================
    // DUT interface signals
    // ==============================================================
    reg                         CLK;
    reg                         RST;

    reg                         w_addr_valid_r;
    reg  [DATA_WIDTH-1:0]       w_data_r;
    reg  [W_ADDR_BITS-1:0]      w_addr_r;

    reg                         r_addr_valid_r;
    wire [DATA_WIDTH-1:0]       r_data_w;
    reg  [R_ADDR_BITS-1:0]      r_addr_r;

    // ==============================================================
    // Test-data registers
    // ==============================================================
    reg [DATA_WIDTH-1:0] a_data_r;
    reg [DATA_WIDTH-1:0] b_data_r;
    reg [DATA_WIDTH-1:0] c_data_r;
    reg [DATA_WIDTH-1:0] d_data_r;
    reg [DATA_WIDTH-1:0] e_data_r;
    reg [DATA_WIDTH-1:0] f_data_r;

    reg [DATA_WIDTH-1:0] golden_data_r;
    reg [DATA_WIDTH-1:0] dut_data_r;

    // ==============================================================
    // File handles and counters
    // ==============================================================
    integer input_file_r;
    integer golden_file_r;

    integer input_scan_count_r;
    integer golden_scan_count_r;

    integer total_tests_r;
    integer passed_tests_r;
    integer failed_tests_r;

    // ==============================================================
    // DUT
    // ==============================================================
    H_function_core #(
        .DATA_WIDTH  (DATA_WIDTH),
        .W_ADDR_BITS (W_ADDR_BITS),
        .R_ADDR_BITS (R_ADDR_BITS)
    ) DUT (
        .CLK             (CLK),
        .RST             (RST),

        .w_addr_valid_i  (w_addr_valid_r),
        .w_data_i        (w_data_r),
        .w_addr_i        (w_addr_r),

        .r_addr_valid_i  (r_addr_valid_r),
        .r_data_o        (r_data_w),
        .r_addr_i        (r_addr_r)
    );

    // ==============================================================
    // Clock generation
    // ==============================================================
    initial begin
        CLK = 1'b0;
        forever #(CLK_PERIOD/2) CLK = ~CLK;
    end

    // ==============================================================
    // Core write transaction
    // ==============================================================
    // Address/data are driven on a falling edge and remain stable
    // across the following rising edge.
    task core_write;
        input [W_ADDR_BITS-1:0] addr_i;
        input [DATA_WIDTH-1:0]  data_i;
        begin
            @(negedge CLK);

            w_addr_valid_r = 1'b1;
            w_addr_r       = addr_i;
            w_data_r       = data_i;

            @(negedge CLK);

            w_addr_valid_r = 1'b0;
            w_addr_r       = {W_ADDR_BITS{1'b0}};
            w_data_r       = {DATA_WIDTH{1'b0}};
        end
    endtask

    // ==============================================================
    // Core read transaction
    // ==============================================================
    // H_arbiter registers r_addr_i/r_addr_valid_i first.
    // r_data_o becomes valid one full CLK later.
    task core_read;
        input  [R_ADDR_BITS-1:0] addr_i;
        output [DATA_WIDTH-1:0]  data_o;
        begin
            @(negedge CLK);

            r_addr_valid_r = 1'b1;
            r_addr_r       = addr_i;

            // Rising edge N:
            // read request is captured into r_addr_r/r_addr_valid_r
            // inside H_arbiter.
            @(posedge CLK);

            @(negedge CLK);

            r_addr_valid_r = 1'b0;
            r_addr_r       = {R_ADDR_BITS{1'b0}};

            // Rising edge N+1:
            // H_arbiter updates r_data_o.
            @(posedge CLK);
            #1;

            data_o = r_data_w;
        end
    endtask

    // ==============================================================
    // Load one test vector into the DUT
    // ==============================================================
    task load_test_vector;
        input [DATA_WIDTH-1:0] a_i;
        input [DATA_WIDTH-1:0] b_i;
        input [DATA_WIDTH-1:0] c_i;
        input [DATA_WIDTH-1:0] d_i;
        input [DATA_WIDTH-1:0] e_i;
        input [DATA_WIDTH-1:0] f_i;
        begin
            // Enter LOAD state.
            core_write(LOAD_BASE_ADDR, 32'd1);

            // Write one complete data set.
            core_write(A_BASE_ADDR, a_i);
            core_write(B_BASE_ADDR, b_i);
            core_write(C_BASE_ADDR, c_i);
            core_write(D_BASE_ADDR, d_i);
            core_write(E_BASE_ADDR, e_i);
            core_write(F_BASE_ADDR, f_i);
        end
    endtask

    // ==============================================================
    // Start one calculation and read H
    // ==============================================================
    task run_h_function;
        output [DATA_WIDTH-1:0] h_o;
        begin
            // LOAD -> READ
            core_write(START_BASE_ADDR, 32'd1);

            // After core_write() returns, DUT is in READ_STATE.
            //
            // Next rising edge:
            //   READ -> COMPUTE and A..F are captured.
            //
            // Next rising edge:
            //   COMPUTE -> WRITE and H is computed.
            //
            // Next rising edge:
            //   WRITE -> IDLE and H is stored in output memory.
            repeat (3) @(posedge CLK);

            // Read result through the memory-mapped read channel.
            core_read(H_BASE_ADDR, h_o);
        end
    endtask

    // ==============================================================
    // Main test sequence
    // ==============================================================
    initial begin

        // ----------------------------------------------------------
        // Initial values
        // ----------------------------------------------------------
        RST = 1'b0;

        w_addr_valid_r = 1'b0;
        w_data_r       = {DATA_WIDTH{1'b0}};
        w_addr_r       = {W_ADDR_BITS{1'b0}};

        r_addr_valid_r = 1'b0;
        r_addr_r       = {R_ADDR_BITS{1'b0}};

        a_data_r       = {DATA_WIDTH{1'b0}};
        b_data_r       = {DATA_WIDTH{1'b0}};
        c_data_r       = {DATA_WIDTH{1'b0}};
        d_data_r       = {DATA_WIDTH{1'b0}};
        e_data_r       = {DATA_WIDTH{1'b0}};
        f_data_r       = {DATA_WIDTH{1'b0}};

        golden_data_r  = {DATA_WIDTH{1'b0}};
        dut_data_r     = {DATA_WIDTH{1'b0}};

        total_tests_r  = 0;
        passed_tests_r = 0;
        failed_tests_r = 0;

        // ----------------------------------------------------------
        // Reset DUT
        // ----------------------------------------------------------
        repeat (5) @(posedge CLK);

        @(negedge CLK);
        RST = 1'b1;

        repeat (2) @(posedge CLK);

        // ----------------------------------------------------------
        // Open C-model files
        // ----------------------------------------------------------
        input_file_r = $fopen(INPUT_FILE_PATH, "r");

        if (input_file_r == 0) begin
            $display("============================================================");
            $display("ERROR: Cannot open input file:");
            $display("%s", INPUT_FILE_PATH);
            $display("============================================================");
            $finish;
        end

        golden_file_r = $fopen(GOLDEN_FILE_PATH, "r");

        if (golden_file_r == 0) begin
            $display("============================================================");
            $display("ERROR: Cannot open golden output file:");
            $display("%s", GOLDEN_FILE_PATH);
            $display("============================================================");

            $fclose(input_file_r);
            $finish;
        end

        $display("");
        $display("============================================================");
        $display("             H_FUNCTION RTL VERIFICATION START");
        $display("============================================================");
        $display("Input file  : %s", INPUT_FILE_PATH);
        $display("Golden file : %s", GOLDEN_FILE_PATH);
        $display("------------------------------------------------------------");

        // ----------------------------------------------------------
        // Process all available test vectors
        // ----------------------------------------------------------
        while ((!$feof(input_file_r)) && (!$feof(golden_file_r))) begin

            input_scan_count_r =
                $fscanf(
                    input_file_r,
                    "%h %h %h %h %h %h\n",
                    a_data_r,
                    b_data_r,
                    c_data_r,
                    d_data_r,
                    e_data_r,
                    f_data_r
                );

            golden_scan_count_r =
                $fscanf(
                    golden_file_r,
                    "%h\n",
                    golden_data_r
                );

            // Only execute a test when one complete input line and one
            // complete golden-output line were read successfully.
            if ((input_scan_count_r == 6) &&
                (golden_scan_count_r == 1)) begin

                total_tests_r = total_tests_r + 1;

                load_test_vector(
                    a_data_r,
                    b_data_r,
                    c_data_r,
                    d_data_r,
                    e_data_r,
                    f_data_r
                );

                run_h_function(dut_data_r);

                if (dut_data_r === golden_data_r) begin

                    passed_tests_r = passed_tests_r + 1;

                    $display(
                        "[PASS] Test %0d : DUT = %08h, GOLDEN = %08h",
                        total_tests_r,
                        dut_data_r,
                        golden_data_r
                    );

                end
                else begin

                    failed_tests_r = failed_tests_r + 1;

                    $display(
                        "[FAIL] Test %0d : DUT = %08h, GOLDEN = %08h",
                        total_tests_r,
                        dut_data_r,
                        golden_data_r
                    );

                    $display(
                        "       A=%08h B=%08h C=%08h D=%08h E=%08h F=%08h",
                        a_data_r,
                        b_data_r,
                        c_data_r,
                        d_data_r,
                        e_data_r,
                        f_data_r
                    );

                end
            end
        end

        // ----------------------------------------------------------
        // Close files
        // ----------------------------------------------------------
        $fclose(input_file_r);
        $fclose(golden_file_r);

        // ----------------------------------------------------------
        // Final summary
        // ----------------------------------------------------------
        $display("");
        $display("============================================================");
        $display("                H_FUNCTION TEST SUMMARY");
        $display("============================================================");
        $display("TOTAL TEST CASES : %0d", total_tests_r);
        $display("PASSED           : %0d", passed_tests_r);
        $display("FAILED           : %0d", failed_tests_r);
        $display("------------------------------------------------------------");

        if ((failed_tests_r == 0) && (total_tests_r > 0)) begin
            $display("FINAL RESULT     : ALL TESTS PASSED");
        end
        else begin
            $display("FINAL RESULT     : TEST FAILED");
        end

        $display("============================================================");
        $display("");

        repeat (5) @(posedge CLK);
        $finish;
    end

endmodule
