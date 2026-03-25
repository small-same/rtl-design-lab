# AXI Interconnect Design Specification

## Overview

The `axi_interconnect` module is a 1-master-to-4-slave AXI4-Lite address decoder and multiplexer. It routes transactions from a single AXI4-Lite master to one of four slave ports based on the transaction address, and returns DECERR for unmapped addresses.

## Address Map

| Base Address | Size | Slave Port | Peripheral |
|-------------|------|------------|------------|
| 0x0000_0000 | 4 KB (0x1000) | Slave 0 | SRAM |
| 0x0001_0000 | 32 B (0x0020) | Slave 1 | DMA registers |
| 0x0002_0000 | 16 B (0x0010) | Slave 2 | UART |
| 0x0003_0000 | 16 B (0x0010) | Slave 3 | Timer |

All other addresses are unmapped and generate DECERR.

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| ADDR_WIDTH | 32 | Address bus width |
| DATA_WIDTH | 32 | Data bus width |
| NUM_SLAVES | 4 | Number of slave ports |
| S0_BASE | 0x0000_0000 | Slave 0 base address |
| S0_SIZE | 0x0000_1000 | Slave 0 address range (4 KB) |
| S1_BASE | 0x0001_0000 | Slave 1 base address |
| S1_SIZE | 0x0000_0020 | Slave 1 address range (32 B) |
| S2_BASE | 0x0002_0000 | Slave 2 base address |
| S2_SIZE | 0x0000_0010 | Slave 2 address range (16 B) |
| S3_BASE | 0x0003_0000 | Slave 3 base address |
| S3_SIZE | 0x0000_0010 | Slave 3 address range (16 B) |

## Interface Signals

### Master Port (AXI4-Lite)

All five AXI4-Lite channels: AW (write address), W (write data), B (write response), AR (read address), R (read data).

### Slave Ports (s0, s1, s2, s3)

Four explicit slave ports, each with identical AXI4-Lite channel signals. Explicit ports are used (rather than arrays or interfaces) for Icarus Verilog compatibility.

## Address Decode Logic

The address decoder compares the incoming address against each slave's `[BASE, BASE+SIZE)` range. Decoding is performed independently for the write path (using `m_awaddr`) and the read path (using `m_araddr`).

Priority: Slave 0 is checked first, then 1, 2, 3. If no range matches, the selection is set to NONE (unmapped).

## Write Path FSM

States: IDLE -> ADDR_DATA -> RESP -> IDLE (normal) or IDLE -> DECERR -> IDLE (unmapped).

- In ADDR_DATA, the interconnect forwards AW and W channels to the selected slave and waits for both handshakes.
- In RESP, it forwards the slave's B channel back to the master.
- For unmapped addresses, it accepts AW/W from the master and returns bresp = 2'b11 (DECERR).

## Read Path FSM

States: IDLE -> ADDR -> DATA -> IDLE (normal) or IDLE -> DECERR -> IDLE (unmapped).

- In ADDR, it forwards the AR channel to the selected slave.
- In DATA, it forwards the slave's R channel back to the master.
- For unmapped addresses, it returns rresp = 2'b11 (DECERR) with zero data.

## Error Handling

- Unmapped addresses: Both write and read paths return DECERR (resp = 2'b11).
- Address gaps between slave regions are treated as unmapped.
- Boundary addresses at exactly BASE+SIZE are out of range and generate DECERR.
