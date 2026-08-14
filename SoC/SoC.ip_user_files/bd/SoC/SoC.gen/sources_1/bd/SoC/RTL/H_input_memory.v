`timescale 1ns / 1ps

module H_input_memory #(
    parameter DATA_WIDTH  = 32,
    parameter W_ADDR_BITS = 4
)(
    input  wire                         CLK,
    input  wire                         RST,

    // --------------------------------------------------------------
    // Write port from Arbiter
    // --------------------------------------------------------------
    input  wire                         we_i,
    input  wire [W_ADDR_BITS-1:0]       w_addr_i,
    input  wire [DATA_WIDTH-1:0]        w_data_i,

    // --------------------------------------------------------------
    // Read addresses from Arbiter
    // --------------------------------------------------------------
    input  wire [W_ADDR_BITS-1:0]       a_r_addr_i,
    input  wire [W_ADDR_BITS-1:0]       b_r_addr_i,
    input  wire [W_ADDR_BITS-1:0]       c_r_addr_i,
    input  wire [W_ADDR_BITS-1:0]       d_r_addr_i,
    input  wire [W_ADDR_BITS-1:0]       e_r_addr_i,
    input  wire [W_ADDR_BITS-1:0]       f_r_addr_i,

    // --------------------------------------------------------------
    // Read data to Arbiter
    // --------------------------------------------------------------
    output wire [DATA_WIDTH-1:0]        a_data_o,
    output wire [DATA_WIDTH-1:0]        b_data_o,
    output wire [DATA_WIDTH-1:0]        c_data_o,
    output wire [DATA_WIDTH-1:0]        d_data_o,
    output wire [DATA_WIDTH-1:0]        e_data_o,
    output wire [DATA_WIDTH-1:0]        f_data_o
);

    localparam integer MEM_DEPTH = 6;

    localparam [W_ADDR_BITS-1:0] A_BASE_ADDR = 0;
    localparam [W_ADDR_BITS-1:0] B_BASE_ADDR = 1;
    localparam [W_ADDR_BITS-1:0] C_BASE_ADDR = 2;
    localparam [W_ADDR_BITS-1:0] D_BASE_ADDR = 3;
    localparam [W_ADDR_BITS-1:0] E_BASE_ADDR = 4;
    localparam [W_ADDR_BITS-1:0] F_BASE_ADDR = 5;

    reg [DATA_WIDTH-1:0] mem_r [0:MEM_DEPTH-1];

    integer i;

    // ==============================================================
    // Write logic
    // ==============================================================
    always @(posedge CLK or negedge RST) begin
        if (!RST) begin
            for (i = 0; i < MEM_DEPTH; i = i + 1) begin
                mem_r[i] <= {DATA_WIDTH{1'b0}};
            end
        end
        else begin
            if (we_i &&
                (w_addr_i >= A_BASE_ADDR) &&
                (w_addr_i <= F_BASE_ADDR)) begin

                mem_r[w_addr_i] <= w_data_i;
            end
        end
    end

    // ==============================================================
    // Combinational read ports
    // ==============================================================
    assign a_data_o = mem_r[a_r_addr_i];
    assign b_data_o = mem_r[b_r_addr_i];
    assign c_data_o = mem_r[c_r_addr_i];
    assign d_data_o = mem_r[d_r_addr_i];
    assign e_data_o = mem_r[e_r_addr_i];
    assign f_data_o = mem_r[f_r_addr_i];

endmodule
