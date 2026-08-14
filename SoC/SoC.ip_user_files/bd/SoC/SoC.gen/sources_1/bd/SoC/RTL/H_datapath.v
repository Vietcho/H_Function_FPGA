`timescale 1ns / 1ps

module H_datapath #(
    parameter DATA_WIDTH = 32
)(
    input  wire                         CLK,
    input  wire                         RST,

    // --------------------------------------------------------------
    // Control from Arbiter
    // --------------------------------------------------------------
    input  wire                         READ_ready_i,
    input  wire                         compute_en_i,

    // --------------------------------------------------------------
    // Operand data from Arbiter
    // --------------------------------------------------------------
    input  wire [DATA_WIDTH-1:0]        a_i,
    input  wire [DATA_WIDTH-1:0]        b_i,
    input  wire [DATA_WIDTH-1:0]        c_i,
    input  wire [DATA_WIDTH-1:0]        d_i,
    input  wire [DATA_WIDTH-1:0]        e_i,
    input  wire [DATA_WIDTH-1:0]        f_i,

    // --------------------------------------------------------------
    // Result to Arbiter
    // --------------------------------------------------------------
    output wire [DATA_WIDTH-1:0]        h_o
);

    reg [DATA_WIDTH-1:0] a_r;
    reg [DATA_WIDTH-1:0] b_r;
    reg [DATA_WIDTH-1:0] c_r;
    reg [DATA_WIDTH-1:0] d_r;
    reg [DATA_WIDTH-1:0] e_r;
    reg [DATA_WIDTH-1:0] f_r;

    wire [DATA_WIDTH-1:0] sum_ab_w;
    wire [DATA_WIDTH-1:0] sum_abc_w;
    wire [DATA_WIDTH-1:0] xor_w;
    wire [DATA_WIDTH-1:0] sub_w;
    wire [DATA_WIDTH-1:0] result_w;

    reg [DATA_WIDTH-1:0] h_r;

    assign sum_ab_w  = a_r + b_r;
    assign sum_abc_w = sum_ab_w + c_r;
    assign xor_w     = sum_abc_w ^ d_r;
    assign sub_w     = xor_w - e_r;
    assign result_w  = sub_w | f_r;

    // ==============================================================
    // READ stage
    // ==============================================================
    always @(posedge CLK) begin
        if (!RST) begin
            a_r <= {DATA_WIDTH{1'b0}};
            b_r <= {DATA_WIDTH{1'b0}};
            c_r <= {DATA_WIDTH{1'b0}};
            d_r <= {DATA_WIDTH{1'b0}};
            e_r <= {DATA_WIDTH{1'b0}};
            f_r <= {DATA_WIDTH{1'b0}};
        end
        else begin
            if (READ_ready_i) begin
                a_r <= a_i;
                b_r <= b_i;
                c_r <= c_i;
                d_r <= d_i;
                e_r <= e_i;
                f_r <= f_i;
            end
        end
    end

    // ==============================================================
    // COMPUTE stage
    // ==============================================================
    always @(posedge CLK or negedge RST) begin
        if (!RST) begin
            h_r <= {DATA_WIDTH{1'b0}};
        end
        else begin
            if (compute_en_i) begin
                h_r <= result_w;
            end
        end
    end

    assign h_o = h_r;

endmodule
