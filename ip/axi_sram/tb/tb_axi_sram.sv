`timescale 1ns/1ps
`include "tb_macros.vh"

module tb_axi_sram;

    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter TIMEOUT    = 10000;

    reg                    clk;
    reg                    rst_n;
    // AXI4-Lite signals
    reg  [ADDR_WIDTH-1:0]  s_awaddr;
    reg                    s_awvalid;
    wire                   s_awready;
    reg  [DATA_WIDTH-1:0]  s_wdata;
    reg  [DATA_WIDTH/8-1:0] s_wstrb;
    reg                    s_wvalid;
    wire                   s_wready;
    wire [1:0]             s_bresp;
    wire                   s_bvalid;
    reg                    s_bready;
    reg  [ADDR_WIDTH-1:0]  s_araddr;
    reg                    s_arvalid;
    wire                   s_arready;
    wire [DATA_WIDTH-1:0]  s_rdata;
    wire [1:0]             s_rresp;
    wire                   s_rvalid;
    reg                    s_rready;

    // Coverage
    integer cov_total, cov_pass, cov_fail;
    integer cov_write_read, cov_byte_strb, cov_sequential, cov_back2back, cov_boundary;
    integer total_writes, total_reads;

    initial begin
        cov_total = 0; cov_pass = 0; cov_fail = 0;
        cov_write_read = 0; cov_byte_strb = 0; cov_sequential = 0;
        cov_back2back = 0; cov_boundary = 0;
        total_writes = 0; total_reads = 0;
    end

    axi_sram u_dut (
        .clk(clk), .rst_n(rst_n),
        .s_awaddr(s_awaddr), .s_awvalid(s_awvalid), .s_awready(s_awready),
        .s_wdata(s_wdata), .s_wstrb(s_wstrb), .s_wvalid(s_wvalid), .s_wready(s_wready),
        .s_bresp(s_bresp), .s_bvalid(s_bvalid), .s_bready(s_bready),
        .s_araddr(s_araddr), .s_arvalid(s_arvalid), .s_arready(s_arready),
        .s_rdata(s_rdata), .s_rresp(s_rresp), .s_rvalid(s_rvalid), .s_rready(s_rready)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // Timeout
    integer cycle_cnt;
    initial cycle_cnt = 0;
    always @(posedge clk) begin
        cycle_cnt <= cycle_cnt + 1;
        if (cycle_cnt >= TIMEOUT) begin
            $display("FAIL: global timeout");
            $finish;
        end
    end

    `TB_COUNTERS
    `TB_DUMP_CONTROL(tb_axi_sram)

    // Write task
    task axi_write;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        input [DATA_WIDTH/8-1:0] strb;
        begin
            @(posedge clk);
            s_awaddr  = addr;
            s_awvalid = 1'b1;
            s_wdata   = data;
            s_wstrb   = strb;
            s_wvalid  = 1'b1;
            s_bready  = 1'b1;
            @(posedge clk);
            s_awvalid = 1'b0;
            s_wvalid  = 1'b0;
            while (!s_bvalid) @(posedge clk);
            @(posedge clk);
            s_bready = 1'b0;
            total_writes = total_writes + 1;
        end
    endtask

    // Read task
    task axi_read;
        input  [ADDR_WIDTH-1:0] addr;
        output [DATA_WIDTH-1:0] data;
        begin
            @(posedge clk);
            s_araddr  = addr;
            s_arvalid = 1'b1;
            s_rready  = 1'b1;
            @(posedge clk);
            s_arvalid = 1'b0;
            while (!s_rvalid) @(posedge clk);
            data = s_rdata;
            @(posedge clk);
            s_rready = 1'b0;
            total_reads = total_reads + 1;
        end
    endtask

    // Check task
    task check;
        input [DATA_WIDTH-1:0] expected;
        input [DATA_WIDTH-1:0] actual;
        input [63:0] name;
        begin
            cov_total = cov_total + 1;
            if (actual === expected) begin
                cov_pass = cov_pass + 1;
                $display("  PASS: %0s (exp=0x%08x got=0x%08x)", name, expected, actual);
            end else begin
                cov_fail = cov_fail + 1;
                $display("  FAIL: %0s (exp=0x%08x got=0x%08x)", name, expected, actual);
            end
        end
    endtask

    reg [DATA_WIDTH-1:0] rd_data;

    initial begin
        rst_n = 0; s_awvalid = 0; s_wvalid = 0; s_arvalid = 0;
        s_bready = 0; s_rready = 0; s_awaddr = 0; s_wdata = 0; s_wstrb = 0; s_araddr = 0;
        repeat (20) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        // ---- Test 1: Basic write/read ----
        $display("");
        $display("=== TEST 1: Basic Write/Read ===");
        cov_write_read = 1;
        axi_write(32'h0000_0000, 32'hDEAD_BEEF, 4'hF);
        axi_read(32'h0000_0000, rd_data);
        check(32'hDEAD_BEEF, rd_data, "basic_wr_rd");

        axi_write(32'h0000_0004, 32'h1234_5678, 4'hF);
        axi_read(32'h0000_0004, rd_data);
        check(32'h1234_5678, rd_data, "addr_04");

        // ---- Test 2: Byte strobe ----
        $display("");
        $display("=== TEST 2: Byte Strobe ===");
        cov_byte_strb = 1;
        axi_write(32'h0000_0010, 32'hFFFF_FFFF, 4'hF);
        axi_write(32'h0000_0010, 32'h0000_00AA, 4'h1); // write only byte 0
        axi_read(32'h0000_0010, rd_data);
        check(32'hFFFF_FFAA, rd_data, "byte_strb");

        // ---- Test 3: Sequential ----
        $display("");
        $display("=== TEST 3: Sequential ===");
        cov_sequential = 1;
        axi_write(32'h0000_0020, 32'h0000_0001, 4'hF);
        axi_write(32'h0000_0024, 32'h0000_0002, 4'hF);
        axi_write(32'h0000_0028, 32'h0000_0003, 4'hF);
        axi_read(32'h0000_0020, rd_data); check(32'h0000_0001, rd_data, "seq_0");
        axi_read(32'h0000_0024, rd_data); check(32'h0000_0002, rd_data, "seq_1");
        axi_read(32'h0000_0028, rd_data); check(32'h0000_0003, rd_data, "seq_2");

        // ---- Test 4: Back-to-back ----
        $display("");
        $display("=== TEST 4: Back-to-back ===");
        cov_back2back = 1;
        axi_write(32'h0000_0100, 32'hAAAA_AAAA, 4'hF);
        axi_write(32'h0000_0104, 32'h5555_5555, 4'hF);
        axi_read(32'h0000_0100, rd_data); check(32'hAAAA_AAAA, rd_data, "b2b_0");
        axi_read(32'h0000_0104, rd_data); check(32'h5555_5555, rd_data, "b2b_1");

        // ---- Test 5: Address boundary ----
        $display("");
        $display("=== TEST 5: Address Boundary ===");
        cov_boundary = 1;
        axi_write(32'h0000_0FFC, 32'hB00D_A470, 4'hF);
        axi_read(32'h0000_0FFC, rd_data);
        // Last word in 4KB
        axi_write(32'h0000_0FFC, 32'hCAFE_BABE, 4'hF);
        axi_read(32'h0000_0FFC, rd_data);
        check(32'hCAFE_BABE, rd_data, "boundary");

        // ---- Coverage Report ----
        $display("");
        $display("========================================");
        $display(" COVERAGE REPORT");
        $display("========================================");
        $display("  Total: %0d  Pass: %0d  Fail: %0d", cov_total, cov_pass, cov_fail);
        $display("  [%s] Basic write/read",  cov_write_read ? "HIT" : "   ");
        $display("  [%s] Byte strobe",       cov_byte_strb  ? "HIT" : "   ");
        $display("  [%s] Sequential",        cov_sequential ? "HIT" : "   ");
        $display("  [%s] Back-to-back",      cov_back2back  ? "HIT" : "   ");
        $display("  [%s] Boundary",          cov_boundary   ? "HIT" : "   ");
        $display("  Functional: %0d / 5", cov_write_read + cov_byte_strb + cov_sequential + cov_back2back + cov_boundary);
        $display("  Writes: %0d  Reads: %0d", total_writes, total_reads);
        $display("");
        if (cov_fail == 0) $display("*** ALL TESTS PASSED ***");
        else $display("*** %0d TEST(S) FAILED ***", cov_fail);
        $display("========================================");
        $finish;
    end

endmodule
