`timescale 1ns/1ps

module router_sva_tb;

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

    logic        enable_q;
    logic [1:0]  route_mode_q;
    logic [31:0] packet_count_q;

    // Clock: 10 ns period
    always #5 pclk = ~pclk;

    // DUT
    apb_axis_router dut (
        .pclk           (pclk),
        .presetn        (presetn),

        .psel           (psel),
        .penable        (penable),
        .pwrite         (pwrite),
        .paddr          (paddr),
        .pwdata         (pwdata),
        .prdata         (prdata),
        .pready         (pready),
        .pslverr        (pslverr),

        .s_tdata        (s_tdata),
        .s_tdest        (s_tdest),
        .s_tvalid       (s_tvalid),
        .s_tready       (s_tready),

        .m0_tdata       (m0_tdata),
        .m0_tvalid      (m0_tvalid),
        .m0_tready      (m0_tready),

        .m1_tdata       (m1_tdata),
        .m1_tvalid      (m1_tvalid),
        .m1_tready      (m1_tready)
    );

    // Access DUT internal registers for assertions.
    assign enable_q       = dut.enable_q;
    assign route_mode_q   = dut.route_mode_q;
    assign packet_count_q = dut.packet_count_q;

    // SVA checker
    router_assertion_checker assertion_checker (
        .pclk       (pclk),
        .presetn    (presetn),

        .enable_q   (enable_q),

        .s_tdata    (s_tdata),
        .s_tdest    (s_tdest),
        .s_tvalid   (s_tvalid),
        .s_tready   (s_tready),

        .m0_tdata   (m0_tdata),
        .m0_tvalid  (m0_tvalid),
        .m0_tready  (m0_tready),

        .m1_tdata   (m1_tdata),
        .m1_tvalid  (m1_tvalid),
        .m1_tready  (m1_tready)
    );

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
            s_tvalid = 1'b0;
            s_tdata  = '0;
            s_tdest  = 1'b0;
        end
    endtask

    initial begin
        $dumpfile("router_sva.vcd");
        $dumpvars(0, router_sva_tb);

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

        // Reset
        repeat (3) @(negedge pclk);
        presetn = 1'b1;

        // Enable router, default routing: route_mode = 00.
        apb_write(8'h00, 32'h0000_0001);

        // Packet 1: default route to m0.
        send_packet(32'hAAAA_0001, 1'b0);

        // Packet 2: default route to m1.
        send_packet(32'hBBBB_0002, 1'b1);

        // Packet 3: block m0 first, then release it.
        m0_tready = 1'b0;

        @(negedge pclk);
        s_tdata  = 32'hCCCC_0003;
        s_tdest  = 1'b0;
        s_tvalid = 1'b1;

        repeat (3) @(negedge pclk);

        // During this period, SVA checks m0 data remains stable.
        m0_tready = 1'b1;

        wait (s_tready == 1'b1);

        @(negedge pclk);
        s_tvalid = 1'b0;
        s_tdata  = '0;
        s_tdest  = 1'b0;

        // Force all packets to m1: enable=1, route_mode=10.
        apb_write(8'h00, 32'h0000_0005);

        // Even with dest=0, packet must go to m1.
        send_packet(32'hDDDD_0004, 1'b0);

        repeat (3) @(negedge pclk);

        if (packet_count_q != 32'd4) begin
            $fatal(1,
                "ERROR: expected packet_count=4, got %0d",
                packet_count_q
            );
        end

        $display("PASS: SVA integration test completed successfully.");
        #20;
        $finish;
    end

endmodule