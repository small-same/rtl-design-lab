// SoC Top — Ibex CPU + AXI4-Lite Interconnect + Peripherals
/* verilator lint_off UNUSED */
`timescale 1ns/1ps

module soc_top #(
    parameter MEM_INIT_FILE = "",
    parameter ADDR_WIDTH    = 32,
    parameter DATA_WIDTH    = 32
)(
    input  wire clk,
    input  wire rst_n,

    // External UART
    output wire uart_tx,
    input  wire uart_rx,

    // Interrupts (active-high, directly usable)
    output wire irq_uart,
    output wire irq_timer,
    output wire irq_dma,

    // Alert output (replaces PicoRV32 trap)
    output wire trap
);

    // ---------------------------------------------------------------
    // Ibex CPU OBI signals
    // ---------------------------------------------------------------
    wire        instr_req;
    wire        instr_gnt;
    wire        instr_rvalid;
    wire [31:0] instr_addr;
    wire [31:0] instr_rdata;

    wire        data_req;
    wire        data_gnt;
    wire        data_rvalid;
    wire        data_we;
    wire [ 3:0] data_be;
    wire [31:0] data_addr;
    wire [31:0] data_wdata;
    wire [31:0] data_rdata;

    // Merged OBI signals (after obi_mux)
    wire        mux_obi_req;
    wire        mux_obi_gnt;
    wire        mux_obi_rvalid;
    wire        mux_obi_we;
    wire [ 3:0] mux_obi_be;
    wire [31:0] mux_obi_addr;
    wire [31:0] mux_obi_wdata;
    wire [31:0] mux_obi_rdata;
    wire        mux_obi_err;

    // AXI4-Lite master signals (from obi_axil_adapter)
    wire        mem_axi_awvalid;
    wire        mem_axi_awready;
    wire [31:0] mem_axi_awaddr;

    wire        mem_axi_wvalid;
    wire        mem_axi_wready;
    wire [31:0] mem_axi_wdata;
    wire [ 3:0] mem_axi_wstrb;

    wire        mem_axi_bvalid;
    wire        mem_axi_bready;
    wire [ 1:0] mem_axi_bresp;

    wire        mem_axi_arvalid;
    wire        mem_axi_arready;
    wire [31:0] mem_axi_araddr;

    wire        mem_axi_rvalid;
    wire        mem_axi_rready;
    wire [31:0] mem_axi_rdata;
    wire [ 1:0] mem_axi_rresp;

    // Ibex register file wires
    wire        dummy_instr_id;
    wire        dummy_instr_wb;
    wire [ 4:0] rf_raddr_a;
    wire [ 4:0] rf_raddr_b;
    wire [ 4:0] rf_waddr_wb;
    wire        rf_we_wb;
    wire [31:0] rf_wdata_wb;
    wire [31:0] rf_rdata_a;
    wire [31:0] rf_rdata_b;

    // Ibex alert signals
    wire        alert_minor;
    wire        alert_major_internal;
    wire        alert_major_bus;

    // Derive trap from major alert (indicates fatal error)
    assign trap = alert_major_internal | alert_major_bus;

    // ICache RAM tie-offs (ICache disabled)
    // IC_NUM_WAYS=2, TagSizeECC=22, LineSizeECC=64
    wire [21:0] ic_tag_rdata  [2];
    wire [63:0] ic_data_rdata [2];
    assign ic_tag_rdata[0]  = 22'b0;
    assign ic_tag_rdata[1]  = 22'b0;
    assign ic_data_rdata[0] = 64'b0;
    assign ic_data_rdata[1] = 64'b0;

    // ---------------------------------------------------------------
    // Ibex CPU Core
    // ---------------------------------------------------------------
    ibex_core #(
        .PMPEnable         (1'b0),
        .PMPNumRegions     (0),
        .RV32E             (1'b0),
        .RV32M             (ibex_pkg::RV32MFast),
        .RV32B             (ibex_pkg::RV32BNone),
        .BranchTargetALU   (1'b0),
        .WritebackStage    (1'b0),
        .ICache            (1'b0),
        .ICacheECC         (1'b0),
        .SecureIbex        (1'b0),
        .DummyInstructions (1'b0),
        .RegFileECC        (1'b0),
        .MemECC            (1'b0),
        .DbgTriggerEn      (1'b0),
        .DmHaltAddr        (32'h0),
        .DmExceptionAddr   (32'h0)
    ) u_cpu (
        .clk_i              (clk),
        .rst_ni             (rst_n),

        .hart_id_i          (32'h0),
        .boot_addr_i        (32'h0000_0000),

        // Instruction memory interface
        .instr_req_o        (instr_req),
        .instr_gnt_i        (instr_gnt),
        .instr_rvalid_i     (instr_rvalid),
        .instr_addr_o       (instr_addr),
        .instr_rdata_i      (instr_rdata),
        .instr_err_i        (1'b0),

        // Data memory interface
        .data_req_o         (data_req),
        .data_gnt_i         (data_gnt),
        .data_rvalid_i      (data_rvalid),
        .data_we_o          (data_we),
        .data_be_o          (data_be),
        .data_addr_o        (data_addr),
        .data_wdata_o       (data_wdata),
        .data_rdata_i       (data_rdata),
        .data_err_i         (1'b0),

        // Register file interface
        .dummy_instr_id_o   (dummy_instr_id),
        .dummy_instr_wb_o   (dummy_instr_wb),
        .rf_raddr_a_o       (rf_raddr_a),
        .rf_raddr_b_o       (rf_raddr_b),
        .rf_waddr_wb_o      (rf_waddr_wb),
        .rf_we_wb_o         (rf_we_wb),
        .rf_wdata_wb_ecc_o  (rf_wdata_wb),
        .rf_rdata_a_ecc_i   (rf_rdata_a),
        .rf_rdata_b_ecc_i   (rf_rdata_b),

        // ICache RAMs (tied off -- ICache disabled)
        .ic_tag_req_o       (),
        .ic_tag_write_o     (),
        .ic_tag_addr_o      (),
        .ic_tag_wdata_o     (),
        .ic_tag_rdata_i     (ic_tag_rdata),
        .ic_data_req_o      (),
        .ic_data_write_o    (),
        .ic_data_addr_o     (),
        .ic_data_wdata_o    (),
        .ic_data_rdata_i    (ic_data_rdata),
        .ic_scr_key_valid_i (1'b1),
        .ic_scr_key_req_o   (),

        // Interrupts
        .irq_software_i     (1'b0),
        .irq_timer_i        (irq_timer),
        .irq_external_i     (irq_uart | irq_dma),
        .irq_fast_i         (15'b0),
        .irq_nm_i           (1'b0),
        .irq_pending_o      (),

        // Debug (tied off)
        .debug_req_i        (1'b0),
        .crash_dump_o       (),
        .double_fault_seen_o(),

        // CPU control
        .fetch_enable_i     (ibex_pkg::IbexMuBiOn),
        .alert_minor_o      (alert_minor),
        .alert_major_internal_o(alert_major_internal),
        .alert_major_bus_o  (alert_major_bus),
        .core_busy_o        ()
    );

    // ---------------------------------------------------------------
    // Ibex Register File (flip-flop based)
    // ---------------------------------------------------------------
    ibex_register_file_ff #(
        .RV32E             (1'b0),
        .DataWidth         (32),
        .DummyInstructions (1'b0)
    ) u_regfile (
        .clk_i             (clk),
        .rst_ni            (rst_n),
        .test_en_i         (1'b0),
        .dummy_instr_id_i  (dummy_instr_id),
        .dummy_instr_wb_i  (dummy_instr_wb),
        .raddr_a_i         (rf_raddr_a),
        .rdata_a_o         (rf_rdata_a),
        .raddr_b_i         (rf_raddr_b),
        .rdata_b_o         (rf_rdata_b),
        .waddr_a_i         (rf_waddr_wb),
        .wdata_a_i         (rf_wdata_wb),
        .we_a_i            (rf_we_wb)
    );

    // ---------------------------------------------------------------
    // OBI Mux: merge instr + data into single OBI port
    // ---------------------------------------------------------------
    obi_mux u_obi_mux (
        .clk             (clk),
        .rst_n           (rst_n),

        // Instruction port (lower priority)
        .instr_req_i     (instr_req),
        .instr_gnt_o     (instr_gnt),
        .instr_rvalid_o  (instr_rvalid),
        .instr_addr_i    (instr_addr),
        .instr_rdata_o   (instr_rdata),
        .instr_err_o     (),

        // Data port (higher priority)
        .data_req_i      (data_req),
        .data_gnt_o      (data_gnt),
        .data_rvalid_o   (data_rvalid),
        .data_we_i       (data_we),
        .data_be_i       (data_be),
        .data_addr_i     (data_addr),
        .data_wdata_i    (data_wdata),
        .data_rdata_o    (data_rdata),
        .data_err_o      (),

        // Merged OBI master
        .obi_req_o       (mux_obi_req),
        .obi_gnt_i       (mux_obi_gnt),
        .obi_rvalid_i    (mux_obi_rvalid),
        .obi_we_o        (mux_obi_we),
        .obi_be_o        (mux_obi_be),
        .obi_addr_o      (mux_obi_addr),
        .obi_wdata_o     (mux_obi_wdata),
        .obi_rdata_i     (mux_obi_rdata),
        .obi_err_i       (mux_obi_err)
    );

    // ---------------------------------------------------------------
    // OBI-to-AXI4-Lite Adapter
    // ---------------------------------------------------------------
    obi_axil_adapter u_obi_adapter (
        .clk             (clk),
        .rst_n           (rst_n),

        // OBI slave (from mux)
        .obi_req_i       (mux_obi_req),
        .obi_gnt_o       (mux_obi_gnt),
        .obi_rvalid_o    (mux_obi_rvalid),
        .obi_we_i        (mux_obi_we),
        .obi_be_i        (mux_obi_be),
        .obi_addr_i      (mux_obi_addr),
        .obi_wdata_i     (mux_obi_wdata),
        .obi_rdata_o     (mux_obi_rdata),
        .obi_err_o       (mux_obi_err),

        // AXI4-Lite master
        .m_awaddr        (mem_axi_awaddr),
        .m_awvalid       (mem_axi_awvalid),
        .m_awready       (mem_axi_awready),
        .m_wdata         (mem_axi_wdata),
        .m_wstrb         (mem_axi_wstrb),
        .m_wvalid        (mem_axi_wvalid),
        .m_wready        (mem_axi_wready),
        .m_bresp         (mem_axi_bresp),
        .m_bvalid        (mem_axi_bvalid),
        .m_bready        (mem_axi_bready),
        .m_araddr        (mem_axi_araddr),
        .m_arvalid       (mem_axi_arvalid),
        .m_arready       (mem_axi_arready),
        .m_rdata         (mem_axi_rdata),
        .m_rresp         (mem_axi_rresp),
        .m_rvalid        (mem_axi_rvalid),
        .m_rready        (mem_axi_rready)
    );

    // ---------------------------------------------------------------
    // Interconnect <-> Slave wires
    // ---------------------------------------------------------------
    // Slave 0: SRAM
    wire [31:0] s0_awaddr,  s0_araddr,  s0_wdata, s0_rdata;
    wire [3:0]  s0_wstrb;
    wire        s0_awvalid, s0_awready, s0_wvalid, s0_wready;
    wire [1:0]  s0_bresp,   s0_rresp;
    wire        s0_bvalid,  s0_bready;
    wire        s0_arvalid, s0_arready, s0_rvalid, s0_rready;

    // Slave 1: DMA regs
    wire [31:0] s1_awaddr,  s1_araddr,  s1_wdata, s1_rdata;
    wire [3:0]  s1_wstrb;
    wire        s1_awvalid, s1_awready, s1_wvalid, s1_wready;
    wire [1:0]  s1_bresp,   s1_rresp;
    wire        s1_bvalid,  s1_bready;
    wire        s1_arvalid, s1_arready, s1_rvalid, s1_rready;

    // Slave 2: UART
    wire [31:0] s2_awaddr,  s2_araddr,  s2_wdata, s2_rdata;
    wire [3:0]  s2_wstrb;
    wire        s2_awvalid, s2_awready, s2_wvalid, s2_wready;
    wire [1:0]  s2_bresp,   s2_rresp;
    wire        s2_bvalid,  s2_bready;
    wire        s2_arvalid, s2_arready, s2_rvalid, s2_rready;

    // Slave 3: Timer
    wire [31:0] s3_awaddr,  s3_araddr,  s3_wdata, s3_rdata;
    wire [3:0]  s3_wstrb;
    wire        s3_awvalid, s3_awready, s3_wvalid, s3_wready;
    wire [1:0]  s3_bresp,   s3_rresp;
    wire        s3_bvalid,  s3_bready;
    wire        s3_arvalid, s3_arready, s3_rvalid, s3_rready;

    // DMA master AXI4 write channel (DMA -> SRAM via interconnect -- simplified: tie off for now)
    wire [31:0] dma_m_awaddr;
    wire [7:0]  dma_m_awlen;
    wire        dma_m_awvalid, dma_m_awready;
    wire [31:0] dma_m_wdata;
    wire        dma_m_wlast, dma_m_wvalid, dma_m_wready;
    wire [1:0]  dma_m_bresp;
    wire        dma_m_bvalid, dma_m_bready;

    // Tie off DMA master (DMA writes directly back to SRAM -- not routed through interconnect in this version)
    assign dma_m_awready = 1'b1;
    assign dma_m_wready  = 1'b1;
    assign dma_m_bresp   = 2'b00;
    assign dma_m_bvalid  = dma_m_bready;

    // ---------------------------------------------------------------
    // AXI Interconnect
    // ---------------------------------------------------------------
    axi_interconnect u_interconnect (
        .clk       (clk),
        .rst_n     (rst_n),

        // Master (CPU via OBI adapter)
        .m_awaddr  (mem_axi_awaddr),
        .m_awvalid (mem_axi_awvalid),
        .m_awready (mem_axi_awready),
        .m_wdata   (mem_axi_wdata),
        .m_wstrb   (mem_axi_wstrb),
        .m_wvalid  (mem_axi_wvalid),
        .m_wready  (mem_axi_wready),
        .m_bresp   (mem_axi_bresp),
        .m_bvalid  (mem_axi_bvalid),
        .m_bready  (mem_axi_bready),
        .m_araddr  (mem_axi_araddr),
        .m_arvalid (mem_axi_arvalid),
        .m_arready (mem_axi_arready),
        .m_rdata   (mem_axi_rdata),
        .m_rresp   (mem_axi_rresp),
        .m_rvalid  (mem_axi_rvalid),
        .m_rready  (mem_axi_rready),

        // Slave 0: SRAM
        .s0_awaddr (s0_awaddr),  .s0_awvalid(s0_awvalid), .s0_awready(s0_awready),
        .s0_wdata  (s0_wdata),   .s0_wstrb  (s0_wstrb),   .s0_wvalid (s0_wvalid), .s0_wready(s0_wready),
        .s0_bresp  (s0_bresp),   .s0_bvalid (s0_bvalid),  .s0_bready (s0_bready),
        .s0_araddr (s0_araddr),  .s0_arvalid(s0_arvalid), .s0_arready(s0_arready),
        .s0_rdata  (s0_rdata),   .s0_rresp  (s0_rresp),   .s0_rvalid (s0_rvalid), .s0_rready(s0_rready),

        // Slave 1: DMA regs
        .s1_awaddr (s1_awaddr),  .s1_awvalid(s1_awvalid), .s1_awready(s1_awready),
        .s1_wdata  (s1_wdata),   .s1_wstrb  (s1_wstrb),   .s1_wvalid (s1_wvalid), .s1_wready(s1_wready),
        .s1_bresp  (s1_bresp),   .s1_bvalid (s1_bvalid),  .s1_bready (s1_bready),
        .s1_araddr (s1_araddr),  .s1_arvalid(s1_arvalid), .s1_arready(s1_arready),
        .s1_rdata  (s1_rdata),   .s1_rresp  (s1_rresp),   .s1_rvalid (s1_rvalid), .s1_rready(s1_rready),

        // Slave 2: UART
        .s2_awaddr (s2_awaddr),  .s2_awvalid(s2_awvalid), .s2_awready(s2_awready),
        .s2_wdata  (s2_wdata),   .s2_wstrb  (s2_wstrb),   .s2_wvalid (s2_wvalid), .s2_wready(s2_wready),
        .s2_bresp  (s2_bresp),   .s2_bvalid (s2_bvalid),  .s2_bready (s2_bready),
        .s2_araddr (s2_araddr),  .s2_arvalid(s2_arvalid), .s2_arready(s2_arready),
        .s2_rdata  (s2_rdata),   .s2_rresp  (s2_rresp),   .s2_rvalid (s2_rvalid), .s2_rready(s2_rready),

        // Slave 3: Timer
        .s3_awaddr (s3_awaddr),  .s3_awvalid(s3_awvalid), .s3_awready(s3_awready),
        .s3_wdata  (s3_wdata),   .s3_wstrb  (s3_wstrb),   .s3_wvalid (s3_wvalid), .s3_wready(s3_wready),
        .s3_bresp  (s3_bresp),   .s3_bvalid (s3_bvalid),  .s3_bready (s3_bready),
        .s3_araddr (s3_araddr),  .s3_arvalid(s3_arvalid), .s3_arready(s3_arready),
        .s3_rdata  (s3_rdata),   .s3_rresp  (s3_rresp),   .s3_rvalid (s3_rvalid), .s3_rready(s3_rready)
    );

    // ---------------------------------------------------------------
    // Slave 0: SRAM (4KB)
    // ---------------------------------------------------------------
    axi_sram #(
        .MEM_INIT_FILE(MEM_INIT_FILE)
    ) u_sram (
        .clk      (clk),
        .rst_n    (rst_n),
        .s_awaddr (s0_awaddr),  .s_awvalid(s0_awvalid), .s_awready(s0_awready),
        .s_wdata  (s0_wdata),   .s_wstrb  (s0_wstrb),   .s_wvalid (s0_wvalid), .s_wready(s0_wready),
        .s_bresp  (s0_bresp),   .s_bvalid (s0_bvalid),  .s_bready (s0_bready),
        .s_araddr (s0_araddr),  .s_arvalid(s0_arvalid), .s_arready(s0_arready),
        .s_rdata  (s0_rdata),   .s_rresp  (s0_rresp),   .s_rvalid (s0_rvalid), .s_rready(s0_rready)
    );

    // ---------------------------------------------------------------
    // Slave 1: DMA Registers + DMA Core
    // ---------------------------------------------------------------
    axi_dma_regs u_dma_regs (
        .clk      (clk),
        .rst_n    (rst_n),
        .s_awaddr (s1_awaddr),  .s_awvalid(s1_awvalid), .s_awready(s1_awready),
        .s_wdata  (s1_wdata),   .s_wstrb  (s1_wstrb),   .s_wvalid (s1_wvalid), .s_wready(s1_wready),
        .s_bresp  (s1_bresp),   .s_bvalid (s1_bvalid),  .s_bready (s1_bready),
        .s_araddr (s1_araddr),  .s_arvalid(s1_arvalid), .s_arready(s1_arready),
        .s_rdata  (s1_rdata),   .s_rresp  (s1_rresp),   .s_rvalid (s1_rvalid), .s_rready(s1_rready),
        .dma_start(),
        .src_addr (),
        .dst_addr (),
        .xfer_len (),
        .m_awaddr (dma_m_awaddr),
        .m_awlen  (dma_m_awlen),
        .m_awvalid(dma_m_awvalid),
        .m_awready(dma_m_awready),
        .m_wdata  (dma_m_wdata),
        .m_wlast  (dma_m_wlast),
        .m_wvalid (dma_m_wvalid),
        .m_wready (dma_m_wready),
        .m_bresp  (dma_m_bresp),
        .m_bvalid (dma_m_bvalid),
        .m_bready (dma_m_bready),
        .irq      (irq_dma)
    );

    // ---------------------------------------------------------------
    // Slave 2: UART Lite
    // ---------------------------------------------------------------
    axi_uart_lite u_uart (
        .clk      (clk),
        .rst_n    (rst_n),
        .s_awaddr (s2_awaddr),  .s_awvalid(s2_awvalid), .s_awready(s2_awready),
        .s_wdata  (s2_wdata),   .s_wstrb  (s2_wstrb),   .s_wvalid (s2_wvalid), .s_wready(s2_wready),
        .s_bresp  (s2_bresp),   .s_bvalid (s2_bvalid),  .s_bready (s2_bready),
        .s_araddr (s2_araddr),  .s_arvalid(s2_arvalid), .s_arready(s2_arready),
        .s_rdata  (s2_rdata),   .s_rresp  (s2_rresp),   .s_rvalid (s2_rvalid), .s_rready(s2_rready),
        .uart_tx  (uart_tx),
        .uart_rx  (uart_rx),
        .irq      (irq_uart)
    );

    // ---------------------------------------------------------------
    // Slave 3: Timer
    // ---------------------------------------------------------------
    axi_timer u_timer (
        .clk      (clk),
        .rst_n    (rst_n),
        .s_awaddr (s3_awaddr),  .s_awvalid(s3_awvalid), .s_awready(s3_awready),
        .s_wdata  (s3_wdata),   .s_wstrb  (s3_wstrb),   .s_wvalid (s3_wvalid), .s_wready(s3_wready),
        .s_bresp  (s3_bresp),   .s_bvalid (s3_bvalid),  .s_bready (s3_bready),
        .s_araddr (s3_araddr),  .s_arvalid(s3_arvalid), .s_arready(s3_arready),
        .s_rdata  (s3_rdata),   .s_rresp  (s3_rresp),   .s_rvalid (s3_rvalid), .s_rready(s3_rready),
        .irq      (irq_timer)
    );

/* verilator lint_on UNUSED */
endmodule
