`timescale 1ns/1ps
`include "tb_macros.vh"

module tb_axi_timer;

    parameter TIMEOUT = 20000;

    reg         clk, rst_n;
    reg  [31:0] s_awaddr, s_araddr, s_wdata;
    reg  [3:0]  s_wstrb;
    reg         s_awvalid, s_wvalid, s_bready, s_arvalid, s_rready;
    wire        s_awready, s_wready, s_bvalid, s_arready, s_rvalid;
    wire [31:0] s_rdata;
    wire [1:0]  s_bresp, s_rresp;
    wire        irq;

    axi_timer u_dut (
        .clk(clk), .rst_n(rst_n),
        .s_awaddr(s_awaddr), .s_awvalid(s_awvalid), .s_awready(s_awready),
        .s_wdata(s_wdata), .s_wstrb(s_wstrb), .s_wvalid(s_wvalid), .s_wready(s_wready),
        .s_bresp(s_bresp), .s_bvalid(s_bvalid), .s_bready(s_bready),
        .s_araddr(s_araddr), .s_arvalid(s_arvalid), .s_arready(s_arready),
        .s_rdata(s_rdata), .s_rresp(s_rresp), .s_rvalid(s_rvalid), .s_rready(s_rready),
        .irq(irq)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer cycle_cnt;
    initial cycle_cnt = 0;
    always @(posedge clk) begin
        cycle_cnt <= cycle_cnt + 1;
        if (cycle_cnt >= TIMEOUT) begin $display("FAIL: timeout"); $finish; end
    end

    `TB_DUMP_CONTROL(tb_axi_timer)

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
    integer cov_count, cov_compare, cov_irq_test, cov_w1c, cov_reload;
    initial begin cov_total=0; cov_pass=0; cov_fail=0; cov_count=0; cov_compare=0; cov_irq_test=0; cov_w1c=0; cov_reload=0; end

    reg [31:0] rd;

    initial begin
        rst_n = 0; s_awvalid = 0; s_wvalid = 0; s_arvalid = 0; s_bready = 0; s_rready = 0;
        s_awaddr = 0; s_araddr = 0; s_wdata = 0; s_wstrb = 0;
        repeat (20) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        // Test 1: Set compare, enable timer, check count
        $display("\n=== Timer Count ===");
        cov_count = 1;
        axi_wr(32'h0000_000C, 32'd100);   // COMPARE = 100
        axi_wr(32'h0000_0000, 32'h0000_0003); // CTRL: enable + irq_en
        repeat (20) @(posedge clk);
        axi_rd(32'h0000_0008, rd); // COUNT
        cov_total = cov_total + 1;
        if (rd > 0 && rd <= 100) begin cov_pass = cov_pass + 1; $display("  PASS: count=%0d", rd); end
        else begin cov_fail = cov_fail + 1; $display("  FAIL: count=%0d", rd); end

        // Test 2: Wait for compare match IRQ
        $display("\n=== Compare Match IRQ ===");
        cov_compare = 1;
        cov_irq_test = 1;
        // Wait enough cycles for counter to reach 100
        repeat (200) @(posedge clk);
        cov_total = cov_total + 1;
        if (irq == 1'b1) begin cov_pass = cov_pass + 1; $display("  PASS: irq asserted"); end
        else begin cov_fail = cov_fail + 1; $display("  FAIL: irq not asserted"); end

        // Read STATUS
        axi_rd(32'h0000_0004, rd);
        cov_total = cov_total + 1;
        if (rd[0] == 1'b1) begin cov_pass = cov_pass + 1; $display("  PASS: match flag set"); end
        else begin cov_fail = cov_fail + 1; $display("  FAIL: match flag not set"); end

        // Test 3: W1C — clear match flag
        $display("\n=== W1C Clear ===");
        cov_w1c = 1;
        axi_wr(32'h0000_0004, 32'h0000_0001); // W1C
        repeat (2) @(posedge clk);
        cov_total = cov_total + 1;
        if (irq == 1'b0) begin cov_pass = cov_pass + 1; $display("  PASS: irq cleared"); end
        else begin cov_fail = cov_fail + 1; $display("  FAIL: irq still asserted"); end

        // Test 4: Auto-reload
        $display("\n=== Auto-reload ===");
        cov_reload = 1;
        axi_wr(32'h0000_0000, 32'h0000_0000); // disable
        axi_wr(32'h0000_000C, 32'd10);         // COMPARE = 10
        axi_wr(32'h0000_0000, 32'h0000_0007);  // enable + irq_en + auto_reload
        repeat (50) @(posedge clk);
        axi_rd(32'h0000_0008, rd);
        cov_total = cov_total + 1;
        // With auto-reload, count should have wrapped and be < 10
        if (rd <= 32'd10) begin cov_pass = cov_pass + 1; $display("  PASS: auto-reload count=%0d", rd); end
        else begin cov_fail = cov_fail + 1; $display("  FAIL: auto-reload count=%0d", rd); end

        // Report
        $display("\n========================================");
        $display(" COVERAGE REPORT");
        $display("========================================");
        $display("  Total: %0d  Pass: %0d  Fail: %0d", cov_total, cov_pass, cov_fail);
        $display("  [%s] Count",      cov_count    ? "HIT" : "   ");
        $display("  [%s] Compare",    cov_compare  ? "HIT" : "   ");
        $display("  [%s] IRQ",        cov_irq_test ? "HIT" : "   ");
        $display("  [%s] W1C",        cov_w1c      ? "HIT" : "   ");
        $display("  [%s] Auto-reload",cov_reload   ? "HIT" : "   ");
        $display("  Functional: %0d / 5", cov_count+cov_compare+cov_irq_test+cov_w1c+cov_reload);
        if (cov_fail == 0) $display("*** ALL TESTS PASSED ***");
        else $display("*** %0d FAILED ***", cov_fail);
        $display("========================================");
        $finish;
    end

endmodule
