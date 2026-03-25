// AXI DMA Register Wrapper — AXI4-Lite slave, burst decomposition to single-beat
/* verilator lint_off UNUSED */
module axi_dma_regs #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  logic                    clk,
    input  logic                    rst_n,

    // AXI4-Lite Slave (from interconnect)
    input  logic [ADDR_WIDTH-1:0]  s_awaddr,
    input  logic                    s_awvalid,
    output logic                    s_awready,
    input  logic [DATA_WIDTH-1:0]  s_wdata,
    input  logic [DATA_WIDTH/8-1:0] s_wstrb,
    input  logic                    s_wvalid,
    output logic                    s_wready,
    output logic [1:0]             s_bresp,
    output logic                    s_bvalid,
    input  logic                    s_bready,
    input  logic [ADDR_WIDTH-1:0]  s_araddr,
    input  logic                    s_arvalid,
    output logic                    s_arready,
    output logic [DATA_WIDTH-1:0]  s_rdata,
    output logic [1:0]             s_rresp,
    output logic                    s_rvalid,
    input  logic                    s_rready,

    // DMA Core interface (directly to axi_dma_core)
    output logic                    dma_start,
    output logic [ADDR_WIDTH-1:0]  src_addr,
    output logic [ADDR_WIDTH-1:0]  dst_addr,
    output logic [15:0]            xfer_len,

    // AXI4 Write master (from DMA core) — directly exposed
    output logic [ADDR_WIDTH-1:0]  m_awaddr,
    output logic [7:0]             m_awlen,
    output logic                    m_awvalid,
    input  logic                    m_awready,
    output logic [DATA_WIDTH-1:0]  m_wdata,
    output logic                    m_wlast,
    output logic                    m_wvalid,
    input  logic                    m_wready,
    input  logic [1:0]             m_bresp,
    input  logic                    m_bvalid,
    output logic                    m_bready,

    output logic                    irq
);

    // Register map (byte offsets):
    //   0x00: CTRL      (RW) — [0] start (auto-clear), [1] irq_en
    //   0x04: STATUS    (R/W1C) — [0] done, [1] busy
    //   0x08: SRC_ADDR  (RW)
    //   0x0C: DST_ADDR  (RW)
    //   0x10: XFER_LEN  (RW) — [15:0] transfer length in beats
    //   0x14: reserved
    //   0x18: reserved
    //   0x1C: reserved

    localparam ADDR_LSB = $clog2(DATA_WIDTH / 8);

    // DMA done signal from internal core
    logic dma_done;

    // ---------------------------------------------------------------
    // Register storage
    // ---------------------------------------------------------------
    logic        irq_en_q;
    logic        done_flag_q;
    logic [ADDR_WIDTH-1:0] src_addr_q;
    logic [ADDR_WIDTH-1:0] dst_addr_q;
    logic [15:0] xfer_len_q;
    logic        dma_start_q;
    logic        dma_busy_q;

    // DMA core connections
    assign src_addr  = src_addr_q;
    assign dst_addr  = dst_addr_q;
    assign xfer_len  = xfer_len_q;
    assign dma_start = dma_start_q;
    assign irq       = irq_en_q && done_flag_q;

    // ---------------------------------------------------------------
    // Write channel + DMA state tracking (single always_ff to avoid multi-driven regs)
    // ---------------------------------------------------------------
    logic aw_done_q, w_done_q;
    logic [ADDR_WIDTH-1:0] awaddr_reg_q;
    logic [DATA_WIDTH-1:0] wdata_reg_q;
    logic s_bvalid_q;

    // Intermediate signals for write decode
    logic       wr_commit;
    logic [2:0] wr_addr_sel;
    logic [DATA_WIDTH-1:0] wr_data_sel;

    assign wr_commit   = !s_bvalid_q &&
                          (aw_done_q || (s_awvalid && !aw_done_q)) &&
                          (w_done_q  || (s_wvalid  && !w_done_q));
    assign wr_addr_sel = aw_done_q ? awaddr_reg_q[ADDR_LSB+2:ADDR_LSB] : s_awaddr[ADDR_LSB+2:ADDR_LSB];
    assign wr_data_sel = w_done_q  ? wdata_reg_q : s_wdata;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            aw_done_q    <= 1'b0;
            w_done_q     <= 1'b0;
            awaddr_reg_q <= '0;
            wdata_reg_q  <= '0;
            s_bvalid_q   <= 1'b0;
            irq_en_q     <= 1'b0;
            src_addr_q   <= '0;
            dst_addr_q   <= '0;
            xfer_len_q   <= 16'd0;
            dma_start_q  <= 1'b0;
            dma_busy_q   <= 1'b0;
            done_flag_q  <= 1'b0;
        end else begin
            // Auto-clear start pulse and set busy
            if (dma_start_q) begin
                dma_start_q <= 1'b0;
                dma_busy_q  <= 1'b1;
            end

            // DMA completion: set done, clear busy
            if (dma_done) begin
                dma_busy_q  <= 1'b0;
                done_flag_q <= 1'b1;
            end

            // Accept AW
            if (s_awvalid && !aw_done_q && !s_bvalid_q) begin
                aw_done_q    <= 1'b1;
                awaddr_reg_q <= s_awaddr;
            end
            // Accept W
            if (s_wvalid && !w_done_q && !s_bvalid_q) begin
                w_done_q    <= 1'b1;
                wdata_reg_q <= s_wdata;
            end
            // Perform write (AXI writes have priority over DMA events for shared regs)
            if (wr_commit) begin
                s_bvalid_q <= 1'b1;
                case (wr_addr_sel)
                    3'b000: begin // CTRL
                        if (wr_data_sel[0])
                            dma_start_q <= 1'b1;
                        irq_en_q <= wr_data_sel[1];
                    end
                    3'b001: begin // STATUS (W1C)
                        if (wr_data_sel[0])
                            done_flag_q <= 1'b0;
                    end
                    3'b010: src_addr_q <= wr_data_sel; // SRC_ADDR
                    3'b011: dst_addr_q <= wr_data_sel; // DST_ADDR
                    3'b100: xfer_len_q <= wr_data_sel[15:0]; // XFER_LEN
                    default: ;
                endcase
            end
            // Clear
            if (s_bvalid_q && s_bready) begin
                s_bvalid_q <= 1'b0;
                aw_done_q  <= 1'b0;
                w_done_q   <= 1'b0;
            end
        end
    end

    assign s_awready = !aw_done_q && !s_bvalid_q;
    assign s_wready  = !w_done_q && !s_bvalid_q;
    assign s_bvalid  = s_bvalid_q;
    assign s_bresp   = 2'b00;

    // ---------------------------------------------------------------
    // Read channel
    // ---------------------------------------------------------------
    logic s_rvalid_q;
    logic [DATA_WIDTH-1:0] s_rdata_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_rvalid_q <= 1'b0;
            s_rdata_q  <= '0;
        end else begin
            if (s_arvalid && !s_rvalid_q) begin
                s_rvalid_q <= 1'b1;
                case (s_araddr[ADDR_LSB+2:ADDR_LSB])
                    3'b000: s_rdata_q <= {{(DATA_WIDTH-2){1'b0}}, irq_en_q, 1'b0};       // CTRL (start always reads 0)
                    3'b001: s_rdata_q <= {{(DATA_WIDTH-2){1'b0}}, dma_busy_q, done_flag_q}; // STATUS
                    3'b010: s_rdata_q <= src_addr_q;
                    3'b011: s_rdata_q <= dst_addr_q;
                    3'b100: s_rdata_q <= {{(DATA_WIDTH-16){1'b0}}, xfer_len_q};
                    default: s_rdata_q <= '0;
                endcase
            end
            if (s_rvalid_q && s_rready)
                s_rvalid_q <= 1'b0;
        end
    end

    assign s_arready = !s_rvalid_q;
    assign s_rvalid  = s_rvalid_q;
    assign s_rdata   = s_rdata_q;
    assign s_rresp   = 2'b00;

    // ---------------------------------------------------------------
    // DMA Core instance
    // ---------------------------------------------------------------
    axi_dma_core #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_dma_core (
        .clk       (clk),
        .rst_n     (rst_n),
        .awaddr    (m_awaddr),
        .awlen     (m_awlen),
        .awvalid   (m_awvalid),
        .awready   (m_awready),
        .wdata     (m_wdata),
        .wlast     (m_wlast),
        .wvalid    (m_wvalid),
        .wready    (m_wready),
        .bresp     (m_bresp),
        .bvalid    (m_bvalid),
        .bready    (m_bready),
        .dma_start (dma_start),
        .src_addr  (src_addr),
        .dst_addr  (dst_addr),
        .xfer_len  (xfer_len),
        .dma_done  (dma_done)
    );

/* verilator lint_on UNUSED */
endmodule
