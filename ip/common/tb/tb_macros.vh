// ============================================================================
// tb_macros.vh — Standardized TB logging and dump control macros
// ============================================================================

// ----------------------------------------------------------------------------
// Logging macros
// %0t = simulation time, %m = hierarchical module path
// ----------------------------------------------------------------------------

// Basic check: condition, message string
`define TB_CHECK(cond, msg) \
    if (!(cond)) begin \
        $display("[%0t] ERROR: %s (%m)", $time, msg); \
        tb_error_count = tb_error_count + 1; \
    end else begin \
        tb_pass_count = tb_pass_count + 1; \
    end

// Check with expected/actual values
`define TB_CHECK_EQ(actual, expected, msg) \
    if ((actual) !== (expected)) begin \
        $display("[%0t] ERROR: %s — exp=0x%08x got=0x%08x (%m)", $time, msg, (expected), (actual)); \
        tb_error_count = tb_error_count + 1; \
    end else begin \
        $display("[%0t] PASS: %s (%m)", $time, msg); \
        tb_pass_count = tb_pass_count + 1; \
    end

// Info message (non-error)
`define TB_INFO(msg) \
    $display("[%0t] INFO: %s (%m)", $time, msg);

// Fatal: stop simulation immediately
`define TB_FATAL(msg) \
    begin \
        $display("[%0t] FATAL: %s (%m)", $time, msg); \
        $finish; \
    end

// Test group header
`define TB_GROUP(name) \
    $display(""); \
    $display("[%0t] ======== %s ========", $time, name);

// ----------------------------------------------------------------------------
// Summary report macro — call at end of simulation
// ----------------------------------------------------------------------------
`define TB_SUMMARY(tb_name) \
    $display(""); \
    $display("========================================"); \
    $display(" %s SUMMARY", tb_name); \
    $display("========================================"); \
    $display("  Pass:  %0d", tb_pass_count); \
    $display("  Error: %0d", tb_error_count); \
    if (tb_error_count == 0) \
        $display("*** ALL TESTS PASSED ***"); \
    else \
        $display("*** %0d TEST(S) FAILED ***", tb_error_count); \
    $display("========================================");

// ----------------------------------------------------------------------------
// Counter declaration — include once per TB module
// ----------------------------------------------------------------------------
`define TB_COUNTERS \
    integer tb_error_count; \
    integer tb_pass_count; \
    initial begin tb_error_count = 0; tb_pass_count = 0; end

// ----------------------------------------------------------------------------
// VCD dump control via plusargs
//
// Usage (default):   vvp a.out              → full dump
// Usage (no dump):   vvp a.out +NO_DUMP
// Usage (windowed):  vvp a.out +DUMP_START=4500 +DUMP_DURATION=1000
//
// Declare these two integers at module scope before using this macro:
//   integer _dump_start, _dump_duration;
// ----------------------------------------------------------------------------
`define TB_DUMP_CTRL_VARS \
    integer _dump_start; \
    integer _dump_duration;

`define TB_DUMP_CONTROL(scope) \
    `TB_DUMP_CTRL_VARS \
    initial begin \
        _dump_start = 0; \
        _dump_duration = 0; \
        if ($test$plusargs("NO_DUMP")) begin \
            $display("[%0t] INFO: VCD dump disabled via +NO_DUMP", $time); \
        end else begin \
            if ($value$plusargs("DUMP_START=%d", _dump_start)) ; \
            if ($value$plusargs("DUMP_DURATION=%d", _dump_duration)) ; \
            if (_dump_start > 0) begin \
                #(_dump_start); \
            end \
            $dumpfile("dump.vcd"); \
            $dumpvars(0, scope); \
            if (_dump_duration > 0) begin \
                #(_dump_duration); \
                $dumpoff; \
                $display("[%0t] INFO: VCD dump stopped after %0d time units", $time, _dump_duration); \
            end \
        end \
    end
