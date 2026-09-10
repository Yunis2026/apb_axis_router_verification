module router_coverage_collector (

    input logic        pclk,
    input logic        presetn,

    input logic        enable_q,
    input logic [1:0]  route_mode_q,

    input logic        s_tdest,
    input logic        s_tvalid,
    input logic        s_tready,

    input logic        m0_tvalid,
    input logic        m0_tready,

    input logic        m1_tvalid,
    input logic        m1_tready,

    input logic        pslverr
);

    // Enable-state coverage
    logic hit_enable_0;
    logic hit_enable_1;

    // Route-mode coverage
    logic hit_mode_default;
    logic hit_mode_force_m0;
    logic hit_mode_force_m1;

    // Destination coverage
    logic hit_dest_0;
    logic hit_dest_1;

    // Output-transfer coverage
    logic hit_output_m0;
    logic hit_output_m1;

    // Error and flow-control coverage
    logic hit_backpressure;
    logic hit_illegal_apb;

    initial begin
        hit_enable_0      = 1'b0;
        hit_enable_1      = 1'b0;

        hit_mode_default  = 1'b0;
        hit_mode_force_m0 = 1'b0;
        hit_mode_force_m1 = 1'b0;

        hit_dest_0        = 1'b0;
        hit_dest_1        = 1'b0;

        hit_output_m0     = 1'b0;
        hit_output_m1     = 1'b0;

        hit_backpressure  = 1'b0;
        hit_illegal_apb   = 1'b0;
    end

    always @(posedge pclk) begin
        if (presetn) begin

            // Observe enabled and disabled states.
            if (enable_q)
                hit_enable_1 <= 1'b1;
            else
                hit_enable_0 <= 1'b1;

            // Observe invalid APB accesses.
            if (pslverr)
                hit_illegal_apb <= 1'b1;

            // Input packet accepted: collect route mode and destination.
            if (s_tvalid && s_tready) begin
                case (route_mode_q)
                    2'b00:  hit_mode_default  <= 1'b1;
                    2'b01:  hit_mode_force_m0 <= 1'b1;
                    2'b10:  hit_mode_force_m1 <= 1'b1;
                    default: begin
                        // Reserved mode 11 is not a required coverage bin.
                    end
                endcase

                if (s_tdest)
                    hit_dest_1 <= 1'b1;
                else
                    hit_dest_0 <= 1'b1;
            end

            // Observe downstream backpressure.
            if (enable_q && s_tvalid && !s_tready)
                hit_backpressure <= 1'b1;

            // Observe completed output transfers.
            if (m0_tvalid && m0_tready)
                hit_output_m0 <= 1'b1;

            if (m1_tvalid && m1_tready)
                hit_output_m1 <= 1'b1;
        end
    end

    task automatic report_coverage;
        integer hit_count;
        integer total_count;
        begin
            total_count = 10;

            hit_count =
                hit_enable_0 +
                hit_enable_1 +
                hit_mode_default +
                hit_mode_force_m0 +
                hit_mode_force_m1 +
                hit_dest_0 +
                hit_dest_1 +
                hit_output_m0 +
                hit_output_m1 +
                hit_backpressure;

            $display("");
            $display("========================================");
            $display("       FUNCTIONAL COVERAGE REPORT");
            $display("========================================");

            $display("Enable disabled (0)       : %s",
                hit_enable_0 ? "HIT" : "MISS");
            $display("Enable enabled  (1)       : %s",
                hit_enable_1 ? "HIT" : "MISS");

            $display("Route mode default (00)   : %s",
                hit_mode_default ? "HIT" : "MISS");
            $display("Route mode force m0 (01)  : %s",
                hit_mode_force_m0 ? "HIT" : "MISS");
            $display("Route mode force m1 (10)  : %s",
                hit_mode_force_m1 ? "HIT" : "MISS");

            $display("Destination 0             : %s",
                hit_dest_0 ? "HIT" : "MISS");
            $display("Destination 1             : %s",
                hit_dest_1 ? "HIT" : "MISS");

            $display("Output m0 transfer        : %s",
                hit_output_m0 ? "HIT" : "MISS");
            $display("Output m1 transfer        : %s",
                hit_output_m1 ? "HIT" : "MISS");

            $display("Backpressure              : %s",
                hit_backpressure ? "HIT" : "MISS");
            $display("Illegal APB access        : %s",
                hit_illegal_apb ? "HIT" : "MISS");

            $display("----------------------------------------");
            $display("Required-bin coverage     : %0d / %0d",
                hit_count, total_count);
            $display("========================================");
            $display("");
        end
    endtask

endmodule