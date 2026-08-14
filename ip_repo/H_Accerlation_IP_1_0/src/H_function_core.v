`timescale 1ns / 1ps

module H_function_core #(
    parameter DATA_WIDTH  = 32,
    parameter W_ADDR_BITS = 4,
    parameter R_ADDR_BITS = 1
)(
    input  wire                         CLK,
    input  wire                         RST,

    // --------------------------------------------------------------
    // Write channel
    // --------------------------------------------------------------
    input  wire                         w_addr_valid_i,
    input  wire [DATA_WIDTH-1:0]        w_data_i,
    input  wire [W_ADDR_BITS-1:0]       w_addr_i,

    // --------------------------------------------------------------
    // Read channel
    // --------------------------------------------------------------
    input  wire                         r_addr_valid_i,
    output wire [DATA_WIDTH-1:0]        r_data_o,
    input  wire [R_ADDR_BITS-1:0]       r_addr_i
);

    // ==============================================================
    // Arbiter <-> Input memory
    // ==============================================================
    wire                         input_mem_we_w;
    wire [W_ADDR_BITS-1:0]       input_mem_w_addr_w;
    wire [DATA_WIDTH-1:0]        input_mem_w_data_w;

    wire [W_ADDR_BITS-1:0]       input_mem_a_r_addr_w;
    wire [W_ADDR_BITS-1:0]       input_mem_b_r_addr_w;
    wire [W_ADDR_BITS-1:0]       input_mem_c_r_addr_w;
    wire [W_ADDR_BITS-1:0]       input_mem_d_r_addr_w;
    wire [W_ADDR_BITS-1:0]       input_mem_e_r_addr_w;
    wire [W_ADDR_BITS-1:0]       input_mem_f_r_addr_w;

    wire [DATA_WIDTH-1:0]        input_mem_a_data_w;
    wire [DATA_WIDTH-1:0]        input_mem_b_data_w;
    wire [DATA_WIDTH-1:0]        input_mem_c_data_w;
    wire [DATA_WIDTH-1:0]        input_mem_d_data_w;
    wire [DATA_WIDTH-1:0]        input_mem_e_data_w;
    wire [DATA_WIDTH-1:0]        input_mem_f_data_w;

    // ==============================================================
    // Arbiter <-> FSM & CTRL
    // ==============================================================
    wire ctrl_load_w;
    wire ctrl_start_w;
    wire ctrl_stop_w;

    wire ctrl_READ_ready_w;
    wire ctrl_compute_en_w;
    wire ctrl_output_we_w;
    wire ctrl_busy_w;

    // ==============================================================
    // Arbiter <-> Datapath
    // ==============================================================
    wire                         datapath_READ_ready_w;
    wire                         datapath_compute_en_w;

    wire [DATA_WIDTH-1:0]        datapath_a_w;
    wire [DATA_WIDTH-1:0]        datapath_b_w;
    wire [DATA_WIDTH-1:0]        datapath_c_w;
    wire [DATA_WIDTH-1:0]        datapath_d_w;
    wire [DATA_WIDTH-1:0]        datapath_e_w;
    wire [DATA_WIDTH-1:0]        datapath_f_w;

    wire [DATA_WIDTH-1:0]        datapath_h_w;

    // ==============================================================
    // Arbiter <-> Output memory
    // ==============================================================
    wire                         output_mem_we_w;
    wire [R_ADDR_BITS-1:0]       output_mem_w_addr_w;
    wire [DATA_WIDTH-1:0]        output_mem_w_data_w;

    wire                         output_mem_r_addr_valid_w;
    wire [R_ADDR_BITS-1:0]       output_mem_r_addr_w;
    wire [DATA_WIDTH-1:0]        output_mem_r_data_w;

    // ==============================================================
    // Arbiter
    // ==============================================================
    H_arbiter #(
        .DATA_WIDTH  (DATA_WIDTH),
        .W_ADDR_BITS (W_ADDR_BITS),
        .R_ADDR_BITS (R_ADDR_BITS)
    ) u_H_arbiter (
        .CLK                         (CLK),
        .RST                         (RST),

        .w_addr_valid_i              (w_addr_valid_i),
        .w_data_i                    (w_data_i),
        .w_addr_i                    (w_addr_i),

        .r_addr_valid_i              (r_addr_valid_i),
        .r_data_o                    (r_data_o),
        .r_addr_i                    (r_addr_i),

        .input_mem_we_o              (input_mem_we_w),
        .input_mem_w_addr_o          (input_mem_w_addr_w),
        .input_mem_w_data_o          (input_mem_w_data_w),

        .input_mem_a_r_addr_o        (input_mem_a_r_addr_w),
        .input_mem_b_r_addr_o        (input_mem_b_r_addr_w),
        .input_mem_c_r_addr_o        (input_mem_c_r_addr_w),
        .input_mem_d_r_addr_o        (input_mem_d_r_addr_w),
        .input_mem_e_r_addr_o        (input_mem_e_r_addr_w),
        .input_mem_f_r_addr_o        (input_mem_f_r_addr_w),

        .input_mem_a_data_i          (input_mem_a_data_w),
        .input_mem_b_data_i          (input_mem_b_data_w),
        .input_mem_c_data_i          (input_mem_c_data_w),
        .input_mem_d_data_i          (input_mem_d_data_w),
        .input_mem_e_data_i          (input_mem_e_data_w),
        .input_mem_f_data_i          (input_mem_f_data_w),

        .ctrl_load_o                 (ctrl_load_w),
        .ctrl_start_o                (ctrl_start_w),
        .ctrl_stop_o                 (ctrl_stop_w),

        .ctrl_READ_ready_i           (ctrl_READ_ready_w),
        .ctrl_compute_en_i           (ctrl_compute_en_w),
        .ctrl_output_we_i            (ctrl_output_we_w),
        .ctrl_busy_i                 (ctrl_busy_w),

        .datapath_READ_ready_o       (datapath_READ_ready_w),
        .datapath_compute_en_o       (datapath_compute_en_w),

        .datapath_a_o                (datapath_a_w),
        .datapath_b_o                (datapath_b_w),
        .datapath_c_o                (datapath_c_w),
        .datapath_d_o                (datapath_d_w),
        .datapath_e_o                (datapath_e_w),
        .datapath_f_o                (datapath_f_w),
        .datapath_h_i                (datapath_h_w),

        .output_mem_we_o             (output_mem_we_w),
        .output_mem_w_addr_o         (output_mem_w_addr_w),
        .output_mem_w_data_o         (output_mem_w_data_w),

        .output_mem_r_addr_valid_o   (output_mem_r_addr_valid_w),
        .output_mem_r_addr_o         (output_mem_r_addr_w),
        .output_mem_r_data_i         (output_mem_r_data_w)
    );

    // ==============================================================
    // Input memory
    // ==============================================================
    H_input_memory #(
        .DATA_WIDTH  (DATA_WIDTH),
        .W_ADDR_BITS (W_ADDR_BITS)
    ) u_H_input_memory (
        .CLK         (CLK),
        .RST         (RST),

        .we_i        (input_mem_we_w),
        .w_addr_i    (input_mem_w_addr_w),
        .w_data_i    (input_mem_w_data_w),

        .a_r_addr_i  (input_mem_a_r_addr_w),
        .b_r_addr_i  (input_mem_b_r_addr_w),
        .c_r_addr_i  (input_mem_c_r_addr_w),
        .d_r_addr_i  (input_mem_d_r_addr_w),
        .e_r_addr_i  (input_mem_e_r_addr_w),
        .f_r_addr_i  (input_mem_f_r_addr_w),

        .a_data_o    (input_mem_a_data_w),
        .b_data_o    (input_mem_b_data_w),
        .c_data_o    (input_mem_c_data_w),
        .d_data_o    (input_mem_d_data_w),
        .e_data_o    (input_mem_e_data_w),
        .f_data_o    (input_mem_f_data_w)
    );

    // ==============================================================
    // FSM & CTRL
    // ==============================================================
    H_ctrl u_H_ctrl (
        .CLK          (CLK),
        .RST          (RST),

        .load_i       (ctrl_load_w),
        .start_i      (ctrl_start_w),
        .stop_i       (ctrl_stop_w),

        .READ_ready_o (ctrl_READ_ready_w),
        .compute_en_o (ctrl_compute_en_w),
        .output_we_o  (ctrl_output_we_w),
        .busy_o       (ctrl_busy_w)
    );

    // ==============================================================
    // Datapath
    // ==============================================================
    H_datapath #(
        .DATA_WIDTH (DATA_WIDTH)
    ) u_H_datapath (
        .CLK          (CLK),
        .RST          (RST),

        .READ_ready_i (datapath_READ_ready_w),
        .compute_en_i (datapath_compute_en_w),

        .a_i          (datapath_a_w),
        .b_i          (datapath_b_w),
        .c_i          (datapath_c_w),
        .d_i          (datapath_d_w),
        .e_i          (datapath_e_w),
        .f_i          (datapath_f_w),

        .h_o          (datapath_h_w)
    );

    // ==============================================================
    // Output memory
    // ==============================================================
    H_output_memory #(
        .DATA_WIDTH  (DATA_WIDTH),
        .R_ADDR_BITS (R_ADDR_BITS)
    ) u_H_output_memory (
        .CLK            (CLK),
        .RST            (RST),

        .we_i           (output_mem_we_w),
        .w_addr_i       (output_mem_w_addr_w),
        .w_data_i       (output_mem_w_data_w),

        .r_addr_valid_i (output_mem_r_addr_valid_w),
        .r_addr_i       (output_mem_r_addr_w),
        .r_data_o       (output_mem_r_data_w)
    );

endmodule
