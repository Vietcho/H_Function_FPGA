`timescale 1ns / 1ps

module H_ctrl (
    input  wire CLK,
    input  wire RST,

    // --------------------------------------------------------------
    // Commands from Arbiter
    // --------------------------------------------------------------
    input  wire load_i,
    input  wire start_i,
    input  wire stop_i,

    // --------------------------------------------------------------
    // Status / control outputs to Arbiter
    // --------------------------------------------------------------
    output wire READ_ready_o,
    output wire compute_en_o,
    output wire output_we_o,
    output wire busy_o
);

    // ==============================================================
    // FSM state encoding
    // ==============================================================
    localparam [2:0] IDLE_STATE    = 3'b000;
    localparam [2:0] LOAD_STATE    = 3'b001;
    localparam [2:0] READ_STATE    = 3'b010;
    localparam [2:0] COMPUTE_STATE = 3'b011;
    localparam [2:0] WRITE_STATE   = 3'b100;

    reg [2:0] state_r;
    reg [2:0] next_state_r;

    reg READ_ready_r;

    // ==============================================================
    // State register
    // ==============================================================
    always @(posedge CLK or negedge RST) begin
        if (!RST) begin
            state_r <= IDLE_STATE;
        end
        else begin
            state_r <= next_state_r;
        end
    end

    // ==============================================================
    // Next-state logic
    // ==============================================================
    always @(*) begin
        next_state_r = state_r;

        // STOP has highest priority.
        if (stop_i) begin
            next_state_r = IDLE_STATE;
        end
        else begin
            case (state_r)

                IDLE_STATE: begin
                    if (load_i) begin
                        next_state_r = LOAD_STATE;
                    end
                    else if (start_i) begin
                        next_state_r = READ_STATE;
                    end
                end

                LOAD_STATE: begin
                    if (start_i) begin
                        next_state_r = READ_STATE;
                    end
                end

                READ_STATE: begin
                    next_state_r = COMPUTE_STATE;
                end

                COMPUTE_STATE: begin
                    next_state_r = WRITE_STATE;
                end

                WRITE_STATE: begin
                    next_state_r = IDLE_STATE;
                end

                default: begin
                    next_state_r = IDLE_STATE;
                end

            endcase
        end
    end

    // ==============================================================
    // READ_ready generation
    // ==============================================================
    always @(*) begin
        if (state_r == READ_STATE) begin
            READ_ready_r = 1'b1;
        end
        else begin
            READ_ready_r = 1'b0;
        end
    end

    assign READ_ready_o = READ_ready_r;

    // ==============================================================
    // Other FSM outputs
    // ==============================================================
    assign compute_en_o = (state_r == COMPUTE_STATE);
    assign output_we_o  = (state_r == WRITE_STATE);

    // Input data may be written in IDLE_STATE and LOAD_STATE.
    assign busy_o =
        (state_r == READ_STATE)    ||
        (state_r == COMPUTE_STATE) ||
        (state_r == WRITE_STATE);

endmodule
