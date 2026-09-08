`timescale 1ns/1ps

module router_smoke_tb;

    // Clock and reset
    logic        pclk;
    logic        presetn;

    // APB signals
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [7:0]  paddr;
    logic [31:0] pwdata;
    logic [31:0] prdata;
    logic        pready;
    logic        pslverr;

    // AXI-Stream input
    logic [31:0] s_tdata;
    logic        s_tdest;
    logic        s_tvalid;
    logic        s_tready;

    // AXI-Stream output 0
    logic [31:0] m0_tdata;
    logic        m0_tvalid;
    logic        m0_tready;

    // AXI-Stream output 1
    logic [31:0] m1_tdata;
    logic        m1_tvalid;
    logic        m1_tready;

    // DUT instance
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

    // 100 MHz clock
    initial pclk = 1'b0;
    always #5 pclk = ~pclk;

    // APB write task
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

    // Send one packet and check its destination
    task automatic send_packet(
        input logic [31:0] data,
        input logic        dest
    );
        begin
            @(negedge pclk);
            s_tdata  = data;
            s_tdest  = dest;
            s_tvalid = 1'b1;

            #1;

            if (dest == 1'b0) begin
                if (!m0_tvalid || m0_tdata != data) begin
                    $fatal(1, "FAIL: packet should be routed to output 0");
                end
            end
            else begin
                if (!m1_tvalid || m1_tdata != data) begin
                    $fatal(1, "FAIL: packet should be routed to output 1");
                end
            end

            // Wait until valid-ready handshake completes
            while (!s_tready) begin
                @(posedge pclk);
            end

            @(negedge pclk);
            s_tvalid = 1'b0;
            s_tdata  = '0;
            s_tdest  = 1'b0;
        end
    endtask

    initial begin
        // Default values
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

        $dumpfile("router_smoke.vcd");
        $dumpvars(0, router_smoke_tb);

        // Reset
        #20;
        presetn = 1'b1;

        // APB write: CTRL register
        // bit[0] = enable = 1
        // bit[2:1] = route_mode = 00, route by s_tdest
        apb_write(8'h00, 32'h0000_0001);

        // Send one packet to each output
        send_packet(32'h1234_ABCD, 1'b0);
        send_packet(32'hDEAD_BEEF, 1'b1);

        // Expected count: 2 successful handshakes
        #10;
        if (dut.packet_count_q != 32'd2) begin
            $fatal(1, "FAIL: packet counter should equal 2, actual = %0d",
                   dut.packet_count_q);
        end

        $display("PASS: router smoke test completed successfully.");
        #20;
        $finish;
    end

endmodule