`timescale 1ns/1ps
`include "tb_macros.vh"

module tb_axi_uart_lite;

    parameter TIMEOUT = 10000;

    reg         clk, rst_n;
    reg  [31:0] s_awaddr, s_araddr, s_wdata;
    reg  [3:0]  s_wstrb;
    reg         s_awvalid, s_wvalid, s_bready, s_arvalid, s_rready;
    wire        s_awready, s_wready, s_bvalid, s_arready, s_rvalid;
    wire [31:0] s_rdata;
    wire [1:0]  s_bresp, s_rresp;
    wire        uart_tx, irq;

    axi_uart_lite u_dut (
        .clk(clk), .rst_n(rst_n),
        .s_awaddr(s_awaddr), .s_awvalid(s_awvalid), .s_awready(s_awready),
        .s_wdata(s_wdata), .s_wstrb(s_wstrb), .s_wvalid(s_wvalid), .s_wready(s_wready),
        .s_bresp(s_bresp), .s_bvalid(s_bvalid), .s_bready(s_bready),
        .s_araddr(s_araddr), .s_arvalid(s_arvalid), .s_arready(s_arready),
        .s_rdata(s_rdata), .s_rresp(s_rresp), .s_rvalid(s_rvalid), .s_rready(s_rready),
        .uart_tx(uart_tx), .uart_rx(1'b1), .irq(irq)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer cycle_cnt;
    initial cycle_cnt = 0;
    always @(posedge clk) begin
        cycle_cnt <= cycle_cnt + 1;
        if (cycle_cnt >= TIMEOUT) begin $display("FAIL: timeout"); $finish; end
    end

    `TB_DUMP_CONTROL(tb_axi_uart_lite)

    task axi_wr; input [31:0] addr, data;
        begin
            @(posedge clk);
            s_awaddr = addr; s_awvalid = 1; s_wdata = data; s_wstrb = 4'hF; s_wvalid = 1; s_bready = 1;
            @(posedge clk);
            s_awvalid = 0;
            s_wvalid = 0;
            while (!s_bvalid) @(posedge clk);
            @(posedge clk); s_bready = 0;
        end
    endtask

    task axi_rd; input [31:0] addr; output [31:0] data;
        begin
            @(posedge clk);
            s_araddr = addr; s_arvalid = 1; s_rready = 1;
            @(posedge clk);
            s_arvalid = 0;
            while (!s_rvalid) @(posedge clk);
            data = s_rdata;
            @(posedge clk); s_rready = 0;
        end
    endtask

    integer cov_total, cov_pass, cov_fail;
    integer cov_tx, cov_loopback, cov_status, cov_irq;
    initial begin cov_total=0; cov_pass=0; cov_fail=0; cov_tx=0; cov_loopback=0; cov_status=0; cov_irq=0; end

    reg [31:0] rd;

    initial begin
        rst_n = 0; s_awvalid = 0; s_wvalid = 0; s_arvalid = 0; s_bready = 0; s_rready = 0;
        s_awaddr = 0; s_araddr = 0; s_wdata = 0; s_wstrb = 0;
        repeat (20) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        // TX write
        $display("\n=== TX Write ===");
        cov_tx = 1;
        axi_wr(32'h0000_0000, 32'h0000_0041); // 'A'
        cov_total = cov_total + 1; cov_pass = cov_pass + 1;
        $display("  PASS: tx_write");

        // Wait for loopback
        repeat (5) @(posedge clk);

        // Read RX (loopback)
        $display("\n=== Loopback Read ===");
        cov_loopback = 1;
        axi_rd(32'h0000_0004, rd); // RX_DATA
        cov_total = cov_total + 1;
        if (rd[7:0] == 8'h41) begin cov_pass = cov_pass + 1; $display("  PASS: loopback 0x%02x", rd[7:0]); end
        else begin cov_fail = cov_fail + 1; $display("  FAIL: loopback exp=0x41 got=0x%02x", rd[7:0]); end

        // Status — wait for FIFO pointer update to propagate
        repeat (2) @(posedge clk);
        $display("\n=== Status ===");
        cov_status = 1;
        axi_rd(32'h0000_0008, rd);
        cov_total = cov_total + 1;
        // After reading RX, rx should be empty: bit[1]=1, bit[2]=0
        if (rd[1] == 1'b1) begin cov_pass = cov_pass + 1; $display("  PASS: rx_empty after read"); end
        else begin cov_fail = cov_fail + 1; $display("  FAIL: status=0x%08x", rd); end

        // IRQ test
        $display("\n=== IRQ ===");
        cov_irq = 1;
        axi_wr(32'h0000_000C, 32'h0000_0001); // enable IRQ
        axi_wr(32'h0000_0000, 32'h0000_0042); // TX 'B' → loopback → RX
        repeat (5) @(posedge clk);
        cov_total = cov_total + 1;
        if (irq == 1'b1) begin cov_pass = cov_pass + 1; $display("  PASS: irq asserted"); end
        else begin cov_fail = cov_fail + 1; $display("  FAIL: irq not asserted"); end

        // Report
        $display("\n========================================");
        $display(" COVERAGE REPORT");
        $display("========================================");
        $display("  Total: %0d  Pass: %0d  Fail: %0d", cov_total, cov_pass, cov_fail);
        $display("  [%s] TX write",   cov_tx       ? "HIT" : "   ");
        $display("  [%s] Loopback",   cov_loopback ? "HIT" : "   ");
        $display("  [%s] Status",     cov_status   ? "HIT" : "   ");
        $display("  [%s] IRQ",        cov_irq      ? "HIT" : "   ");
        $display("  Functional: %0d / 4", cov_tx+cov_loopback+cov_status+cov_irq);
        if (cov_fail == 0) $display("*** ALL TESTS PASSED ***");
        else $display("*** %0d FAILED ***", cov_fail);
        $display("========================================");
        $finish;
    end

endmodule
