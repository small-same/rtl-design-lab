/* verilator lint_off UNUSED */
`timescale 1ns/1ps

module axi_interconnect #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter NUM_SLAVES = 4,
    // Slave 0: SRAM  — 0x0000_0000, 4KB
    parameter [ADDR_WIDTH-1:0] S0_BASE = 32'h0000_0000,
    parameter [ADDR_WIDTH-1:0] S0_SIZE = 32'h0000_1000,
    // Slave 1: DMA regs — 0x0001_0000, 32B
    parameter [ADDR_WIDTH-1:0] S1_BASE = 32'h0001_0000,
    parameter [ADDR_WIDTH-1:0] S1_SIZE = 32'h0000_0020,
    // Slave 2: UART — 0x0002_0000, 16B
    parameter [ADDR_WIDTH-1:0] S2_BASE = 32'h0002_0000,
    parameter [ADDR_WIDTH-1:0] S2_SIZE = 32'h0000_0010,
    // Slave 3: Timer — 0x0003_0000, 16B
    parameter [ADDR_WIDTH-1:0] S3_BASE = 32'h0003_0000,
    parameter [ADDR_WIDTH-1:0] S3_SIZE = 32'h0000_0010
) (
    input  wire                    clk,
    input  wire                    rst_n,

    // ---- Master port (AXI4-Lite) ----
    // Write Address
    input  wire [ADDR_WIDTH-1:0]   m_awaddr,
    input  wire                    m_awvalid,
    output reg                     m_awready,
    // Write Data
    input  wire [DATA_WIDTH-1:0]   m_wdata,
    input  wire [DATA_WIDTH/8-1:0] m_wstrb,
    input  wire                    m_wvalid,
    output reg                     m_wready,
    // Write Response
    output reg  [1:0]              m_bresp,
    output reg                     m_bvalid,
    input  wire                    m_bready,
    // Read Address
    input  wire [ADDR_WIDTH-1:0]   m_araddr,
    input  wire                    m_arvalid,
    output reg                     m_arready,
    // Read Data
    output reg  [DATA_WIDTH-1:0]   m_rdata,
    output reg  [1:0]              m_rresp,
    output reg                     m_rvalid,
    input  wire                    m_rready,

    // ---- Slave 0 port ----
    output reg  [ADDR_WIDTH-1:0]   s0_awaddr,
    output reg                     s0_awvalid,
    input  wire                    s0_awready,
    output reg  [DATA_WIDTH-1:0]   s0_wdata,
    output reg  [DATA_WIDTH/8-1:0] s0_wstrb,
    output reg                     s0_wvalid,
    input  wire                    s0_wready,
    input  wire [1:0]              s0_bresp,
    input  wire                    s0_bvalid,
    output reg                     s0_bready,
    output reg  [ADDR_WIDTH-1:0]   s0_araddr,
    output reg                     s0_arvalid,
    input  wire                    s0_arready,
    input  wire [DATA_WIDTH-1:0]   s0_rdata,
    input  wire [1:0]              s0_rresp,
    input  wire                    s0_rvalid,
    output reg                     s0_rready,

    // ---- Slave 1 port ----
    output reg  [ADDR_WIDTH-1:0]   s1_awaddr,
    output reg                     s1_awvalid,
    input  wire                    s1_awready,
    output reg  [DATA_WIDTH-1:0]   s1_wdata,
    output reg  [DATA_WIDTH/8-1:0] s1_wstrb,
    output reg                     s1_wvalid,
    input  wire                    s1_wready,
    input  wire [1:0]              s1_bresp,
    input  wire                    s1_bvalid,
    output reg                     s1_bready,
    output reg  [ADDR_WIDTH-1:0]   s1_araddr,
    output reg                     s1_arvalid,
    input  wire                    s1_arready,
    input  wire [DATA_WIDTH-1:0]   s1_rdata,
    input  wire [1:0]              s1_rresp,
    input  wire                    s1_rvalid,
    output reg                     s1_rready,

    // ---- Slave 2 port ----
    output reg  [ADDR_WIDTH-1:0]   s2_awaddr,
    output reg                     s2_awvalid,
    input  wire                    s2_awready,
    output reg  [DATA_WIDTH-1:0]   s2_wdata,
    output reg  [DATA_WIDTH/8-1:0] s2_wstrb,
    output reg                     s2_wvalid,
    input  wire                    s2_wready,
    input  wire [1:0]              s2_bresp,
    input  wire                    s2_bvalid,
    output reg                     s2_bready,
    output reg  [ADDR_WIDTH-1:0]   s2_araddr,
    output reg                     s2_arvalid,
    input  wire                    s2_arready,
    input  wire [DATA_WIDTH-1:0]   s2_rdata,
    input  wire [1:0]              s2_rresp,
    input  wire                    s2_rvalid,
    output reg                     s2_rready,

    // ---- Slave 3 port ----
    output reg  [ADDR_WIDTH-1:0]   s3_awaddr,
    output reg                     s3_awvalid,
    input  wire                    s3_awready,
    output reg  [DATA_WIDTH-1:0]   s3_wdata,
    output reg  [DATA_WIDTH/8-1:0] s3_wstrb,
    output reg                     s3_wvalid,
    input  wire                    s3_wready,
    input  wire [1:0]              s3_bresp,
    input  wire                    s3_bvalid,
    output reg                     s3_bready,
    output reg  [ADDR_WIDTH-1:0]   s3_araddr,
    output reg                     s3_arvalid,
    input  wire                    s3_arready,
    input  wire [DATA_WIDTH-1:0]   s3_rdata,
    input  wire [1:0]              s3_rresp,
    input  wire                    s3_rvalid,
    output reg                     s3_rready
);

    // ----------------------------------------------------------------
    // Address decode
    // ----------------------------------------------------------------
    localparam SEL_NONE = 3'd4;

    // Write channel selection (registered)
    reg [2:0] wr_sel_d, wr_sel_q;

    // Read channel selection (registered)
    reg [2:0] rd_sel_d, rd_sel_q;

    // Decode function — purely combinational
    function [2:0] addr_decode;
        input [ADDR_WIDTH-1:0] addr;
        begin
            if (addr < (S0_BASE + S0_SIZE))
                addr_decode = 3'd0;
            else if (addr >= S1_BASE && addr < (S1_BASE + S1_SIZE))
                addr_decode = 3'd1;
            else if (addr >= S2_BASE && addr < (S2_BASE + S2_SIZE))
                addr_decode = 3'd2;
            else if (addr >= S3_BASE && addr < (S3_BASE + S3_SIZE))
                addr_decode = 3'd3;
            else
                addr_decode = SEL_NONE;
        end
    endfunction

    // ----------------------------------------------------------------
    // Write path FSM
    // ----------------------------------------------------------------
    // States: IDLE(00), ADDR_DATA(01), RESP(10), DECERR_RESP(11)
    localparam WR_IDLE      = 2'd0;
    localparam WR_ADDR_DATA = 2'd1;
    localparam WR_RESP      = 2'd2;
    localparam WR_DECERR    = 2'd3;

    reg [1:0] wr_state_d, wr_state_q;
    reg       aw_done_d, aw_done_q;  // AW handshake done in current txn
    reg       w_done_d, w_done_q;    // W handshake done in current txn

    always_comb begin
        wr_state_d = wr_state_q;
        wr_sel_d   = wr_sel_q;
        aw_done_d  = aw_done_q;
        w_done_d   = w_done_q;

        // Master-side defaults
        m_awready = 1'b0;
        m_wready  = 1'b0;
        m_bvalid  = 1'b0;
        m_bresp   = 2'b00;

        // Slave-side defaults: deassert all valids/readys
        s0_awaddr  = {ADDR_WIDTH{1'b0}}; s0_awvalid = 1'b0;
        s0_wdata   = {DATA_WIDTH{1'b0}}; s0_wstrb = {(DATA_WIDTH/8){1'b0}}; s0_wvalid = 1'b0;
        s0_bready  = 1'b0;

        s1_awaddr  = {ADDR_WIDTH{1'b0}}; s1_awvalid = 1'b0;
        s1_wdata   = {DATA_WIDTH{1'b0}}; s1_wstrb = {(DATA_WIDTH/8){1'b0}}; s1_wvalid = 1'b0;
        s1_bready  = 1'b0;

        s2_awaddr  = {ADDR_WIDTH{1'b0}}; s2_awvalid = 1'b0;
        s2_wdata   = {DATA_WIDTH{1'b0}}; s2_wstrb = {(DATA_WIDTH/8){1'b0}}; s2_wvalid = 1'b0;
        s2_bready  = 1'b0;

        s3_awaddr  = {ADDR_WIDTH{1'b0}}; s3_awvalid = 1'b0;
        s3_wdata   = {DATA_WIDTH{1'b0}}; s3_wstrb = {(DATA_WIDTH/8){1'b0}}; s3_wvalid = 1'b0;
        s3_bready  = 1'b0;

        case (wr_state_q)
            WR_IDLE: begin
                if (m_awvalid) begin
                    wr_sel_d = addr_decode(m_awaddr);
                    if (wr_sel_d == SEL_NONE) begin
                        // Accept AW immediately, then generate DECERR
                        m_awready  = 1'b1;
                        m_wready   = m_wvalid; // also consume W if present
                        aw_done_d  = 1'b1;
                        w_done_d   = m_wvalid;
                        if (m_wvalid)
                            wr_state_d = WR_DECERR;
                        else begin
                            wr_state_d = WR_ADDR_DATA; // wait for W
                        end
                    end else begin
                        wr_state_d = WR_ADDR_DATA;
                        aw_done_d  = 1'b0;
                        w_done_d   = 1'b0;
                    end
                end
            end

            WR_ADDR_DATA: begin
                if (wr_sel_q == SEL_NONE) begin
                    // Unmapped: just consume W data then go to DECERR
                    m_wready = m_wvalid;
                    if (m_wvalid) begin
                        w_done_d   = 1'b1;
                        wr_state_d = WR_DECERR;
                    end
                end else begin
                    // Forward AW to selected slave (if not done)
                    if (!aw_done_q) begin
                        m_awready = 1'b0; // will accept once slave accepts
                        case (wr_sel_q)
                            3'd0: begin s0_awaddr = m_awaddr; s0_awvalid = m_awvalid; if (s0_awready && m_awvalid) begin m_awready = 1'b1; aw_done_d = 1'b1; end end
                            3'd1: begin s1_awaddr = m_awaddr; s1_awvalid = m_awvalid; if (s1_awready && m_awvalid) begin m_awready = 1'b1; aw_done_d = 1'b1; end end
                            3'd2: begin s2_awaddr = m_awaddr; s2_awvalid = m_awvalid; if (s2_awready && m_awvalid) begin m_awready = 1'b1; aw_done_d = 1'b1; end end
                            3'd3: begin s3_awaddr = m_awaddr; s3_awvalid = m_awvalid; if (s3_awready && m_awvalid) begin m_awready = 1'b1; aw_done_d = 1'b1; end end
                            default: ;
                        endcase
                    end

                    // Forward W to selected slave (if not done)
                    if (!w_done_q) begin
                        case (wr_sel_q)
                            3'd0: begin s0_wdata = m_wdata; s0_wstrb = m_wstrb; s0_wvalid = m_wvalid; if (s0_wready && m_wvalid) begin m_wready = 1'b1; w_done_d = 1'b1; end end
                            3'd1: begin s1_wdata = m_wdata; s1_wstrb = m_wstrb; s1_wvalid = m_wvalid; if (s1_wready && m_wvalid) begin m_wready = 1'b1; w_done_d = 1'b1; end end
                            3'd2: begin s2_wdata = m_wdata; s2_wstrb = m_wstrb; s2_wvalid = m_wvalid; if (s2_wready && m_wvalid) begin m_wready = 1'b1; w_done_d = 1'b1; end end
                            3'd3: begin s3_wdata = m_wdata; s3_wstrb = m_wstrb; s3_wvalid = m_wvalid; if (s3_wready && m_wvalid) begin m_wready = 1'b1; w_done_d = 1'b1; end end
                            default: ;
                        endcase
                    end

                    // Both done -> wait for response
                    if ((aw_done_d || aw_done_q) && (w_done_d || w_done_q))
                        wr_state_d = WR_RESP;
                end
            end

            WR_RESP: begin
                // Forward bvalid/bresp from selected slave
                case (wr_sel_q)
                    3'd0: begin m_bvalid = s0_bvalid; m_bresp = s0_bresp; s0_bready = m_bready; if (s0_bvalid && m_bready) wr_state_d = WR_IDLE; end
                    3'd1: begin m_bvalid = s1_bvalid; m_bresp = s1_bresp; s1_bready = m_bready; if (s1_bvalid && m_bready) wr_state_d = WR_IDLE; end
                    3'd2: begin m_bvalid = s2_bvalid; m_bresp = s2_bresp; s2_bready = m_bready; if (s2_bvalid && m_bready) wr_state_d = WR_IDLE; end
                    3'd3: begin m_bvalid = s3_bvalid; m_bresp = s3_bresp; s3_bready = m_bready; if (s3_bvalid && m_bready) wr_state_d = WR_IDLE; end
                    default: wr_state_d = WR_IDLE;
                endcase
            end

            WR_DECERR: begin
                m_bvalid = 1'b1;
                m_bresp  = 2'b11; // DECERR
                if (m_bready)
                    wr_state_d = WR_IDLE;
            end
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_state_q <= WR_IDLE;
            wr_sel_q   <= SEL_NONE;
            aw_done_q  <= 1'b0;
            w_done_q   <= 1'b0;
        end else begin
            wr_state_q <= wr_state_d;
            wr_sel_q   <= wr_sel_d;
            aw_done_q  <= aw_done_d;
            w_done_q   <= w_done_d;
        end
    end

    // ----------------------------------------------------------------
    // Read path FSM
    // ----------------------------------------------------------------
    localparam RD_IDLE   = 2'd0;
    localparam RD_ADDR   = 2'd1;
    localparam RD_DATA   = 2'd2;
    localparam RD_DECERR = 2'd3;

    reg [1:0] rd_state_d, rd_state_q;

    always_comb begin
        rd_state_d = rd_state_q;
        rd_sel_d   = rd_sel_q;

        m_arready = 1'b0;
        m_rdata   = {DATA_WIDTH{1'b0}};
        m_rresp   = 2'b00;
        m_rvalid  = 1'b0;

        s0_araddr = {ADDR_WIDTH{1'b0}}; s0_arvalid = 1'b0; s0_rready = 1'b0;
        s1_araddr = {ADDR_WIDTH{1'b0}}; s1_arvalid = 1'b0; s1_rready = 1'b0;
        s2_araddr = {ADDR_WIDTH{1'b0}}; s2_arvalid = 1'b0; s2_rready = 1'b0;
        s3_araddr = {ADDR_WIDTH{1'b0}}; s3_arvalid = 1'b0; s3_rready = 1'b0;

        case (rd_state_q)
            RD_IDLE: begin
                if (m_arvalid) begin
                    rd_sel_d = addr_decode(m_araddr);
                    if (rd_sel_d == SEL_NONE) begin
                        m_arready  = 1'b1;
                        rd_state_d = RD_DECERR;
                    end else begin
                        rd_state_d = RD_ADDR;
                    end
                end
            end

            RD_ADDR: begin
                case (rd_sel_q)
                    3'd0: begin s0_araddr = m_araddr; s0_arvalid = m_arvalid; if (s0_arready && m_arvalid) begin m_arready = 1'b1; rd_state_d = RD_DATA; end end
                    3'd1: begin s1_araddr = m_araddr; s1_arvalid = m_arvalid; if (s1_arready && m_arvalid) begin m_arready = 1'b1; rd_state_d = RD_DATA; end end
                    3'd2: begin s2_araddr = m_araddr; s2_arvalid = m_arvalid; if (s2_arready && m_arvalid) begin m_arready = 1'b1; rd_state_d = RD_DATA; end end
                    3'd3: begin s3_araddr = m_araddr; s3_arvalid = m_arvalid; if (s3_arready && m_arvalid) begin m_arready = 1'b1; rd_state_d = RD_DATA; end end
                    default: rd_state_d = RD_IDLE;
                endcase
            end

            RD_DATA: begin
                case (rd_sel_q)
                    3'd0: begin m_rvalid = s0_rvalid; m_rdata = s0_rdata; m_rresp = s0_rresp; s0_rready = m_rready; if (s0_rvalid && m_rready) rd_state_d = RD_IDLE; end
                    3'd1: begin m_rvalid = s1_rvalid; m_rdata = s1_rdata; m_rresp = s1_rresp; s1_rready = m_rready; if (s1_rvalid && m_rready) rd_state_d = RD_IDLE; end
                    3'd2: begin m_rvalid = s2_rvalid; m_rdata = s2_rdata; m_rresp = s2_rresp; s2_rready = m_rready; if (s2_rvalid && m_rready) rd_state_d = RD_IDLE; end
                    3'd3: begin m_rvalid = s3_rvalid; m_rdata = s3_rdata; m_rresp = s3_rresp; s3_rready = m_rready; if (s3_rvalid && m_rready) rd_state_d = RD_IDLE; end
                    default: rd_state_d = RD_IDLE;
                endcase
            end

            RD_DECERR: begin
                m_rvalid = 1'b1;
                m_rresp  = 2'b11; // DECERR
                m_rdata  = {DATA_WIDTH{1'b0}};
                if (m_rready)
                    rd_state_d = RD_IDLE;
            end
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_state_q <= RD_IDLE;
            rd_sel_q   <= SEL_NONE;
        end else begin
            rd_state_q <= rd_state_d;
            rd_sel_q   <= rd_sel_d;
        end
    end

endmodule
