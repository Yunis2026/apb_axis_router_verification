module router_assertion_checker (

    input logic        pclk,
    input logic        presetn,

    input logic        enable_q,

    input logic [31:0] s_tdata,
    input logic        s_tdest,
    input logic        s_tvalid,
    input logic        s_tready,

    input logic [31:0] m0_tdata,
    input logic        m0_tvalid,
    input logic        m0_tready,

    input logic [31:0] m1_tdata,
    input logic        m1_tvalid,
    input logic        m1_tready
);

    logic        prev_m0_blocked;
    logic [31:0] prev_m0_tdata;

    logic        prev_m1_blocked;
    logic [31:0] prev_m1_tdata;

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            prev_m0_blocked <= 1'b0;
            prev_m0_tdata   <= '0;

            prev_m1_blocked <= 1'b0;
            prev_m1_tdata   <= '0;
        end
        else begin
            // Rule 1: disabled router must not accept input traffic.
            if (!enable_q && s_tready) begin
                $error(
                    "[ASSERT] ERROR: router disabled but s_tready is high."
                );
            end

            // Rule 2: m0 data must stay stable while backpressured.
            if (prev_m0_blocked) begin
                if (!m0_tvalid) begin
                    $error(
                        "[ASSERT] ERROR: m0_tvalid dropped during backpressure."
                    );
                end

                if (m0_tdata != prev_m0_tdata) begin
                    $error(
                        "[ASSERT] ERROR: m0_tdata changed during backpressure."
                    );
                end
            end

            // Rule 3: m1 data must stay stable while backpressured.
            if (prev_m1_blocked) begin
                if (!m1_tvalid) begin
                    $error(
                        "[ASSERT] ERROR: m1_tvalid dropped during backpressure."
                    );
                end

                if (m1_tdata != prev_m1_tdata) begin
                    $error(
                        "[ASSERT] ERROR: m1_tdata changed during backpressure."
                    );
                end
            end

            // Rule 4: both outputs cannot transfer in one cycle.
            if ((m0_tvalid && m0_tready) &&
                (m1_tvalid && m1_tready)) begin
                $error(
                    "[ASSERT] ERROR: m0 and m1 transferred simultaneously."
                );
            end

            // Save current backpressure state for next clock cycle.
            prev_m0_blocked <= m0_tvalid && !m0_tready;
            prev_m0_tdata   <= m0_tdata;

            prev_m1_blocked <= m1_tvalid && !m1_tready;
            prev_m1_tdata   <= m1_tdata;
        end
    end

endmodule