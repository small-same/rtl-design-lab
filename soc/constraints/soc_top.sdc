# ==============================================================================
# SDC Timing Constraints — soc_top
# Target: PicoRV32 AXI4-Lite SoC Subsystem
# ==============================================================================

# ------------------------------------------------------------------------------
# Clock Definition
# ------------------------------------------------------------------------------
# Single clock domain, 100 MHz (10 ns period)
create_clock -name clk -period 10.0 [get_ports clk]

# Clock uncertainty (jitter + skew estimate)
set_clock_uncertainty 0.5 [get_clocks clk]

# ------------------------------------------------------------------------------
# Reset
# ------------------------------------------------------------------------------
# rst_n is asynchronous, treat as false path for timing analysis
set_false_path -from [get_ports rst_n]

# ------------------------------------------------------------------------------
# Input Delays
# ------------------------------------------------------------------------------
# External UART RX input — assume max 3 ns delay from pad
set_input_delay -clock clk -max 3.0 [get_ports uart_rx]
set_input_delay -clock clk -min 0.5 [get_ports uart_rx]

# ------------------------------------------------------------------------------
# Output Delays
# ------------------------------------------------------------------------------
# UART TX output — assume max 3 ns setup requirement at pad
set_output_delay -clock clk -max 3.0 [get_ports uart_tx]
set_output_delay -clock clk -min 0.5 [get_ports uart_tx]

# IRQ outputs (directly usable, active-high)
set_output_delay -clock clk -max 2.0 [get_ports {irq_uart irq_timer irq_dma}]
set_output_delay -clock clk -min 0.5 [get_ports {irq_uart irq_timer irq_dma}]

# Trap signal
set_output_delay -clock clk -max 2.0 [get_ports trap]
set_output_delay -clock clk -min 0.5 [get_ports trap]

# ------------------------------------------------------------------------------
# Design Rule Constraints
# ------------------------------------------------------------------------------
# Max transition time on all nets
set_max_transition 1.0 [current_design]

# Max fanout
set_max_fanout 20 [current_design]
