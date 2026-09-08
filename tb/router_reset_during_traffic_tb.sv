`timescale 1ns/1ps

module router_reset_during_traffic_tb;

    logic        pclk;
    logic        presetn;

    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [7:0]  paddr;
    logic [31:0] pwdata;
    logic [31:0] prdata;
    logic        pready;
    logic        pslverr;

    logic [31:0] s_tdata;
    logic        s_tdest;
    logic        s_tvalid;
    logic        s_tready;

    logic [31:0] m0_tdata;
    logic        m0_tvalid;
    logic        m0_tready;

    logic [31:0] m1_tdata;
    logic        m1_tvalid;
    logic        m1_tready;

    apb_axis_router dut (
        .pclk      (pclk),
        .presetn   (presetn),
        .psel      (psel),
        .penable   (penable),
        .pwrite    (pwrite),
        .paddr     (paddr),
        .pwdata    (pwdata),
        .prdata    (prdata),
        .pready    (pready),
        .pslverr   (pslverr),

        .s_tdata   (s_tdata),
        .s_tdest   (s_tdest),
        .s_tvalid  (s_tvalid),
        .s_tready  (s_tready),

        .m0_tdata  (m0_tdata),
        .m0_tvalid (m0_tvalid),
        .m0_tready (m0_tready),

        .m1_tdata  (m1_tdata),
        .m1_tvalid (m1_tvalid),
        .m1_tready (m1_tready)
    );

    initial pclk = 1'b0;
    always #5 pclk = ~pclk;

    task automatic apb_write(
        input logic [7:0]  addr,
        input logic [31:0] data
    );
        begin
            @(negedge pclk);
            psel    = 1'b1;
            penable = 1'b0;
            pwrite  = 1'b1;
            paddr   = addr;
            pwdata  = data;

            @(negedge pclk);
            penable = 1'b1;

            @(negedge pclk);
            psel    = 1'b0;
            penable = 1'b0;
            pwrite  = 1'b0;
            paddr   = '0;
            pwdata  = '0;
        end
    endtask

    task automatic send_recovery_packet;
        begin
            @(negedge pclk);
            s_tdata  = 32'hFACE_0001;
            s_tdest  = 1'b0;
            s_tvalid = 1'b1;

            #1;

            if (!m0_tvalid || !s_tready) begin
                $fatal(1, "FAIL: router did not recover after reset.");
            end

            @(posedge pclk);
            #1;

            if (dut.packet_count_q != 32'd1) begin
                $fatal(1, "FAIL: counter should equal 1 after recovery packet.");
            end

            @(negedge pclk);
            s_tvalid = 1'b0;
            s_tdata  = '0;
        end
    endtask

    initial begin
        presetn   = 1'b0;

        psel      = 1'b0;
        penable   = 1'b0;
        pwrite    = 1'b0;
        paddr     = '0;
        pwdata    = '0;

        s_tdata   = '0;
        s_tdest   = 1'b0;
        s_tvalid  = 1'b0;

        m0_tready = 1'b1;
        m1_tready = 1'b1;

        $dumpfile("router_reset_during_traffic.vcd");
        $dumpvars(0, router_reset_during_traffic_tb);

        // 1. Initial reset
        #20;
        presetn = 1'b1;

        // 2. Enable router
        apb_write(8'h00, 32'h0000_0001);

        // 3. Block output 0, then present one packet for output 0
        m0_tready = 1'b0;

        @(negedge pclk);
        s_tdata  = 32'hDEAD_0001;
        s_tdest  = 1'b0;
        s_tvalid = 1'b1;

        #1;

        if (!m0_tvalid || s_tready) begin
            $fatal(1, "FAIL: packet should be pending under backpressure.");
        end

        // 4. Assert reset while the packet is still pending.
        // This is intentionally not aligned to a clock edge.
        #2;
        presetn = 1'b0;

        #1;

        // 5. Reset must clear router state immediately.
        if (dut.enable_q != 1'b0) begin
            $fatal(1, "FAIL: enable_q was not cleared by reset.");
        end

        if (dut.packet_count_q != 32'd0) begin
            $fatal(1, "FAIL: packet counter was not cleared by reset.");
        end

        if (m0_tvalid != 1'b0 || m1_tvalid != 1'b0) begin
            $fatal(1, "FAIL: router must stop all outputs during reset.");
        end

        if (s_tready != 1'b0) begin
            $fatal(1, "FAIL: router must not accept input during reset.");
        end

        // 6. Release reset and remove the old pending packet.
        @(negedge pclk);
        presetn   = 1'b1;
        s_tvalid  = 1'b0;
        s_tdata   = '0;
        m0_tready = 1'b1;

        // 7. Re-enable router and verify it can work again.
        apb_write(8'h00, 32'h0000_0001);
        send_recovery_packet();

        $display("PASS: reset-during-traffic test completed successfully.");
        #20;
        $finish;
    end

endmodule