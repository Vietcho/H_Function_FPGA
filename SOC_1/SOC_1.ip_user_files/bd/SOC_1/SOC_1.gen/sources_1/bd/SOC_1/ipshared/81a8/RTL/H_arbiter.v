`timescale 1ns / 1ps

module H_arbiter #(
    parameter DATA_WIDTH  = 32,
    parameter W_ADDR_BITS = 4,
    parameter R_ADDR_BITS = 1
)(
    input  wire                         CLK,
    input  wire                         RST,

    // --------------------------------------------------------------
    // Core-side write channel
    // --------------------------------------------------------------
    input  wire                         w_addr_valid_i,
    input  wire [DATA_WIDTH-1:0]        w_data_i,
    input  wire [W_ADDR_BITS-1:0]       w_addr_i,

    // --------------------------------------------------------------
    // Core-side read channel
    // --------------------------------------------------------------
    input  wire                         r_addr_valid_i,
    output reg  [DATA_WIDTH-1:0]        r_data_o,
    input  wire [R_ADDR_BITS-1:0]       r_addr_i,

    // --------------------------------------------------------------
    // Arbiter <-> Input memory
    // --------------------------------------------------------------
    output wire                         input_mem_we_o,
    output wire [W_ADDR_BITS-1:0]       input_mem_w_addr_o,
    output wire [DATA_WIDTH-1:0]        input_mem_w_data_o,

    output wire [W_ADDR_BITS-1:0]       input_mem_a_r_addr_o,
    output wire [W_ADDR_BITS-1:0]       input_mem_b_r_addr_o,
    output wire [W_ADDR_BITS-1:0]       input_mem_c_r_addr_o,
    output wire [W_ADDR_BITS-1:0]       input_mem_d_r_addr_o,
    output wire [W_ADDR_BITS-1:0]       input_mem_e_r_addr_o,
    output wire [W_ADDR_BITS-1:0]       input_mem_f_r_addr_o,

    input  wire [DATA_WIDTH-1:0]        input_mem_a_data_i,
    input  wire [DATA_WIDTH-1:0]        input_mem_b_data_i,
    input  wire [DATA_WIDTH-1:0]        input_mem_c_data_i,
    input  wire [DATA_WIDTH-1:0]        input_mem_d_data_i,
    input  wire [DATA_WIDTH-1:0]        input_mem_e_data_i,
    input  wire [DATA_WIDTH-1:0]        input_mem_f_data_i,

    // --------------------------------------------------------------
    // Arbiter <-> FSM & CTRL
    // --------------------------------------------------------------
    output wire                         ctrl_load_o,
    output wire                         ctrl_start_o,
    output wire                         ctrl_stop_o,

    input  wire                         ctrl_READ_ready_i,
    input  wire                         ctrl_compute_en_i,
    input  wire                         ctrl_output_we_i,
    input  wire                         ctrl_busy_i,

    // --------------------------------------------------------------
    // Arbiter <-> Datapath
    // --------------------------------------------------------------
    output wire                         datapath_READ_ready_o,
    output wire                         datapath_compute_en_o,

    output wire [DATA_WIDTH-1:0]        datapath_a_o,
    output wire [DATA_WIDTH-1:0]        datapath_b_o,
    output wire [DATA_WIDTH-1:0]        datapath_c_o,
    output wire [DATA_WIDTH-1:0]        datapath_d_o,
    output wire [DATA_WIDTH-1:0]        datapath_e_o,
    output wire [DATA_WIDTH-1:0]        datapath_f_o,

    input  wire [DATA_WIDTH-1:0]        datapath_h_i,

    // --------------------------------------------------------------
    // Arbiter <-> Output memory
    // --------------------------------------------------------------
    output wire                         output_mem_we_o,
    output wire [R_ADDR_BITS-1:0]       output_mem_w_addr_o,
    output wire [DATA_WIDTH-1:0]        output_mem_w_data_o,

    output wire                         output_mem_r_addr_valid_o,
    output wire [R_ADDR_BITS-1:0]       output_mem_r_addr_o,
    input  wire [DATA_WIDTH-1:0]        output_mem_r_data_i
);

    // ==============================================================
    // Write address map
    // ==============================================================
    localparam [W_ADDR_BITS-1:0] A_BASE_ADDR     = 0;
    localparam [W_ADDR_BITS-1:0] B_BASE_ADDR     = 1;
    localparam [W_ADDR_BITS-1:0] C_BASE_ADDR     = 2;
    localparam [W_ADDR_BITS-1:0] D_BASE_ADDR     = 3;
    localparam [W_ADDR_BITS-1:0] E_BASE_ADDR     = 4;
    localparam [W_ADDR_BITS-1:0] F_BASE_ADDR     = 5;

    localparam [W_ADDR_BITS-1:0] LOAD_BASE_ADDR  = 6;
    localparam [W_ADDR_BITS-1:0] START_BASE_ADDR = 7;
    localparam [W_ADDR_BITS-1:0] STOP_BASE_ADDR  = 8;

    // ==============================================================
    // Read address map
    // ==============================================================
    localparam [R_ADDR_BITS-1:0] H_BASE_ADDR          = 0;
    localparam [R_ADDR_BITS-1:0] READ_READY_BASE_ADDR = 1;

    // ==============================================================
    // Internal write-decode wires
    // ==============================================================
    wire input_addr_hit_w;
    wire load_addr_hit_w;
    wire start_addr_hit_w;
    wire stop_addr_hit_w;

    wire core_input_write_accept_w;

    // ==============================================================
    // Registered read request
    // ==============================================================
    // The read address and read-valid request are registered first.
    // r_data_o is then updated on the following clock edge.
    reg [R_ADDR_BITS-1:0] r_addr_r;
    reg                   r_addr_valid_r;

    // READ_READY is a one-cycle status pulse. Capture its value in the
    // same cycle in which the external read request is accepted.
    reg READ_ready_sample_r;

    wire h_addr_hit_w;
    wire read_ready_addr_hit_w;

    // ==============================================================
    // Write-address decode
    // ==============================================================
    assign input_addr_hit_w =
        (w_addr_i >= A_BASE_ADDR) &&
        (w_addr_i <= F_BASE_ADDR);

    assign load_addr_hit_w =
        (w_addr_i == LOAD_BASE_ADDR);

    assign start_addr_hit_w =
        (w_addr_i == START_BASE_ADDR);

    assign stop_addr_hit_w =
        (w_addr_i == STOP_BASE_ADDR);

    // ==============================================================
    // Controller commands
    // ==============================================================
    assign ctrl_load_o =
        w_addr_valid_i &&
        load_addr_hit_w;

    assign ctrl_start_o =
        w_addr_valid_i &&
        start_addr_hit_w;

    assign ctrl_stop_o =
        w_addr_valid_i &&
        stop_addr_hit_w;

    // ==============================================================
    // Core -> Input memory
    // ==============================================================
    assign core_input_write_accept_w =
        w_addr_valid_i &&
        input_addr_hit_w &&
        !ctrl_busy_i;

    assign input_mem_we_o =
        core_input_write_accept_w;

    assign input_mem_w_addr_o =
        w_addr_i;

    assign input_mem_w_data_o =
        w_data_i;

    // ==============================================================
    // Fixed input-memory read addresses
    // ==============================================================
    assign input_mem_a_r_addr_o = A_BASE_ADDR;
    assign input_mem_b_r_addr_o = B_BASE_ADDR;
    assign input_mem_c_r_addr_o = C_BASE_ADDR;
    assign input_mem_d_r_addr_o = D_BASE_ADDR;
    assign input_mem_e_r_addr_o = E_BASE_ADDR;
    assign input_mem_f_r_addr_o = F_BASE_ADDR;

    // ==============================================================
    // Input memory -> Arbiter -> Datapath
    // ==============================================================
    assign datapath_a_o = input_mem_a_data_i;
    assign datapath_b_o = input_mem_b_data_i;
    assign datapath_c_o = input_mem_c_data_i;
    assign datapath_d_o = input_mem_d_data_i;
    assign datapath_e_o = input_mem_e_data_i;
    assign datapath_f_o = input_mem_f_data_i;

    assign datapath_READ_ready_o =
        ctrl_READ_ready_i &&
        !ctrl_stop_o;

    assign datapath_compute_en_o =
        ctrl_compute_en_i &&
        !ctrl_stop_o;

    // ==============================================================
    // Datapath -> Arbiter -> Output memory
    // ==============================================================
    assign output_mem_we_o =
        ctrl_output_we_i &&
        !ctrl_stop_o;

    assign output_mem_w_addr_o =
        H_BASE_ADDR;

    assign output_mem_w_data_o =
        datapath_h_i;

    // ==============================================================
    // Register external read request
    // ==============================================================
    always @(posedge CLK or negedge RST) begin
        if (!RST) begin
            r_addr_r           <= {R_ADDR_BITS{1'b0}};
            r_addr_valid_r     <= 1'b0;
            READ_ready_sample_r <= 1'b0;
        end
        else begin
            r_addr_valid_r <= r_addr_valid_i;

            if (r_addr_valid_i) begin
                r_addr_r <= r_addr_i;

                if (r_addr_i == READ_READY_BASE_ADDR) begin
                    READ_ready_sample_r <= ctrl_READ_ready_i;
                end
                else begin
                    READ_ready_sample_r <= 1'b0;
                end
            end
        end
    end

    // ==============================================================
    // Decode REGISTERED read address
    // ==============================================================
    assign h_addr_hit_w =
        (r_addr_r == H_BASE_ADDR);

    assign read_ready_addr_hit_w =
        (r_addr_r == READ_READY_BASE_ADDR);

    // ==============================================================
    // Registered request -> Output memory
    // ==============================================================
    // The output memory sees the registered address phase.
    assign output_mem_r_addr_valid_o =
        r_addr_valid_r &&
        h_addr_hit_w;

    assign output_mem_r_addr_o =
        H_BASE_ADDR;

    // ==============================================================
    // One-cycle delayed r_data_o
    // ==============================================================
    //
    // If the core presents a valid read request before edge N:
    //
    //   edge N:
    //      r_addr_i / r_addr_valid_i are captured into
    //      r_addr_r / r_addr_valid_r.
    //
    //   edge N+1:
    //      r_data_o is updated using the registered request.
    //
    // Therefore r_data_o has one full CLK cycle of latency from the
    // accepted r_addr_valid_i request.
    always @(posedge CLK or negedge RST) begin
        if (!RST) begin
            r_data_o <= {DATA_WIDTH{1'b0}};
        end
        else begin
            if (r_addr_valid_r) begin
                if (h_addr_hit_w) begin
                    r_data_o <= output_mem_r_data_i;
                end
                else if (read_ready_addr_hit_w) begin
                    r_data_o <=
                        {{(DATA_WIDTH-1){1'b0}}, READ_ready_sample_r};
                end
                else begin
                    r_data_o <= {DATA_WIDTH{1'b0}};
                end
            end
        end
    end

endmodule
