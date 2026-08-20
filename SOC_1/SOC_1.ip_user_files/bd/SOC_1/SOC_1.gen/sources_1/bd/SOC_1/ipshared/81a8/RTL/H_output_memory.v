`timescale 1ns / 1ps

module H_output_memory #(
    parameter DATA_WIDTH  = 32,
    parameter R_ADDR_BITS = 1
)(
    input  wire                         CLK,
    input  wire                         RST,

    // --------------------------------------------------------------
    // Write channel from Arbiter
    // --------------------------------------------------------------
    input  wire                         we_i,
    input  wire [R_ADDR_BITS-1:0]       w_addr_i,
    input  wire [DATA_WIDTH-1:0]        w_data_i,

    // --------------------------------------------------------------
    // Read channel from Arbiter
    // --------------------------------------------------------------
    input  wire                         r_addr_valid_i,
    input  wire [R_ADDR_BITS-1:0]       r_addr_i,
    output wire [DATA_WIDTH-1:0]        r_data_o
);

    localparam [R_ADDR_BITS-1:0] H_BASE_ADDR = 0;

    reg [DATA_WIDTH-1:0] h_mem_r;

    // ==============================================================
    // Result storage
    // ==============================================================
    always @(posedge CLK or negedge RST) begin
        if (!RST) begin
            h_mem_r <= {DATA_WIDTH{1'b0}};
        end
        else begin
            if (we_i && (w_addr_i == H_BASE_ADDR)) begin
                h_mem_r <= w_data_i;
            end
        end
    end

    // Combinational memory read. The Arbiter provides the registered
    // read address and registers r_data_o on the following clock edge.
    assign r_data_o =
        (r_addr_valid_i && (r_addr_i == H_BASE_ADDR)) ?
        h_mem_r :
        {DATA_WIDTH{1'b0}};

endmodule
