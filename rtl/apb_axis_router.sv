module apb_axis_router (
    // APB interface
    input  logic        pclk,
    input  logic        presetn,
    input  logic        psel,
    input  logic        penable,
    input  logic        pwrite,
    input  logic [7:0]  paddr,
    input  logic [31:0] pwdata,
    output logic [31:0] prdata,
    output logic        pready,
    output logic        pslverr,

    // AXI-Stream input
    input  logic [31:0] s_tdata,
    input  logic        s_tdest,
    input  logic        s_tvalid,
    output logic        s_tready,

    // AXI-Stream output 0
    output logic [31:0] m0_tdata,
    output logic        m0_tvalid,
    input  logic        m0_tready,

    // AXI-Stream output 1
    output logic [31:0] m1_tdata,
    output logic        m1_tvalid,
    input  logic        m1_tready
);

    // Register map
    localparam logic [7:0] ADDR_CTRL   = 8'h00;
    localparam logic [7:0] ADDR_STATUS = 8'h04;
    localparam logic [7:0] ADDR_COUNT  = 8'h08;

    logic        enable_q;
    logic [1:0]  route_mode_q;
    logic [31:0] packet_count_q;
    logic        selected_out;

    // APB always responds in one access cycle
    assign pready = 1'b1;

    // Invalid address causes APB error
    always_comb begin
        pslverr = 1'b0;

        if (psel && penable) begin
            case (paddr)
                ADDR_CTRL,
                ADDR_STATUS,
                ADDR_COUNT: pslverr = 1'b0;
                default:    pslverr = 1'b1;
            endcase
        end
    end

    // APB read data
    always_comb begin
        prdata = 32'h0;

        case (paddr)
            ADDR_CTRL: begin
                prdata[0]   = enable_q;
                prdata[2:1] = route_mode_q;
            end

            ADDR_STATUS: begin
                prdata[0] = enable_q;
            end

            ADDR_COUNT: begin
                prdata = packet_count_q;
            end

            default: prdata = 32'h0;
        endcase
    end

    // APB writable control register
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            enable_q     <= 1'b0;
            route_mode_q <= 2'b00;
        end
        else if (psel && penable && pwrite && (paddr == ADDR_CTRL)) begin
            enable_q     <= pwdata[0];
            route_mode_q <= pwdata[2:1];
        end
    end

    // Routing rule:
    // 00: route according to s_tdest
    // 01: force every packet to output 0
    // 10: force every packet to output 1
    // 11: reserved, treated as s_tdest routing
    always_comb begin
        case (route_mode_q)
            2'b01:  selected_out = 1'b0;
            2'b10:  selected_out = 1'b1;
            default: selected_out = s_tdest;
        endcase
    end

    // AXI-Stream routing and backpressure
    always_comb begin
        m0_tdata  = s_tdata;
        m1_tdata  = s_tdata;
        m0_tvalid = 1'b0;
        m1_tvalid = 1'b0;
        s_tready  = 1'b0;

        if (enable_q) begin
            if (selected_out == 1'b0) begin
                m0_tvalid = s_tvalid;
                s_tready  = m0_tready;
            end
            else begin
                m1_tvalid = s_tvalid;
                s_tready  = m1_tready;
            end
        end
    end

    // Count each successfully transferred packet
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            packet_count_q <= 32'h0;
        end
        else if (s_tvalid && s_tready) begin
            packet_count_q <= packet_count_q + 1'b1;
        end
    end

endmodule