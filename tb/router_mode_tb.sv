`timescale 1ns/1ps

module router_mode_tb;

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

    task automatic send_and_check(
        input logic [31:0] data,
        input logic        dest,
        input logic        expected_output
    );
        begin
            @(negedge pclk);
            s_tdata  = data;
            s_tdest  = dest;
            s_tvalid = 1'b1;

            #1;

            if (expected_output == 1'b0) begin
                if (!m0_tvalid || m1_tvalid) begin
                    $fatal(1, "FAIL: packet should be routed to output 0.");
                end
            end
            else begin
                if (!m1_tvalid || m0_tvalid) begin
                    $fatal(1, "FAIL: packet should be routed to output 1.");
                end
            end

            @(posedge pclk);
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

        $dumpfile("router_mode.vcd");
        $dumpvars(0, router_mode_tb);

        // Reset
        #20;
        presetn = 1'b1;

        // Test 1:
        // CTRL = 3 = 3'b011
        // enable = 1, route_mode = 01
        // Force every packet to output 0
        apb_write(8'h00, 32'h0000_0003);

        // Even though tdest = 1, packet must go to output 0
        send_and_check(32'hAAAA_0001, 1'b1, 1'b0);

        // Test 2:
        // CTRL = 5 = 3'b101
        // enable = 1, route_mode = 10
        // Force every packet to output 1
        apb_write(8'h00, 32'h0000_0005);

        // Even though tdest = 0, packet must go to output 1
        send_and_check(32'hBBBB_0002, 1'b0, 1'b1);

        #1;

        if (dut.packet_count_q != 32'd2) begin
            $fatal(1, "FAIL: packet counter should equal 2, actual = %0d",
                   dut.packet_count_q);
        end

        $display("PASS: route mode test completed successfully.");
        #20;
        $finish;
    end

endmodule