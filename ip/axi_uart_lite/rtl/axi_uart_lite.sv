// AXI4-Lite UART Lite — simple TX/RX with loopback for simulation
/* verilator lint_off UNUSED */
module axi_uart_lite #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter FIFO_DEPTH = 16
)(
    input  logic                    clk,
    input  logic                    rst_n,

    // AXI4-Lite Slave
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

    // External UART pins (directly usable or loopback)
    output logic                    uart_tx,
    input  logic                    uart_rx,
    output logic                    irq
);

    // Register map (byte offsets):
    //   0x00: TX_DATA  (W)  — write byte to transmit
    //   0x04: RX_DATA  (R)  — read received byte
    //   0x08: STATUS   (R)  — [0] tx_full, [1] rx_empty, [2] rx_valid
    //   0x0C: CONTROL  (RW) — [0] irq_en (rx data available interrupt)

    localparam ADDR_LSB = $clog2(DATA_WIDTH / 8);

    // ---------------------------------------------------------------
    // Internal TX/RX FIFO (simple shift-register FIFO for sim)
    // ---------------------------------------------------------------
    logic [7:0]  tx_fifo [FIFO_DEPTH];
    logic [$clog2(FIFO_DEPTH):0] tx_wr_ptr_q, tx_rd_ptr_q;
    logic tx_full, tx_empty;

    logic [7:0]  rx_fifo [FIFO_DEPTH];
    logic [$clog2(FIFO_DEPTH):0] rx_wr_ptr_q, rx_rd_ptr_q;
    logic rx_full, rx_empty;

    assign tx_full  = (tx_wr_ptr_q - tx_rd_ptr_q) == FIFO_DEPTH[$clog2(FIFO_DEPTH):0];
    assign tx_empty = (tx_wr_ptr_q == tx_rd_ptr_q);
    assign rx_full  = (rx_wr_ptr_q - rx_rd_ptr_q) == FIFO_DEPTH[$clog2(FIFO_DEPTH):0];
    assign rx_empty = (rx_wr_ptr_q == rx_rd_ptr_q);

    // Control register
    logic irq_en_q;

    // ---------------------------------------------------------------
    // Loopback: TX FIFO → RX FIFO (for simulation)
    // In real hardware this would be replaced by actual UART TX/RX logic
    // ---------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_rd_ptr_q <= '0;
            rx_wr_ptr_q <= '0;
        end else begin
            if (!tx_empty && !rx_full) begin
                rx_fifo[rx_wr_ptr_q[$clog2(FIFO_DEPTH)-1:0]] <= tx_fifo[tx_rd_ptr_q[$clog2(FIFO_DEPTH)-1:0]];
                tx_rd_ptr_q <= tx_rd_ptr_q + 1;
                rx_wr_ptr_q <= rx_wr_ptr_q + 1;
            end
        end
    end

    assign uart_tx = 1'b1; // idle high (placeholder)
    assign irq = irq_en_q && !rx_empty;

    // ---------------------------------------------------------------
    // Write channel
    // ---------------------------------------------------------------
    logic aw_done_q, w_done_q;
    logic [ADDR_WIDTH-1:0] awaddr_q;
    logic [DATA_WIDTH-1:0] wdata_q;
    logic s_bvalid_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            aw_done_q   <= 1'b0;
            w_done_q    <= 1'b0;
            awaddr_q    <= '0;
            wdata_q     <= '0;
            s_bvalid_q  <= 1'b0;
            tx_wr_ptr_q <= '0;
            irq_en_q    <= 1'b0;
        end else begin
            // Accept AW
            if (s_awvalid && !aw_done_q && !s_bvalid_q) begin
                aw_done_q <= 1'b1;
                awaddr_q  <= s_awaddr;
            end
            // Accept W
            if (s_wvalid && !w_done_q && !s_bvalid_q) begin
                w_done_q <= 1'b1;
                wdata_q  <= s_wdata;
            end
            // Perform write when both received (guard with !s_bvalid_q to prevent double-fire)
            if (!s_bvalid_q &&
                (aw_done_q || (s_awvalid && !aw_done_q)) &&
                (w_done_q  || (s_wvalid  && !w_done_q))) begin
                s_bvalid_q <= 1'b1;
                // Determine effective address
                if (aw_done_q ? (awaddr_q[ADDR_LSB+1:ADDR_LSB] == 2'b00) : (s_awaddr[ADDR_LSB+1:ADDR_LSB] == 2'b00)) begin
                    // TX_DATA write
                    if (!tx_full) begin
                        tx_fifo[tx_wr_ptr_q[$clog2(FIFO_DEPTH)-1:0]] <= w_done_q ? wdata_q[7:0] : s_wdata[7:0];
                        tx_wr_ptr_q <= tx_wr_ptr_q + 1;
                    end
                end else if (aw_done_q ? (awaddr_q[ADDR_LSB+1:ADDR_LSB] == 2'b11) : (s_awaddr[ADDR_LSB+1:ADDR_LSB] == 2'b11)) begin
                    // CONTROL write
                    irq_en_q <= w_done_q ? wdata_q[0] : s_wdata[0];
                end
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
            s_rvalid_q  <= 1'b0;
            s_rdata_q   <= '0;
            rx_rd_ptr_q <= '0;
        end else begin
            if (s_arvalid && !s_rvalid_q) begin
                s_rvalid_q <= 1'b1;
                case (s_araddr[ADDR_LSB+1:ADDR_LSB])
                    2'b00: s_rdata_q <= '0; // TX_DATA not readable
                    2'b01: begin
                        // RX_DATA
                        if (!rx_empty) begin
                            s_rdata_q   <= {{(DATA_WIDTH-8){1'b0}}, rx_fifo[rx_rd_ptr_q[$clog2(FIFO_DEPTH)-1:0]]};
                            rx_rd_ptr_q <= rx_rd_ptr_q + 1;
                        end else begin
                            s_rdata_q <= '0;
                        end
                    end
                    2'b10: begin
                        // STATUS
                        s_rdata_q <= {{(DATA_WIDTH-3){1'b0}}, !rx_empty, rx_empty, tx_full};
                    end
                    2'b11: begin
                        // CONTROL
                        s_rdata_q <= {{(DATA_WIDTH-1){1'b0}}, irq_en_q};
                    end
                endcase
            end
            if (s_rvalid_q && s_rready) begin
                s_rvalid_q <= 1'b0;
            end
        end
    end

    assign s_arready = !s_rvalid_q;
    assign s_rvalid  = s_rvalid_q;
    assign s_rdata   = s_rdata_q;
    assign s_rresp   = 2'b00;

/* verilator lint_on UNUSED */
endmodule
