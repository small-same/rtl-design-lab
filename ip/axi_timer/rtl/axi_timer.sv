// AXI4-Lite 32-bit Timer with compare match IRQ
/* verilator lint_off UNUSED */
module axi_timer #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
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

    output logic                    irq
);

    // Register map (byte offsets):
    //   0x00: CTRL     (RW) — [0] enable, [1] irq_en, [2] auto_reload
    //   0x04: STATUS   (R/W1C) — [0] compare_match (write 1 to clear)
    //   0x08: COUNT    (R)  — current counter value
    //   0x0C: COMPARE  (RW) — compare match value

    localparam ADDR_LSB = $clog2(DATA_WIDTH / 8);

    // ---------------------------------------------------------------
    // Timer registers
    // ---------------------------------------------------------------
    logic        timer_en_q;
    logic        irq_en_q;
    logic        auto_reload_q;
    logic        match_flag_q;
    logic [31:0] count_q;
    logic [31:0] compare_q;

    // ---------------------------------------------------------------
    // Timer logic
    // ---------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count_q <= 32'd0;
        end else if (!timer_en_q) begin
            count_q <= 32'd0;
        end else begin
            if (count_q == compare_q && compare_q != 32'd0) begin
                if (auto_reload_q)
                    count_q <= 32'd0;
                // else: stop counting (counter holds at match)
            end else begin
                count_q <= count_q + 32'd1;
            end
        end
    end

    // Match flag — edge-detect: fires only on rising edge of match condition
    logic match_cond;
    logic match_cond_prev_q;
    logic match_event;

    assign match_cond  = timer_en_q && (count_q == compare_q) && (compare_q != 32'd0);
    assign match_event = match_cond && !match_cond_prev_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            match_cond_prev_q <= 1'b0;
        else
            match_cond_prev_q <= match_cond;
    end

    assign irq = match_flag_q && irq_en_q;

    // ---------------------------------------------------------------
    // Write channel
    // ---------------------------------------------------------------
    logic aw_done_q, w_done_q;
    logic [ADDR_WIDTH-1:0] awaddr_q;
    logic [DATA_WIDTH-1:0] wdata_q;
    logic s_bvalid_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            aw_done_q     <= 1'b0;
            w_done_q      <= 1'b0;
            awaddr_q      <= '0;
            wdata_q       <= '0;
            s_bvalid_q    <= 1'b0;
            timer_en_q    <= 1'b0;
            irq_en_q      <= 1'b0;
            auto_reload_q <= 1'b0;
            match_flag_q  <= 1'b0;
            compare_q     <= 32'd0;
        end else begin
            // Set match flag on event
            if (match_event)
                match_flag_q <= 1'b1;

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
            // Perform write (guard with !s_bvalid_q to prevent double-fire)
            if (!s_bvalid_q &&
                (aw_done_q || (s_awvalid && !aw_done_q)) &&
                (w_done_q  || (s_wvalid  && !w_done_q))) begin
                s_bvalid_q <= 1'b1;
                case (aw_done_q ? awaddr_q[ADDR_LSB+1:ADDR_LSB] : s_awaddr[ADDR_LSB+1:ADDR_LSB])
                    2'b00: begin // CTRL
                        timer_en_q    <= w_done_q ? wdata_q[0] : s_wdata[0];
                        irq_en_q      <= w_done_q ? wdata_q[1] : s_wdata[1];
                        auto_reload_q <= w_done_q ? wdata_q[2] : s_wdata[2];
                    end
                    2'b01: begin // STATUS (W1C)
                        if (w_done_q ? wdata_q[0] : s_wdata[0])
                            match_flag_q <= 1'b0;
                    end
                    2'b11: begin // COMPARE
                        compare_q <= w_done_q ? wdata_q : s_wdata;
                    end
                    default: ; // COUNT is read-only
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
                case (s_araddr[ADDR_LSB+1:ADDR_LSB])
                    2'b00: s_rdata_q <= {{(DATA_WIDTH-3){1'b0}}, auto_reload_q, irq_en_q, timer_en_q};
                    2'b01: s_rdata_q <= {{(DATA_WIDTH-1){1'b0}}, match_flag_q};
                    2'b10: s_rdata_q <= count_q;
                    2'b11: s_rdata_q <= compare_q;
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

/* verilator lint_on UNUSED */
endmodule
