# SoC Subsystem 設計規格

## 1. 架構
```
              +-----------------+
              |   picorv32_axi  |  (RISC-V RV32I CPU)
              +--------+--------+
                       |
              +--------v--------+
              | axi_interconnect|  (1-master, 4-slave)
              +--+----+----+---++
                 |    |    |    |
            +----+ +--+  ++   ++---+
            |      |      |        |
       +----v-+ +--v---+ +v-----+ +v--------+
       | sram | | dma  | | uart | | timer   |
       | 4KB  | | regs | | lite | | 32-bit  |
       +------+ +------+ +------+ +---------+
```

## 2. 位址映射
| 基底位址 | 大小 | 模組 | 說明 |
|----------|------|------|------|
| 0x0000_0000 | 4KB | axi_sram | 主記憶體（boot + data） |
| 0x0001_0000 | 32B | axi_dma_regs | DMA 控制/狀態暫存器 |
| 0x0002_0000 | 16B | axi_uart_lite | UART TX/RX |
| 0x0003_0000 | 16B | axi_timer | Timer + IRQ |

## 3. CPU
- PicoRV32 (RV32I), ISC License
- AXI4-Lite master
- Reset vector: 0x0000_0000
- Stack: 0x0000_0FFC (SRAM top)
- IRQ: [0] timer, [1] uart, [2] dma

## 4. 時脈與重置
- 單一時脈域 (clk)
- 全域 active-low 非同步重置 (rst_n)

## 5. Firmware
- boot.S: 設定 stack pointer，跳轉至 main
- main.c: 測試 SRAM、UART loopback、Timer、DMA 暫存器存取
- 使用 riscv32-unknown-elf-gcc 編譯，產出 hex 供 $readmemh 載入
