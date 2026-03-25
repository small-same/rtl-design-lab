`timescale 1ns/1ps
`include "tb_macros.vh"

module tb_axi_dma;

    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 32;
    parameter TIMEOUT    = 50000;

    reg                    clk;
    reg                    rst_n;
    // AXI Write Address Channel
    wire [ADDR_WIDTH-1:0]  awaddr;
    wire [7:0]             awlen;
    wire                   awvalid;
    reg                    awready;
    // AXI Write Data Channel
    wire [DATA_WIDTH-1:0]  wdata;
    wire                   wlast;
    wire                   wvalid;
    reg                    wready;
    // AXI Write Response Channel
    reg  [1:0]             bresp;
    reg                    bvalid;
    wire                   bready;
    // Control
    reg                    dma_start;
    reg  [ADDR_WIDTH-1:0]  src_addr;
    reg  [ADDR_WIDTH-1:0]  dst_addr;
    reg  [15:0]            xfer_len;
    wire                   dma_done;

    // ----------------------------------------------------------------
    // Coverage counters
    // ----------------------------------------------------------------
    integer cov_total_tests;
    integer cov_passed_tests;
    integer cov_failed_tests;
    // Functional coverage flags
    integer cov_single_beat;        // xfer_len = 1
    integer cov_short_burst;        // xfer_len < 16
    integer cov_exact_max_burst;    // xfer_len = 256
    integer cov_multi_burst;        // xfer_len > 256
    integer cov_backpressure_w;     // wready deasserted during transfer
    integer cov_backpressure_aw;    // awready delayed
    integer cov_bresp_delay;        // bvalid delayed after wlast
    integer cov_back_to_back;       // consecutive transfers
    integer cov_zero_len;           // xfer_len = 0 (should not start)
    // Signal toggle coverage
    integer cov_wlast_toggled;
    integer cov_dma_done_toggled;
    integer cov_awvalid_toggled;
    // FSM state coverage
    integer cov_st_idle_hit;
    integer cov_st_addr_hit;
    integer cov_st_data_hit;
    integer cov_st_wresp_hit;
    integer cov_st_done_hit;
    // Beat count tracking
    integer total_beats_transferred;

    initial begin
        cov_total_tests      = 0;
        cov_passed_tests     = 0;
        cov_failed_tests     = 0;
        cov_single_beat      = 0;
        cov_short_burst      = 0;
        cov_exact_max_burst  = 0;
        cov_multi_burst      = 0;
        cov_backpressure_w   = 0;
        cov_backpressure_aw  = 0;
        cov_bresp_delay      = 0;
        cov_back_to_back     = 0;
        cov_zero_len         = 0;
        cov_wlast_toggled    = 0;
        cov_dma_done_toggled = 0;
        cov_awvalid_toggled  = 0;
        cov_st_idle_hit      = 0;
        cov_st_addr_hit      = 0;
        cov_st_data_hit      = 0;
        cov_st_wresp_hit     = 0;
        cov_st_done_hit      = 0;
        total_beats_transferred = 0;
    end

    // ----------------------------------------------------------------
    // DUT
    // ----------------------------------------------------------------
    axi_dma_core #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .awaddr    (awaddr),
        .awlen     (awlen),
        .awvalid   (awvalid),
        .awready   (awready),
        .wdata     (wdata),
        .wlast     (wlast),
        .wvalid    (wvalid),
        .wready    (wready),
        .bresp     (bresp),
        .bvalid    (bvalid),
        .bready    (bready),
        .dma_start (dma_start),
        .src_addr  (src_addr),
        .dst_addr  (dst_addr),
        .xfer_len  (xfer_len),
        .dma_done  (dma_done)
    );

    // ----------------------------------------------------------------
    // Clock: 10 ns period
    // ----------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // ----------------------------------------------------------------
    // FSM state coverage sampling
    // ----------------------------------------------------------------
    always @(posedge clk) begin
        if (rst_n) begin
            case (u_dut.state_q)
                3'b000: cov_st_idle_hit  = 1;
                3'b001: cov_st_addr_hit  = 1;
                3'b010: cov_st_data_hit  = 1;
                3'b011: cov_st_wresp_hit = 1;
                3'b100: cov_st_done_hit  = 1;
            endcase
        end
    end

    // Toggle coverage sampling
    always @(posedge clk) begin
        if (wlast)    cov_wlast_toggled    = 1;
        if (dma_done) cov_dma_done_toggled = 1;
        if (awvalid)  cov_awvalid_toggled  = 1;
    end

    // Beat counter
    always @(posedge clk) begin
        if (wvalid && wready)
            total_beats_transferred = total_beats_transferred + 1;
    end

    // ----------------------------------------------------------------
    // Configurable AXI slave behavior
    // ----------------------------------------------------------------
    reg        awready_mode;   // 0: delayed, 1: immediate
    reg        wready_mode;    // 0: always high, 1: random backpressure
    reg [3:0]  bresp_delay;    // cycles to delay bvalid after wlast

    reg awvalid_d1;
    reg wlast_seen;
    reg [3:0] bresp_cnt;

    // awready logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            awready    <= 1'b0;
            awvalid_d1 <= 1'b0;
        end else if (awready_mode) begin
            awready <= awvalid;
        end else begin
            awvalid_d1 <= awvalid;
            awready    <= awvalid & awvalid_d1;
        end
    end

    // wready logic with backpressure
    reg [7:0] wready_lfsr;
    initial wready_lfsr = 8'hA5;
    always @(posedge clk) begin
        wready_lfsr <= {wready_lfsr[6:0], wready_lfsr[7] ^ wready_lfsr[5]};
    end

    always @(*) begin
        if (wready_mode)
            wready = wready_lfsr[0];
        else
            wready = 1'b1;
    end

    // bvalid logic with configurable delay
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bvalid     <= 1'b0;
            bresp      <= 2'b00;
            wlast_seen <= 1'b0;
            bresp_cnt  <= 4'd0;
        end else begin
            if (wvalid && wready && wlast) begin
                if (bresp_delay == 4'd0) begin
                    bvalid <= 1'b1;
                    bresp  <= 2'b00;
                end else begin
                    wlast_seen <= 1'b1;
                    bresp_cnt  <= 4'd0;
                end
            end else if (wlast_seen) begin
                if (bresp_cnt >= bresp_delay - 1) begin
                    bvalid     <= 1'b1;
                    bresp      <= 2'b00;
                    wlast_seen <= 1'b0;
                end else begin
                    bresp_cnt <= bresp_cnt + 4'd1;
                end
            end else if (bvalid && bready) begin
                bvalid <= 1'b0;
            end
        end
    end

    // ----------------------------------------------------------------
    // Timeout
    // ----------------------------------------------------------------
    integer cycle_cnt;
    initial cycle_cnt = 0;
    always @(posedge clk) begin
        cycle_cnt <= cycle_cnt + 1;
        if (cycle_cnt >= TIMEOUT) begin
            $display("FAIL: global timeout after %0d cycles", TIMEOUT);
            $finish;
        end
    end

    // ----------------------------------------------------------------
    // VCD dump
    // ----------------------------------------------------------------
    `TB_DUMP_CONTROL(tb_axi_dma)

    // ----------------------------------------------------------------
    // Task: run one DMA transfer and check result
    // ----------------------------------------------------------------
    task run_dma_xfer;
        input [ADDR_WIDTH-1:0] t_src;
        input [ADDR_WIDTH-1:0] t_dst;
        input [15:0]           t_len;
        input integer          t_timeout;
        input [63:0]           t_name_0; // test name (8 chars max)
        integer wait_cnt;
        begin
            cov_total_tests = cov_total_tests + 1;
            src_addr  = t_src;
            dst_addr  = t_dst;
            xfer_len  = t_len;
            @(posedge clk);
            dma_start = 1'b1;
            @(posedge clk);
            dma_start = 1'b0;

            // Wait for dma_done or timeout
            wait_cnt = 0;
            while (dma_done !== 1'b1 && wait_cnt < t_timeout) begin
                @(posedge clk);
                wait_cnt = wait_cnt + 1;
            end

            if (dma_done === 1'b1) begin
                cov_passed_tests = cov_passed_tests + 1;
                $display("  PASS: test xfer_len=%0d completed in %0d cycles",
                         t_len, wait_cnt);
            end else begin
                cov_failed_tests = cov_failed_tests + 1;
                $display("  FAIL: test xfer_len=%0d timeout after %0d cycles",
                         t_len, wait_cnt);
            end

            // Wait for DUT to return to IDLE
            repeat (5) @(posedge clk);
        end
    endtask

    // ----------------------------------------------------------------
    // Task: check zero-length transfer does NOT start
    // ----------------------------------------------------------------
    task run_zero_len_test;
        integer wait_cnt;
        begin
            cov_total_tests = cov_total_tests + 1;
            cov_zero_len = 1;
            src_addr  = 32'h0000_1000;
            dst_addr  = 32'h0000_2000;
            xfer_len  = 16'd0;
            @(posedge clk);
            dma_start = 1'b1;
            @(posedge clk);
            dma_start = 1'b0;

            // DMA should NOT assert dma_done (nothing to transfer)
            // Wait a few cycles and verify state stays IDLE
            repeat (10) @(posedge clk);
            if (dma_done === 1'b0 && u_dut.state_q == 3'b000) begin
                cov_passed_tests = cov_passed_tests + 1;
                $display("  PASS: zero-length correctly ignored");
            end else begin
                cov_failed_tests = cov_failed_tests + 1;
                $display("  FAIL: zero-length should not start DMA (state=%b, done=%b)",
                         u_dut.state_q, dma_done);
            end
            repeat (5) @(posedge clk);
        end
    endtask

    // ----------------------------------------------------------------
    // Main test sequence
    // ----------------------------------------------------------------
    initial begin
        // Init
        rst_n          = 1'b0;
        dma_start      = 1'b0;
        src_addr       = 32'd0;
        dst_addr       = 32'd0;
        xfer_len       = 16'd0;
        awready_mode   = 1'b0;
        wready_mode    = 1'b0;
        bresp_delay    = 4'd0;

        // Hold reset for 20 cycles
        repeat (20) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        // ==============================================================
        $display("");
        $display("========================================");
        $display(" TEST GROUP 1: Basic Transfers");
        $display("========================================");

        // Test 1.1: Single beat (xfer_len = 1)
        $display("[1.1] Single beat transfer");
        awready_mode = 1'b0; wready_mode = 1'b0; bresp_delay = 4'd0;
        cov_single_beat = 1;
        run_dma_xfer(32'h1000, 32'h2000, 16'd1, 500, "single");

        // Test 1.2: Short burst (xfer_len = 4)
        $display("[1.2] Short burst (len=4)");
        cov_short_burst = 1;
        run_dma_xfer(32'h1000, 32'h2000, 16'd4, 500, "short4");

        // Test 1.3: Medium burst (xfer_len = 8)
        $display("[1.3] Medium burst (len=8)");
        run_dma_xfer(32'h1000, 32'h2000, 16'd8, 500, "med8");

        // Test 1.4: Max single burst (xfer_len = 256)
        $display("[1.4] Max single burst (len=256)");
        cov_exact_max_burst = 1;
        run_dma_xfer(32'h1000, 32'h2000, 16'd256, 5000, "max256");

        // ==============================================================
        $display("");
        $display("========================================");
        $display(" TEST GROUP 2: Multi-burst Transfers");
        $display("========================================");

        // Test 2.1: Just over max burst (xfer_len = 257)
        $display("[2.1] Multi-burst (len=257)");
        cov_multi_burst = 1;
        run_dma_xfer(32'h1000, 32'h2000, 16'd257, 5000, "mb257");

        // Test 2.2: Two full bursts (xfer_len = 512)
        $display("[2.2] Two full bursts (len=512)");
        run_dma_xfer(32'h1000, 32'h2000, 16'd512, 10000, "mb512");

        // ==============================================================
        $display("");
        $display("========================================");
        $display(" TEST GROUP 3: Edge Cases");
        $display("========================================");

        // Test 3.1: Zero-length transfer (should not start)
        $display("[3.1] Zero-length transfer");
        run_zero_len_test();

        // Test 3.2: xfer_len = 2
        $display("[3.2] Minimal multi-beat (len=2)");
        run_dma_xfer(32'h1000, 32'h2000, 16'd2, 500, "len2");

        // Test 3.3: xfer_len = 255
        $display("[3.3] One less than max burst (len=255)");
        run_dma_xfer(32'h1000, 32'h2000, 16'd255, 5000, "len255");

        // ==============================================================
        $display("");
        $display("========================================");
        $display(" TEST GROUP 4: Backpressure (wready)");
        $display("========================================");

        // Test 4.1: Random wready backpressure, short burst
        $display("[4.1] Backpressure wready, len=8");
        wready_mode = 1'b1;
        cov_backpressure_w = 1;
        run_dma_xfer(32'h3000, 32'h4000, 16'd8, 2000, "bp_w8");

        // Test 4.2: Backpressure with longer burst
        $display("[4.2] Backpressure wready, len=64");
        run_dma_xfer(32'h3000, 32'h4000, 16'd64, 5000, "bp_w64");
        wready_mode = 1'b0;

        // ==============================================================
        $display("");
        $display("========================================");
        $display(" TEST GROUP 5: awready Variations");
        $display("========================================");

        // Test 5.1: Immediate awready
        $display("[5.1] Immediate awready, len=8");
        awready_mode = 1'b1;
        cov_backpressure_aw = 1;
        run_dma_xfer(32'h5000, 32'h6000, 16'd8, 500, "aw_imm");

        // Test 5.2: Delayed awready (default mode)
        $display("[5.2] Delayed awready, len=16");
        awready_mode = 1'b0;
        run_dma_xfer(32'h5000, 32'h6000, 16'd16, 1000, "aw_del");
        awready_mode = 1'b0;

        // ==============================================================
        $display("");
        $display("========================================");
        $display(" TEST GROUP 6: Write Response Delay");
        $display("========================================");

        // Test 6.1: bresp delayed by 3 cycles
        $display("[6.1] bresp delay=3, len=8");
        bresp_delay = 4'd3;
        cov_bresp_delay = 1;
        run_dma_xfer(32'h7000, 32'h8000, 16'd8, 1000, "bd3");

        // Test 6.2: bresp delayed by 8 cycles
        $display("[6.2] bresp delay=8, len=4");
        bresp_delay = 4'd8;
        run_dma_xfer(32'h7000, 32'h8000, 16'd4, 1000, "bd8");
        bresp_delay = 4'd0;

        // ==============================================================
        $display("");
        $display("========================================");
        $display(" TEST GROUP 7: Back-to-Back Transfers");
        $display("========================================");

        // Test 7.1: Two consecutive transfers
        $display("[7.1] Back-to-back, len=4 then len=8");
        cov_back_to_back = 1;
        run_dma_xfer(32'hA000, 32'hB000, 16'd4, 500, "b2b_1");
        // Start next immediately (no extra gap)
        run_dma_xfer(32'hC000, 32'hD000, 16'd8, 500, "b2b_2");

        // ==============================================================
        $display("");
        $display("========================================");
        $display(" TEST GROUP 8: Combined Stress");
        $display("========================================");

        // Test 8.1: Backpressure + delayed bresp + multi-burst
        $display("[8.1] Stress: backpressure + bresp_delay + multi-burst");
        wready_mode  = 1'b1;
        bresp_delay  = 4'd5;
        awready_mode = 1'b0;
        run_dma_xfer(32'hE000, 32'hF000, 16'd300, 15000, "stress");
        wready_mode  = 1'b0;
        bresp_delay  = 4'd0;

        // ==============================================================
        // Coverage Report
        // ==============================================================
        $display("");
        $display("========================================");
        $display(" COVERAGE REPORT");
        $display("========================================");
        $display("");
        $display("--- Test Summary ---");
        $display("  Total tests:   %0d", cov_total_tests);
        $display("  Passed:        %0d", cov_passed_tests);
        $display("  Failed:        %0d", cov_failed_tests);
        $display("  Pass rate:     %0d%%",
                 (cov_total_tests > 0) ? (cov_passed_tests * 100 / cov_total_tests) : 0);
        $display("");
        $display("--- Functional Coverage ---");
        $display("  [%s] Single beat (len=1)",       cov_single_beat      ? "HIT" : "   ");
        $display("  [%s] Short burst (len<16)",      cov_short_burst      ? "HIT" : "   ");
        $display("  [%s] Exact max burst (len=256)", cov_exact_max_burst  ? "HIT" : "   ");
        $display("  [%s] Multi-burst (len>256)",     cov_multi_burst      ? "HIT" : "   ");
        $display("  [%s] wready backpressure",       cov_backpressure_w   ? "HIT" : "   ");
        $display("  [%s] awready variation",         cov_backpressure_aw  ? "HIT" : "   ");
        $display("  [%s] bresp delay",               cov_bresp_delay      ? "HIT" : "   ");
        $display("  [%s] Back-to-back transfers",    cov_back_to_back     ? "HIT" : "   ");
        $display("  [%s] Zero-length rejection",     cov_zero_len         ? "HIT" : "   ");
        $display("  Functional coverage: %0d / 9",
                 cov_single_beat + cov_short_burst + cov_exact_max_burst +
                 cov_multi_burst + cov_backpressure_w + cov_backpressure_aw +
                 cov_bresp_delay + cov_back_to_back + cov_zero_len);
        $display("");
        $display("--- Toggle Coverage ---");
        $display("  [%s] wlast toggled",             cov_wlast_toggled    ? "HIT" : "   ");
        $display("  [%s] dma_done toggled",          cov_dma_done_toggled ? "HIT" : "   ");
        $display("  [%s] awvalid toggled",           cov_awvalid_toggled  ? "HIT" : "   ");
        $display("  Toggle coverage: %0d / 3",
                 cov_wlast_toggled + cov_dma_done_toggled + cov_awvalid_toggled);
        $display("");
        $display("--- FSM State Coverage ---");
        $display("  [%s] ST_IDLE",                   cov_st_idle_hit  ? "HIT" : "   ");
        $display("  [%s] ST_ADDR",                   cov_st_addr_hit  ? "HIT" : "   ");
        $display("  [%s] ST_DATA",                   cov_st_data_hit  ? "HIT" : "   ");
        $display("  [%s] ST_WRESP",                  cov_st_wresp_hit ? "HIT" : "   ");
        $display("  [%s] ST_DONE",                   cov_st_done_hit  ? "HIT" : "   ");
        $display("  FSM coverage: %0d / 5",
                 cov_st_idle_hit + cov_st_addr_hit + cov_st_data_hit +
                 cov_st_wresp_hit + cov_st_done_hit);
        $display("");
        $display("--- Data Transfer ---");
        $display("  Total beats transferred: %0d", total_beats_transferred);
        $display("");

        if (cov_failed_tests == 0)
            $display("*** ALL TESTS PASSED ***");
        else
            $display("*** %0d TEST(S) FAILED ***", cov_failed_tests);

        $display("========================================");
        $finish;
    end

endmodule
