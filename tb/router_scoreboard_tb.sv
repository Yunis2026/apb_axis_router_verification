`timescale 1ns/1ps

module router_scoreboard_tb;

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

    // Scoreboard
    router_scoreboard sb (
        .pclk       (pclk),
        .presetn    (presetn),

        .route_mode (dut.route_mode_q),

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

            #1;

            if (pslverr != 1'b0) begin
                $fatal(1, "FAIL: legal APB write raised pslverr.");
            end

            @(negedge pclk);
            psel    = 1'b0;
            penable = 1'b0;
            pwrite  = 1'b0;
            paddr   = '0;
            pwdata  = '0;
        end
    endtask

    // Driver task:
    // Holds valid and data stable until a valid-ready handshake occurs.
    task automatic send_packet(
        input logic [31:0] data,
        input logic        dest
    );
        begin
            @(negedge pclk);
            s_tdata  = data;
            s_tdest  = dest;
            s_tvalid = 1'b1;

            // Keep the packet stable until router accepts it.
            do begin
                @(posedge pclk);
            end while (!s_tready);

            @(negedge pclk);
            s_tvalid = 1'b0;
            s_tdata  = '0;
            s_tdest  = 1'b0;
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

        $dumpfile("router_scoreboard.vcd");
        $dumpvars(0, router_scoreboard_tb);

        // 1. Reset and enable default routing mode.
        #20;
        presetn = 1'b1;

        // CTRL = 1: enable=1, route_mode=00.
        apb_write(8'h00, 32'h0000_0001);

        // 2. Default routing: one packet to each output.
        send_packet(32'h1111_0001, 1'b0);
        send_packet(32'h2222_0002, 1'b1);

        // 3. Backpressure: block output 0 for three cycles.
        m0_tready = 1'b0;

        fork
            begin
                send_packet(32'h3333_0003, 1'b0);
            end

            begin
                repeat (3) @(posedge pclk);

                @(negedge pclk);
                m0_tready = 1'b1;
            end
        join

        // 4. Force all packets to output 1.
        // CTRL = 5: enable=1, route_mode=10.
        apb_write(8'h00, 32'h0000_0005);

        // Even though dest=0, scoreboard must expect output 1.
        send_packet(32'h4444_0004, 1'b0);

        #1;

        if (dut.packet_count_q != 32'd4) begin
            $fatal(1,
                "FAIL: packet counter should equal 4, actual = %0d.",
                dut.packet_count_q);
        end

        $display("PASS: scoreboard integration test completed successfully.");
        #20;
        $finish;
    end

endmodule