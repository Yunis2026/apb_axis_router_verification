module router_scoreboard (

    input logic        pclk,
    input logic        presetn,

    // Current router configuration
    input logic [1:0]  route_mode,

    // AXI-Stream input monitor
    input logic [31:0] s_tdata,
    input logic        s_tdest,
    input logic        s_tvalid,
    input logic        s_tready,

    // AXI-Stream output 0 monitor
    input logic [31:0] m0_tdata,
    input logic        m0_tvalid,
    input logic        m0_tready,

    // AXI-Stream output 1 monitor
    input logic [31:0] m1_tdata,
    input logic        m1_tvalid,
    input logic        m1_tready
);

    // Expected transactions waiting to be observed at an output.
    logic [31:0] expected_data_q[$];
    logic        expected_output_q[$];

    logic [31:0] expected_data;
    logic        expected_output;
    logic        actual_output;

    // Calculate expected output from route mode and input destination.
    function automatic logic get_expected_output(
        input logic [1:0] mode,
        input logic       dest
    );
        begin
            case (mode)
                2'b01:  get_expected_output = 1'b0; // Force output 0
                2'b10:  get_expected_output = 1'b1; // Force output 1
                default: get_expected_output = dest; // Route by s_tdest
            endcase
        end
    endfunction

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            expected_data_q.delete();
            expected_output_q.delete();

            $display("[SB] Reset: expected queue cleared.");
        end
        else begin
            // Input handshake:
            // Record what the router is expected to produce later.
            if (s_tvalid && s_tready) begin
                expected_data_q.push_back(s_tdata);
                expected_output_q.push_back(
                    get_expected_output(route_mode, s_tdest)
                );

                $display(
                    "[SB] Input accepted: data=0x%08h expected_output=%0d",
                    s_tdata,
                    get_expected_output(route_mode, s_tdest)
                );
            end

            // Router must never transfer to both outputs in one cycle.
            if ((m0_tvalid && m0_tready) && (m1_tvalid && m1_tready)) begin
                $fatal(1, "[SB] ERROR: both outputs transferred in one cycle.");
            end

            // Output handshake:
            // Compare actual output transaction against expected queue entry.
            if ((m0_tvalid && m0_tready) || (m1_tvalid && m1_tready)) begin

                if (expected_data_q.size() == 0) begin
                    $fatal(1,
                        "[SB] ERROR: output transfer has no expected packet.");
                end

                expected_data   = expected_data_q.pop_front();
                expected_output = expected_output_q.pop_front();
                actual_output   = (m1_tvalid && m1_tready);

                if (actual_output != expected_output) begin
                    $fatal(1,
                        "[SB] ERROR: wrong output. Expected m%0d, got m%0d.",
                        expected_output, actual_output);
                end

                if (actual_output == 1'b0 && m0_tdata != expected_data) begin
                    $fatal(1,
                        "[SB] ERROR: m0 data mismatch. Expected 0x%08h, got 0x%08h.",
                        expected_data, m0_tdata);
                end

                if (actual_output == 1'b1 && m1_tdata != expected_data) begin
                    $fatal(1,
                        "[SB] ERROR: m1 data mismatch. Expected 0x%08h, got 0x%08h.",
                        expected_data, m1_tdata);
                end

                $display(
                    "[SB] PASS: data=0x%08h transferred to m%0d",
                    expected_data, actual_output
                );
            end
        end
    end

endmodule