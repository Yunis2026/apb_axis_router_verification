`timescale 1ns/1ps

module router_coverage_tb;

    logic        pclk;
    logic        presetn;

    // APB interface
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

    // AXI-Stream output m0
    logic [31:0] m0_tdata;
    logic        m0_tvalid;
    logic        m0_tready;

    // AXI-Stream output m1
    logic [31:0] m1_tdata;
    logic        m1_tvalid;
    logic        m1_tready;

    // Internal DUT signals observed by coverage collector
    logic        enable_q;
    logic [1:0]  route_mode_q;

    // 10 ns clock period
    always #5 pclk = ~pclk;

    // DUT
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

    // Observe internal configuration registers.
    assign enable_q     = dut.enable_q;
    assign route_mode_q = dut.route_mode_q;

    // Functional coverage collector
    router_coverage_collector coverage (
        .pclk         (pclk),
        .presetn      (presetn),

        .enable_q     (enable_q),
        .route_mode_q (route_mode_q),

        .s_tdest      (s_tdest),
        .s_tvalid     (s_tvalid),
        .s_tready     (s_tready),

        .m0_tvalid    (m0_tvalid),
        .m0_tready    (m0_tready),

        .m1_tvalid    (m1_tvalid),
        .m1_tready    (m1_tready),

        .pslverr      (pslverr)
    );

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

    // Send one AXI-Stream packet
    task automatic send_packet(
        input logic [31:0] data,
        input logic        dest
    );
        begin
            @(negedge pclk);
            s_tdata  = data;
            s_tdest  = dest;
            s_tvalid = 1'b1;

            wait (s_tready == 1'b1);

            @(negedge pclk);
            s_tdata  = '0;
            s_tdest  = 1'b0;
            s_tvalid = 1'b0;
        end
    endtask

    initial begin
        $dumpfile("router_coverage.vcd");
        $dumpvars(0, router_coverage_tb);

        pclk      = 1'b0;
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

        // Reset, then intentionally leave router disabled briefly.
        repeat (3) @(negedge pclk);
        presetn = 1'b1;

        // Covers enable = 0.
        repeat (2) @(posedge pclk);

        // Enable router, route_mode = 00 (default routing).
        apb_write(8'h00, 32'h0000_0001);

        // Covers default mode, destination 0, output m0.
        send_packet(32'h1000_0001, 1'b0);

        // Covers default mode, destination 1, output m1.
        send_packet(32'h2000_0002, 1'b1);

        // Covers backpressure on output m0.
        m0_tready = 1'b0;

        @(negedge pclk);
        s_tdata  = 32'h3000_0003;
        s_tdest  = 1'b0;
        s_tvalid = 1'b1;

        repeat (3) @(negedge pclk);

        m0_tready = 1'b1;
        wait (s_tready == 1'b1);

        @(negedge pclk);
        s_tdata  = '0;
        s_tdest  = 1'b0;
        s_tvalid = 1'b0;

        // Enable router, route_mode = 01: force m0.
        apb_write(8'h00, 32'h0000_0003);

        // dest=1 but packet must go to m0.
        send_packet(32'h4000_0004, 1'b1);

        // Enable router, route_mode = 10: force m1.
        apb_write(8'h00, 32'h0000_0005);

        // dest=0 but packet must go to m1.
        send_packet(32'h5000_0005, 1'b0);

        // Illegal APB access: should assert pslverr.
        apb_write(8'hF0, 32'hDEAD_BEEF);

        repeat (3) @(posedge pclk);

        coverage.report_coverage();

        $display("PASS: functional coverage test completed successfully.");
        #20;
        $finish;
    end

endmodule