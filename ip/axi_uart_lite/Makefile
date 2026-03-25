PROJECT_ROOT := $(shell git rev-parse --show-toplevel 2>/dev/null || echo ../..)
IP_NAME      := axi_uart_lite
IP_DIR       := $(PROJECT_ROOT)/ip/$(IP_NAME)
TB           ?= tb_axi_uart_lite

sim:
	bash $(PROJECT_ROOT)/scripts/sim/run_sim.sh \
		$(IP_DIR)/filelist/sim.f $(TB) $(IP_DIR)

lint:
	bash $(PROJECT_ROOT)/scripts/lint/run_lint.sh \
		$(IP_DIR)/filelist/rtl.f $(IP_DIR)

.PHONY: sim lint
