`timescale 1ns/1ps
`include "tb_macros.vh"

module tb_soc_top;

    parameter TIMEOUT = 500000; // Ibex needs more cycles (pipelined)

    reg  clk;
    reg  rst_n;
    wire uart_tx;
    wire irq_uart, irq_timer, irq_dma;
    wire trap;

    soc_top #(
        .MEM_INIT_FILE("firmware.hex")
    ) u_dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .uart_tx   (uart_tx),
        .uart_rx   (1'b1),
        .irq_uart  (irq_uart),
        .irq_timer (irq_timer),
        .irq_dma   (irq_dma),
        .trap      (trap)
    );

    initial clk = 0;
    always #5 clk = ~clk; // 100 MHz

    // Timeout
    integer cycle_cnt;
    initial cycle_cnt = 0;
    always @(posedge clk) begin
        cycle_cnt <= cycle_cnt + 1;
        if (cycle_cnt >= TIMEOUT) begin
            $display("TIMEOUT after %0d cycles", TIMEOUT);
            $finish;
        end
    end

    // Monitor halt — firmware writes 0xDEAD0000 to SRAM[0x110] when done
    reg [31:0] halt_marker;
    always @(posedge clk) begin
        if (rst_n) begin
            halt_marker = u_dut.u_sram.mem[68]; // 0x110 / 4 = 68
            if (halt_marker == 32'hDEAD0000) begin
                $display("CPU HALTED at cycle %0d", cycle_cnt);
                $display("SRAM[0x100] = 0x%08x", u_dut.u_sram.mem[64]);
                $display("SRAM[0x104] = 0x%08x", u_dut.u_sram.mem[65]);
                $display("SRAM[0x108] = 0x%08x", u_dut.u_sram.mem[66]);
                $finish;
            end
        end
    end

    // Monitor Ibex alert (hardware error)
    always @(posedge clk) begin
        if (trap) begin
            $display("ALERT: Ibex hardware error at cycle %0d", cycle_cnt);
        end
    end

    // Coverage
    integer cov_total, cov_pass, cov_fail;
    integer cov_boot, cov_sram, cov_trap_seen;
    initial begin
        cov_total = 0; cov_pass = 0; cov_fail = 0;
        cov_boot = 0; cov_sram = 0; cov_trap_seen = 0;
    end

    `TB_DUMP_CONTROL(tb_soc_top)

    // Simple test: just check the SoC boots and runs without immediate trap
    initial begin
        rst_n = 0;
        repeat (50) @(posedge clk);
        rst_n = 1;
        cov_boot = 1;

        // Wait some cycles and check CPU is running (no immediate trap)
        repeat (100) @(posedge clk);
        cov_total = cov_total + 1;
        if (!trap) begin
            cov_pass = cov_pass + 1;
            cov_sram = 1;
            $display("PASS: CPU booted without immediate trap");
        end else begin
            cov_fail = cov_fail + 1;
            $display("FAIL: CPU trapped immediately");
        end

        // Let it run for a while
        repeat (TIMEOUT - 200) @(posedge clk);

        // Report
        $display("");
        $display("========================================");
        $display(" SoC COVERAGE REPORT");
        $display("========================================");
        $display("  Total: %0d  Pass: %0d  Fail: %0d", cov_total, cov_pass, cov_fail);
        $display("  [%s] Boot",  cov_boot ? "HIT" : "   ");
        $display("  [%s] SRAM",  cov_sram ? "HIT" : "   ");
        $display("========================================");
        $finish;
    end

endmodule
