`timescale 1ns/1ps

module router_illegal_apb_tb;

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

    task automatic check_illegal_access(
        input logic       write_not_read,
        input logic [7:0] addr
    );
        begin
            // APB setup phase: error must remain low.
            @(negedge pclk);
            psel    = 1'b1;
            penable = 1'b0;
            pwrite  = write_not_read;
            paddr   = addr;
            pwdata  = 32'hDEAD_BEEF;

            #1;

            if (pslverr != 1'b0) begin
                $fatal(1, "FAIL: pslverr must be 0 during APB setup phase.");
            end

            // APB access phase: invalid address must raise pslverr.
            @(negedge pclk);
            penable = 1'b1;

            #1;

            if (pslverr != 1'b1) begin
                $fatal(1, "FAIL: invalid APB address did not raise pslverr.");
            end

            // End transfer: error must return low.
            @(negedge pclk);
            psel    = 1'b0;
            penable = 1'b0;
            pwrite  = 1'b0;
            paddr   = '0;
            pwdata  = '0;

            #1;

            if (pslverr != 1'b0) begin
                $fatal(1, "FAIL: pslverr must return to 0 after transfer.");
            end
        end
    endtask

    task automatic check_legal_enable_write;
        begin
            @(negedge pclk);
            psel    = 1'b1;
            penable = 1'b0;
            pwrite  = 1'b1;
            paddr   = 8'h00;
            pwdata  = 32'h0000_0001;

            @(negedge pclk);
            penable = 1'b1;

            #1;

            if (pslverr != 1'b0) begin
                $fatal(1, "FAIL: legal APB CTRL write raised pslverr.");
            end

            @(negedge pclk);
            psel    = 1'b0;
            penable = 1'b0;
            pwrite  = 1'b0;
            paddr   = '0;
            pwdata  = '0;
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

        $dumpfile("router_illegal_apb.vcd");
        $dumpvars(0, router_illegal_apb_tb);

        // Reset
        #20;
        presetn = 1'b1;

        // Test an illegal APB write and an illegal APB read.
        check_illegal_access(1'b1, 8'hFF);
        check_illegal_access(1'b0, 8'hFC);

        // Illegal accesses must not change DUT state.
        if (dut.enable_q != 1'b0 || dut.packet_count_q != 32'd0) begin
            $fatal(1, "FAIL: illegal access changed DUT state.");
        end

        // Legal access must still work and must not raise an error.
        check_legal_enable_write();

        if (dut.enable_q != 1'b1) begin
            $fatal(1, "FAIL: legal CTRL write did not enable router.");
        end

        $display("PASS: illegal APB address test completed successfully.");
        #20;
        $finish;
    end

endmodule