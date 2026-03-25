/* verilator lint_off UNUSED */
`timescale 1ns/1ps
`include "tb_macros.vh"

module tb_axi_interconnect;

    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter STRB_WIDTH = DATA_WIDTH / 8;
    parameter TIMEOUT    = 50000;

    reg clk;
    reg rst_n;

    // ---- Master-side signals ----
    reg  [ADDR_WIDTH-1:0] m_awaddr;
    reg                   m_awvalid;
    wire                  m_awready;
    reg  [DATA_WIDTH-1:0] m_wdata;
    reg  [STRB_WIDTH-1:0] m_wstrb;
    reg                   m_wvalid;
    wire                  m_wready;
    wire [1:0]            m_bresp;
    wire                  m_bvalid;
    reg                   m_bready;
    reg  [ADDR_WIDTH-1:0] m_araddr;
    reg                   m_arvalid;
    wire                  m_arready;
    wire [DATA_WIDTH-1:0] m_rdata;
    wire [1:0]            m_rresp;
    wire                  m_rvalid;
    reg                   m_rready;

    // ---- Slave 0 signals ----
    wire [ADDR_WIDTH-1:0] s0_awaddr;  wire s0_awvalid; reg s0_awready;
    wire [DATA_WIDTH-1:0] s0_wdata;   wire [STRB_WIDTH-1:0] s0_wstrb; wire s0_wvalid; reg s0_wready;
    reg  [1:0] s0_bresp; reg s0_bvalid; wire s0_bready;
    wire [ADDR_WIDTH-1:0] s0_araddr;  wire s0_arvalid; reg s0_arready;
    reg  [DATA_WIDTH-1:0] s0_rdata;   reg [1:0] s0_rresp; reg s0_rvalid; wire s0_rready;

    // ---- Slave 1 signals ----
    wire [ADDR_WIDTH-1:0] s1_awaddr;  wire s1_awvalid; reg s1_awready;
    wire [DATA_WIDTH-1:0] s1_wdata;   wire [STRB_WIDTH-1:0] s1_wstrb; wire s1_wvalid; reg s1_wready;
    reg  [1:0] s1_bresp; reg s1_bvalid; wire s1_bready;
    wire [ADDR_WIDTH-1:0] s1_araddr;  wire s1_arvalid; reg s1_arready;
    reg  [DATA_WIDTH-1:0] s1_rdata;   reg [1:0] s1_rresp; reg s1_rvalid; wire s1_rready;

    // ---- Slave 2 signals ----
    wire [ADDR_WIDTH-1:0] s2_awaddr;  wire s2_awvalid; reg s2_awready;
    wire [DATA_WIDTH-1:0] s2_wdata;   wire [STRB_WIDTH-1:0] s2_wstrb; wire s2_wvalid; reg s2_wready;
    reg  [1:0] s2_bresp; reg s2_bvalid; wire s2_bready;
    wire [ADDR_WIDTH-1:0] s2_araddr;  wire s2_arvalid; reg s2_arready;
    reg  [DATA_WIDTH-1:0] s2_rdata;   reg [1:0] s2_rresp; reg s2_rvalid; wire s2_rready;

    // ---- Slave 3 signals ----
    wire [ADDR_WIDTH-1:0] s3_awaddr;  wire s3_awvalid; reg s3_awready;
    wire [DATA_WIDTH-1:0] s3_wdata;   wire [STRB_WIDTH-1:0] s3_wstrb; wire s3_wvalid; reg s3_wready;
    reg  [1:0] s3_bresp; reg s3_bvalid; wire s3_bready;
    wire [ADDR_WIDTH-1:0] s3_araddr;  wire s3_arvalid; reg s3_arready;
    reg  [DATA_WIDTH-1:0] s3_rdata;   reg [1:0] s3_rresp; reg s3_rvalid; wire s3_rready;

    // ----------------------------------------------------------------
    // Coverage counters
    // ----------------------------------------------------------------
    integer cov_total_tests;
    integer cov_passed_tests;
    integer cov_failed_tests;
    integer cov_decode_s0;
    integer cov_decode_s1;
    integer cov_decode_s2;
    integer cov_decode_s3;
    integer cov_decode_err;
    integer cov_write_s0;
    integer cov_read_s0;
    integer cov_back_to_back;

    initial begin
        cov_total_tests  = 0;
        cov_passed_tests = 0;
        cov_failed_tests = 0;
        cov_decode_s0    = 0;
        cov_decode_s1    = 0;
        cov_decode_s2    = 0;
        cov_decode_s3    = 0;
        cov_decode_err   = 0;
        cov_write_s0     = 0;
        cov_read_s0      = 0;
        cov_back_to_back = 0;
    end

    // ----------------------------------------------------------------
    // DUT
    // ----------------------------------------------------------------
    axi_interconnect #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_dut (
        .clk       (clk),
        .rst_n     (rst_n),
        // Master
        .m_awaddr  (m_awaddr),  .m_awvalid (m_awvalid), .m_awready (m_awready),
        .m_wdata   (m_wdata),   .m_wstrb   (m_wstrb),   .m_wvalid  (m_wvalid),  .m_wready  (m_wready),
        .m_bresp   (m_bresp),   .m_bvalid  (m_bvalid),  .m_bready  (m_bready),
        .m_araddr  (m_araddr),  .m_arvalid (m_arvalid), .m_arready (m_arready),
        .m_rdata   (m_rdata),   .m_rresp   (m_rresp),   .m_rvalid  (m_rvalid),  .m_rready  (m_rready),
        // Slave 0
        .s0_awaddr (s0_awaddr), .s0_awvalid(s0_awvalid),.s0_awready(s0_awready),
        .s0_wdata  (s0_wdata),  .s0_wstrb  (s0_wstrb),  .s0_wvalid (s0_wvalid), .s0_wready (s0_wready),
        .s0_bresp  (s0_bresp),  .s0_bvalid (s0_bvalid), .s0_bready (s0_bready),
        .s0_araddr (s0_araddr), .s0_arvalid(s0_arvalid),.s0_arready(s0_arready),
        .s0_rdata  (s0_rdata),  .s0_rresp  (s0_rresp),  .s0_rvalid (s0_rvalid), .s0_rready (s0_rready),
        // Slave 1
        .s1_awaddr (s1_awaddr), .s1_awvalid(s1_awvalid),.s1_awready(s1_awready),
        .s1_wdata  (s1_wdata),  .s1_wstrb  (s1_wstrb),  .s1_wvalid (s1_wvalid), .s1_wready (s1_wready),
        .s1_bresp  (s1_bresp),  .s1_bvalid (s1_bvalid), .s1_bready (s1_bready),
        .s1_araddr (s1_araddr), .s1_arvalid(s1_arvalid),.s1_arready(s1_arready),
        .s1_rdata  (s1_rdata),  .s1_rresp  (s1_rresp),  .s1_rvalid (s1_rvalid), .s1_rready (s1_rready),
        // Slave 2
        .s2_awaddr (s2_awaddr), .s2_awvalid(s2_awvalid),.s2_awready(s2_awready),
        .s2_wdata  (s2_wdata),  .s2_wstrb  (s2_wstrb),  .s2_wvalid (s2_wvalid), .s2_wready (s2_wready),
        .s2_bresp  (s2_bresp),  .s2_bvalid (s2_bvalid), .s2_bready (s2_bready),
        .s2_araddr (s2_araddr), .s2_arvalid(s2_arvalid),.s2_arready(s2_arready),
        .s2_rdata  (s2_rdata),  .s2_rresp  (s2_rresp),  .s2_rvalid (s2_rvalid), .s2_rready (s2_rready),
        // Slave 3
        .s3_awaddr (s3_awaddr), .s3_awvalid(s3_awvalid),.s3_awready(s3_awready),
        .s3_wdata  (s3_wdata),  .s3_wstrb  (s3_wstrb),  .s3_wvalid (s3_wvalid), .s3_wready (s3_wready),
        .s3_bresp  (s3_bresp),  .s3_bvalid (s3_bvalid), .s3_bready (s3_bready),
        .s3_araddr (s3_araddr), .s3_arvalid(s3_arvalid),.s3_arready(s3_arready),
        .s3_rdata  (s3_rdata),  .s3_rresp  (s3_rresp),  .s3_rvalid (s3_rvalid), .s3_rready (s3_rready)
    );

    // ----------------------------------------------------------------
    // Clock
    // ----------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // ----------------------------------------------------------------
    // Simple slave responders (all 4 identical behavior)
    // Each slave: immediately accept AW/W, return OKAY bresp,
    // immediately accept AR, return rdata = addr[7:0] repeated.
    // ----------------------------------------------------------------

    // --- Slave 0 responder ---
    reg [DATA_WIDTH-1:0] s0_wr_data_captured;
    reg [ADDR_WIDTH-1:0] s0_rd_addr_captured;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s0_awready <= 1'b1; s0_wready <= 1'b1;
            s0_bvalid  <= 1'b0; s0_bresp  <= 2'b00;
            s0_arready <= 1'b1;
            s0_rvalid  <= 1'b0; s0_rresp  <= 2'b00; s0_rdata <= 32'd0;
        end else begin
            // Write response
            if (s0_bvalid && s0_bready) s0_bvalid <= 1'b0;
            if (s0_awvalid && s0_awready && s0_wvalid && s0_wready) begin
                s0_bvalid <= 1'b1; s0_bresp <= 2'b00;
                s0_wr_data_captured <= s0_wdata;
            end else if (s0_wvalid && s0_wready && !s0_bvalid) begin
                s0_bvalid <= 1'b1; s0_bresp <= 2'b00;
                s0_wr_data_captured <= s0_wdata;
            end else if (s0_awvalid && s0_awready && !s0_wvalid) begin
                // AW only, wait for W
            end
            // Read response
            if (s0_rvalid && s0_rready) s0_rvalid <= 1'b0;
            if (s0_arvalid && s0_arready) begin
                s0_rvalid <= 1'b1; s0_rresp <= 2'b00;
                s0_rdata  <= {4{s0_araddr[7:0]}};
                s0_rd_addr_captured <= s0_araddr;
            end
        end
    end

    // --- Slave 1 responder ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_awready <= 1'b1; s1_wready <= 1'b1;
            s1_bvalid  <= 1'b0; s1_bresp  <= 2'b00;
            s1_arready <= 1'b1;
            s1_rvalid  <= 1'b0; s1_rresp  <= 2'b00; s1_rdata <= 32'd0;
        end else begin
            if (s1_bvalid && s1_bready) s1_bvalid <= 1'b0;
            if (s1_wvalid && s1_wready && !s1_bvalid) begin
                s1_bvalid <= 1'b1; s1_bresp <= 2'b00;
            end
            if (s1_rvalid && s1_rready) s1_rvalid <= 1'b0;
            if (s1_arvalid && s1_arready) begin
                s1_rvalid <= 1'b1; s1_rresp <= 2'b00;
                s1_rdata  <= {4{s1_araddr[7:0]}};
            end
        end
    end

    // --- Slave 2 responder ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s2_awready <= 1'b1; s2_wready <= 1'b1;
            s2_bvalid  <= 1'b0; s2_bresp  <= 2'b00;
            s2_arready <= 1'b1;
            s2_rvalid  <= 1'b0; s2_rresp  <= 2'b00; s2_rdata <= 32'd0;
        end else begin
            if (s2_bvalid && s2_bready) s2_bvalid <= 1'b0;
            if (s2_wvalid && s2_wready && !s2_bvalid) begin
                s2_bvalid <= 1'b1; s2_bresp <= 2'b00;
            end
            if (s2_rvalid && s2_rready) s2_rvalid <= 1'b0;
            if (s2_arvalid && s2_arready) begin
                s2_rvalid <= 1'b1; s2_rresp <= 2'b00;
                s2_rdata  <= {4{s2_araddr[7:0]}};
            end
        end
    end

    // --- Slave 3 responder ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s3_awready <= 1'b1; s3_wready <= 1'b1;
            s3_bvalid  <= 1'b0; s3_bresp  <= 2'b00;
            s3_arready <= 1'b1;
            s3_rvalid  <= 1'b0; s3_rresp  <= 2'b00; s3_rdata <= 32'd0;
        end else begin
            if (s3_bvalid && s3_bready) s3_bvalid <= 1'b0;
            if (s3_wvalid && s3_wready && !s3_bvalid) begin
                s3_bvalid <= 1'b1; s3_bresp <= 2'b00;
            end
            if (s3_rvalid && s3_rready) s3_rvalid <= 1'b0;
            if (s3_arvalid && s3_arready) begin
                s3_rvalid <= 1'b1; s3_rresp <= 2'b00;
                s3_rdata  <= {4{s3_araddr[7:0]}};
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
    `TB_DUMP_CONTROL(tb_axi_interconnect)

    // ----------------------------------------------------------------
    // Task: AXI4-Lite write
    // ----------------------------------------------------------------
    task axi_write;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        output [1:0]           resp;
        integer wait_cnt;
        begin
            @(posedge clk);
            m_awaddr  = addr;
            m_awvalid = 1'b1;
            m_wdata   = data;
            m_wstrb   = {STRB_WIDTH{1'b1}};
            m_wvalid  = 1'b1;
            m_bready  = 1'b1;

            // Wait for AW and W handshakes
            wait_cnt = 0;
            while ((!m_awready || !m_wready) && wait_cnt < 100) begin
                @(posedge clk);
                if (m_awready) m_awvalid = 1'b0;
                if (m_wready)  m_wvalid  = 1'b0;
                wait_cnt = wait_cnt + 1;
            end
            // Deassert after handshake
            @(posedge clk);
            m_awvalid = 1'b0;
            m_wvalid  = 1'b0;

            // Wait for B response
            wait_cnt = 0;
            while (!m_bvalid && wait_cnt < 100) begin
                @(posedge clk);
                wait_cnt = wait_cnt + 1;
            end
            resp = m_bresp;
            @(posedge clk);
            m_bready = 1'b0;
            @(posedge clk);
        end
    endtask

    // ----------------------------------------------------------------
    // Task: AXI4-Lite read
    // ----------------------------------------------------------------
    task axi_read;
        input  [ADDR_WIDTH-1:0] addr;
        output [DATA_WIDTH-1:0] data;
        output [1:0]            resp;
        integer wait_cnt;
        begin
            @(posedge clk);
            m_araddr  = addr;
            m_arvalid = 1'b1;
            m_rready  = 1'b1;

            // Wait for AR handshake
            wait_cnt = 0;
            while (!m_arready && wait_cnt < 100) begin
                @(posedge clk);
                wait_cnt = wait_cnt + 1;
            end
            @(posedge clk);
            m_arvalid = 1'b0;

            // Wait for R response
            wait_cnt = 0;
            while (!m_rvalid && wait_cnt < 100) begin
                @(posedge clk);
                wait_cnt = wait_cnt + 1;
            end
            data = m_rdata;
            resp = m_rresp;
            @(posedge clk);
            m_rready = 1'b0;
            @(posedge clk);
        end
    endtask

    // ----------------------------------------------------------------
    // Task: check write result
    // ----------------------------------------------------------------
    task check_write;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        input [1:0]            exp_resp;
        input [255:0]          test_name;
        reg [1:0] got_resp;
        begin
            cov_total_tests = cov_total_tests + 1;
            axi_write(addr, data, got_resp);
            if (got_resp === exp_resp) begin
                cov_passed_tests = cov_passed_tests + 1;
                $display("  PASS: %0s write addr=0x%08h resp=%b", test_name, addr, got_resp);
            end else begin
                cov_failed_tests = cov_failed_tests + 1;
                $display("  FAIL: %0s write addr=0x%08h exp_resp=%b got_resp=%b",
                         test_name, addr, exp_resp, got_resp);
            end
        end
    endtask

    // ----------------------------------------------------------------
    // Task: check read result
    // ----------------------------------------------------------------
    task check_read;
        input [ADDR_WIDTH-1:0] addr;
        input [1:0]            exp_resp;
        input [DATA_WIDTH-1:0] exp_data; // 0 means don't check data
        input                  check_data;
        input [255:0]          test_name;
        reg [DATA_WIDTH-1:0] got_data;
        reg [1:0]            got_resp;
        begin
            cov_total_tests = cov_total_tests + 1;
            axi_read(addr, got_data, got_resp);
            if (got_resp !== exp_resp) begin
                cov_failed_tests = cov_failed_tests + 1;
                $display("  FAIL: %0s read addr=0x%08h exp_resp=%b got_resp=%b",
                         test_name, addr, exp_resp, got_resp);
            end else if (check_data && got_data !== exp_data) begin
                cov_failed_tests = cov_failed_tests + 1;
                $display("  FAIL: %0s read addr=0x%08h exp_data=0x%08h got_data=0x%08h",
                         test_name, addr, exp_data, got_data);
            end else begin
                cov_passed_tests = cov_passed_tests + 1;
                $display("  PASS: %0s read addr=0x%08h data=0x%08h resp=%b",
                         test_name, addr, got_data, got_resp);
            end
        end
    endtask

    // ----------------------------------------------------------------
    // Main test sequence
    // ----------------------------------------------------------------
    initial begin
        // Init
        rst_n     = 1'b0;
        m_awaddr  = 0; m_awvalid = 0;
        m_wdata   = 0; m_wstrb   = 0; m_wvalid = 0;
        m_bready  = 0;
        m_araddr  = 0; m_arvalid = 0;
        m_rready  = 0;

        repeat (20) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        // ==============================================================
        $display("");
        $display("========================================");
        $display(" TEST GROUP 1: Address Decode (Write)");
        $display("========================================");

        $display("[1.1] Write to Slave 0 (SRAM @ 0x0000_0000)");
        cov_decode_s0 = 1;
        check_write(32'h0000_0000, 32'hDEAD_BEEF, 2'b00, "S0_wr");

        $display("[1.2] Write to Slave 1 (DMA @ 0x0001_0000)");
        cov_decode_s1 = 1;
        check_write(32'h0001_0000, 32'hCAFE_BABE, 2'b00, "S1_wr");

        $display("[1.3] Write to Slave 2 (UART @ 0x0002_0000)");
        cov_decode_s2 = 1;
        check_write(32'h0002_0004, 32'h1234_5678, 2'b00, "S2_wr");

        $display("[1.4] Write to Slave 3 (Timer @ 0x0003_0000)");
        cov_decode_s3 = 1;
        check_write(32'h0003_0008, 32'hAAAA_BBBB, 2'b00, "S3_wr");

        // ==============================================================
        $display("");
        $display("========================================");
        $display(" TEST GROUP 2: Unmapped Address (DECERR)");
        $display("========================================");

        $display("[2.1] Write to unmapped address");
        cov_decode_err = 1;
        check_write(32'hFFFF_0000, 32'h0000_0000, 2'b11, "unmap_wr");

        $display("[2.2] Read from unmapped address");
        check_read(32'hFFFF_0000, 2'b11, 32'd0, 1'b0, "unmap_rd");

        $display("[2.3] Write to gap between slaves");
        check_write(32'h0000_5000, 32'h0000_0000, 2'b11, "gap_wr");

        // ==============================================================
        $display("");
        $display("========================================");
        $display(" TEST GROUP 3: Read from Each Slave");
        $display("========================================");

        // Slave responders return {4{addr[7:0]}} as rdata
        $display("[3.1] Read from Slave 0 @ 0x0000_0010");
        cov_read_s0 = 1;
        check_read(32'h0000_0010, 2'b00, 32'h10101010, 1'b1, "S0_rd");

        $display("[3.2] Read from Slave 1 @ 0x0001_0004");
        check_read(32'h0001_0004, 2'b00, 32'h04040404, 1'b1, "S1_rd");

        $display("[3.3] Read from Slave 2 @ 0x0002_0008");
        check_read(32'h0002_0008, 2'b00, 32'h08080808, 1'b1, "S2_rd");

        $display("[3.4] Read from Slave 3 @ 0x0003_000C");
        check_read(32'h0003_000C, 2'b00, 32'h0C0C0C0C, 1'b1, "S3_rd");

        // ==============================================================
        $display("");
        $display("========================================");
        $display(" TEST GROUP 4: Write then Read (S0)");
        $display("========================================");

        $display("[4.1] Write 0xABCD1234 to S0 @ 0x0000_0100");
        cov_write_s0 = 1;
        check_write(32'h0000_0100, 32'hABCD1234, 2'b00, "S0_w_then_r");

        $display("[4.2] Read back from S0 @ 0x0000_0100");
        // Note: our simple responder returns {4{addr[7:0]}} not stored data
        check_read(32'h0000_0100, 2'b00, 32'h00000000, 1'b1, "S0_r_back");

        // ==============================================================
        $display("");
        $display("========================================");
        $display(" TEST GROUP 5: Back-to-Back Accesses");
        $display("========================================");

        $display("[5.1] Rapid writes to different slaves");
        cov_back_to_back = 1;
        check_write(32'h0000_0000, 32'h11111111, 2'b00, "b2b_s0");
        check_write(32'h0001_0000, 32'h22222222, 2'b00, "b2b_s1");
        check_write(32'h0002_0000, 32'h33333333, 2'b00, "b2b_s2");
        check_write(32'h0003_0000, 32'h44444444, 2'b00, "b2b_s3");

        $display("[5.2] Rapid reads from different slaves");
        check_read(32'h0000_0000, 2'b00, 32'h00000000, 1'b1, "b2b_rd_s0");
        check_read(32'h0001_0000, 2'b00, 32'h00000000, 1'b1, "b2b_rd_s1");
        check_read(32'h0002_0000, 2'b00, 32'h00000000, 1'b1, "b2b_rd_s2");
        check_read(32'h0003_0000, 2'b00, 32'h00000000, 1'b1, "b2b_rd_s3");

        // ==============================================================
        $display("");
        $display("========================================");
        $display(" TEST GROUP 6: Boundary Addresses");
        $display("========================================");

        $display("[6.1] S0 last valid addr (0x0000_0FFC)");
        check_read(32'h0000_0FFC, 2'b00, 32'hFCFCFCFC, 1'b1, "S0_last");

        $display("[6.2] S0 first out-of-range (0x0000_1000) -> DECERR");
        check_read(32'h0000_1000, 2'b11, 32'd0, 1'b0, "S0_oor");

        $display("[6.3] S1 last valid addr (0x0001_001F)");
        check_read(32'h0001_001C, 2'b00, 32'h1C1C1C1C, 1'b1, "S1_last");

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
        $display("  [%s] Decode to Slave 0",       cov_decode_s0   ? "HIT" : "   ");
        $display("  [%s] Decode to Slave 1",       cov_decode_s1   ? "HIT" : "   ");
        $display("  [%s] Decode to Slave 2",       cov_decode_s2   ? "HIT" : "   ");
        $display("  [%s] Decode to Slave 3",       cov_decode_s3   ? "HIT" : "   ");
        $display("  [%s] Decode error (unmapped)",  cov_decode_err  ? "HIT" : "   ");
        $display("  [%s] Write to slave",           cov_write_s0    ? "HIT" : "   ");
        $display("  [%s] Read from slave",          cov_read_s0     ? "HIT" : "   ");
        $display("  [%s] Back-to-back accesses",    cov_back_to_back? "HIT" : "   ");
        $display("  Functional coverage: %0d / 8",
                 cov_decode_s0 + cov_decode_s1 + cov_decode_s2 + cov_decode_s3 +
                 cov_decode_err + cov_write_s0 + cov_read_s0 + cov_back_to_back);
        $display("");

        if (cov_failed_tests == 0)
            $display("*** ALL TESTS PASSED ***");
        else
            $display("*** %0d TEST(S) FAILED ***", cov_failed_tests);

        $display("========================================");
        $finish;
    end

endmodule
