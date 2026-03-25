// AXI DMA Core — memory-to-memory DMA engine with AXI4 write channel
/* verilator lint_off UNUSED */
module axi_dma_core #(
    parameter DATA_WIDTH    = 32,
    parameter ADDR_WIDTH    = 32,
    parameter MAX_BURST_LEN = 256,
    parameter FIFO_DEPTH    = 16
)(
    input  logic                    clk,
    input  logic                    rst_n,
    // AXI Write Address Channel
    output logic [ADDR_WIDTH-1:0]   awaddr,
    output logic [7:0]              awlen,
    output logic                    awvalid,
    input  logic                    awready,
    // AXI Write Data Channel
    output logic [DATA_WIDTH-1:0]   wdata,
    output logic                    wlast,
    output logic                    wvalid,
    input  logic                    wready,
    // AXI Write Response Channel
    input  logic [1:0]              bresp,
    input  logic                    bvalid,
    output logic                    bready,
    // Control
    input  logic                    dma_start,
    input  logic [ADDR_WIDTH-1:0]   src_addr,
    input  logic [ADDR_WIDTH-1:0]   dst_addr,
    input  logic [15:0]             xfer_len,
    output logic                    dma_done
);

    // ---------------------------------------------------------------
    // State encoding
    // ---------------------------------------------------------------
    localparam [2:0] ST_IDLE  = 3'b000,
                     ST_ADDR  = 3'b001,
                     ST_DATA  = 3'b010,
                     ST_WRESP = 3'b011,
                     ST_DONE  = 3'b100;

    logic [2:0] state_q, state_d;

    // ---------------------------------------------------------------
    // Internal registers
    // ---------------------------------------------------------------
    logic [15:0]            beat_cnt_q,    beat_cnt_d;
    logic [15:0]            remaining_q,   remaining_d;   // beats left across bursts
    logic [ADDR_WIDTH-1:0]  awaddr_q,      awaddr_d;
    logic [7:0]             awlen_q,       awlen_d;
    logic                   awvalid_q,     awvalid_d;
    logic [DATA_WIDTH-1:0]  wdata_q,       wdata_d;
    logic                   wvalid_q,      wvalid_d;
    logic                   wlast_q,       wlast_d;
    logic                   bready_q,      bready_d;
    logic                   dma_done_q,    dma_done_d;

    // Burst length capped to AXI4 max (256 beats = awlen 255)
    localparam AXI_MAX_BURST = (MAX_BURST_LEN > 256) ? 256 : MAX_BURST_LEN;

    // ---------------------------------------------------------------
    // Combinational next-state & output logic
    // ---------------------------------------------------------------
    always_comb begin
        // Defaults — hold current value (prevents latches)
        state_d     = state_q;
        beat_cnt_d  = beat_cnt_q;
        remaining_d = remaining_q;
        awaddr_d    = awaddr_q;
        awlen_d     = awlen_q;
        awvalid_d   = awvalid_q;
        wdata_d     = wdata_q;
        wvalid_d    = wvalid_q;
        wlast_d     = wlast_q;
        bready_d    = bready_q;
        dma_done_d  = dma_done_q;

        case (state_q)
            ST_IDLE: begin
                dma_done_d = 1'b0;
                if (dma_start && (xfer_len != 16'd0)) begin
                    state_d     = ST_ADDR;
                    remaining_d = xfer_len;
                    awaddr_d    = dst_addr;
                    // Compute burst length for first burst
                    if (xfer_len > AXI_MAX_BURST[15:0]) begin
                        awlen_d = AXI_MAX_BURST[7:0] - 8'd1;
                    end else begin
                        awlen_d = xfer_len[7:0] - 8'd1;
                    end
                    awvalid_d = 1'b1;
                end
            end

            ST_ADDR: begin
                if (awready) begin
                    awvalid_d  = 1'b0;
                    state_d    = ST_DATA;
                    wvalid_d   = 1'b1;
                    beat_cnt_d = 16'd0;
                    // Assert wlast immediately if single-beat burst
                    wlast_d    = (awlen_q == 8'd0) ? 1'b1 : 1'b0;
                    wdata_d    = {{(DATA_WIDTH-16){1'b0}}, 16'd0};
                end
            end

            ST_DATA: begin
                if (wready) begin
                    beat_cnt_d = beat_cnt_q + 16'd1;
                    wdata_d    = {{(DATA_WIDTH-16){1'b0}}, beat_cnt_q + 16'd1};
                    if (beat_cnt_q == {8'd0, awlen_q}) begin
                        // Last beat accepted
                        wvalid_d   = 1'b0;
                        wlast_d    = 1'b0;
                        bready_d   = 1'b1;
                        state_d    = ST_WRESP;
                    end else if (beat_cnt_q + 16'd1 == {8'd0, awlen_q}) begin
                        wlast_d = 1'b1;
                    end
                end
            end

            ST_WRESP: begin
                if (bvalid) begin
                    bready_d    = 1'b0;
                    remaining_d = remaining_q - ({8'd0, awlen_q} + 16'd1);
                    if (remaining_q <= ({8'd0, awlen_q} + 16'd1)) begin
                        // Transfer complete
                        state_d    = ST_DONE;
                        dma_done_d = 1'b1;
                    end else begin
                        // More bursts needed
                        state_d  = ST_ADDR;
                        awaddr_d = awaddr_q + (({{(ADDR_WIDTH-8){1'b0}}, awlen_q} + 1) * (DATA_WIDTH / 8));
                        if ((remaining_q - ({8'd0, awlen_q} + 16'd1)) > AXI_MAX_BURST[15:0]) begin
                            awlen_d = AXI_MAX_BURST[7:0] - 8'd1;
                        end else begin
                            awlen_d = remaining_q[7:0] - awlen_q - 8'd2;
                        end
                        awvalid_d = 1'b1;
                    end
                end
            end

            ST_DONE: begin
                dma_done_d = 1'b0;
                state_d    = ST_IDLE;
            end

            default: begin
                state_d = ST_IDLE;
            end
        endcase
    end

    // ---------------------------------------------------------------
    // Sequential — async assert, sync deassert reset
    // ---------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q     <= ST_IDLE;
            beat_cnt_q  <= 16'd0;
            remaining_q <= 16'd0;
            awaddr_q    <= '0;
            awlen_q     <= 8'd0;
            awvalid_q   <= 1'b0;
            wdata_q     <= '0;
            wvalid_q    <= 1'b0;
            wlast_q     <= 1'b0;
            bready_q    <= 1'b0;
            dma_done_q  <= 1'b0;
        end else begin
            state_q     <= state_d;
            beat_cnt_q  <= beat_cnt_d;
            remaining_q <= remaining_d;
            awaddr_q    <= awaddr_d;
            awlen_q     <= awlen_d;
            awvalid_q   <= awvalid_d;
            wdata_q     <= wdata_d;
            wvalid_q    <= wvalid_d;
            wlast_q     <= wlast_d;
            bready_q    <= bready_d;
            dma_done_q  <= dma_done_d;
        end
    end

    // ---------------------------------------------------------------
    // Output assignments
    // ---------------------------------------------------------------
    assign awaddr  = awaddr_q;
    assign awlen   = awlen_q;
    assign awvalid = awvalid_q;
    assign wdata   = wdata_q;
    assign wvalid  = wvalid_q;
    assign wlast   = wlast_q;
    assign bready  = bready_q;
    assign dma_done = dma_done_q;

/* verilator lint_on UNUSED */
endmodule
