module router_sva (

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

    // 1. Router disabled: input must not be accepted.
    property p_disabled_router_not_ready;
        @(posedge pclk) disable iff (!presetn)
        !enable_q |-> !s_tready;
    endproperty

    assert property (p_disabled_router_not_ready)
        else $error("[SVA] ERROR: router is disabled but s_tready is high.");

    // 2. If m0 has valid data but m0 is not ready,
    //    valid and data must remain stable in the next cycle.
    property p_m0_data_stable_under_backpressure;
        @(posedge pclk) disable iff (!presetn)
        (m0_tvalid && !m0_tready) |=> (m0_tvalid && $stable(m0_tdata));
    endproperty

    assert property (p_m0_data_stable_under_backpressure)
        else $error("[SVA] ERROR: m0 data changed during backpressure.");

    // 3. Same stability rule for m1.
    property p_m1_data_stable_under_backpressure;
        @(posedge pclk) disable iff (!presetn)
        (m1_tvalid && !m1_tready) |=> (m1_tvalid && $stable(m1_tdata));
    endproperty

    assert property (p_m1_data_stable_under_backpressure)
        else $error("[SVA] ERROR: m1 data changed during backpressure.");

    // 4. Router must never transfer to both outputs in one cycle.
    property p_not_two_outputs_same_cycle;
        @(posedge pclk) disable iff (!presetn)
        !((m0_tvalid && m0_tready) && (m1_tvalid && m1_tready));
    endproperty

    assert property (p_not_two_outputs_same_cycle)
        else $error("[SVA] ERROR: m0 and m1 transferred simultaneously.");

endmodule