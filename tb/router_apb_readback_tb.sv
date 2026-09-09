`timescale 1ns/1ps

module router_apb_readback_tb;

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

    task automatic apb_read_and_check(
        input logic [7:0]  addr,
        input logic [31:0] expected_data
    );
        begin
            // APB read setup phase
            @(negedge pclk);
            psel    = 1'b1;
            penable = 1'b0;
            pwrite  = 1'b0;
            paddr   = addr;

            // APB read access phase
            @(negedge pclk);
            penable = 1'b1;

            #1;

            if (pslverr != 1'b0) begin
                $fatal(1, "FAIL: legal APB read raised pslverr.");
            end

            if (prdata !== expected_data) begin
                $fatal(1,
                    "FAIL: read address 0x%0h. Expected 0x%08h, got 0x%08h.",
                    addr, expected_data, prdata);
            end

            @(negedge pclk);
            psel    = 1'b0;
            penable = 1'b0;
            paddr   = '0;
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

            #1;

            // route_mode=10, so every packet must go to output 1
            if (!m1_tvalid || m0_tvalid || !s_tready) begin
                $fatal(1, "FAIL: packet was not force-routed to output 1.");
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

        $dumpfile("router_apb_readback.vcd");
        $dumpvars(0, router_apb_readback_tb);

        // 1. Reset and check default CTRL value.
        #20;
        presetn = 1'b1;

        apb_read_and_check(8'h00, 32'h0000_0000);

        // 2. Write CTRL:
        // enable=1 and route_mode=10, so CTRL = 3'b101 = 0x5.
        apb_write(8'h00, 32'h0000_0005);

        // 3. Read CTRL and STATUS.
        apb_read_and_check(8'h00, 32'h0000_0005);
        apb_read_and_check(8'h04, 32'h0000_0001);

        // 4. Send two packets; both should be force-routed to output 1.
        send_packet(32'h1111_0001, 1'b0);
        send_packet(32'h2222_0002, 1'b1);

        #1;

        if (dut.packet_count_q != 32'd2) begin
            $fatal(1, "FAIL: packet counter should equal 2.");
        end

        // 5. Read COUNT register through APB.
        apb_read_and_check(8'h08, 32'h0000_0002);

        $display("PASS: APB readback test completed successfully.");
        #20;
        $finish;
    end

endmodule