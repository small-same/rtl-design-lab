// Minimal SoC test firmware for Ibex
// Tests: SRAM read/write, UART TX, Timer, DMA registers

#include <stdint.h>

// Peripheral base addresses
#define SRAM_BASE    0x00000000
#define DMA_BASE     0x00010000
#define UART_BASE    0x00020000
#define TIMER_BASE   0x00030000

// DMA registers
#define DMA_CTRL     (*(volatile uint32_t *)(DMA_BASE + 0x00))
#define DMA_STATUS   (*(volatile uint32_t *)(DMA_BASE + 0x04))
#define DMA_SRC      (*(volatile uint32_t *)(DMA_BASE + 0x08))
#define DMA_DST      (*(volatile uint32_t *)(DMA_BASE + 0x0C))
#define DMA_LEN      (*(volatile uint32_t *)(DMA_BASE + 0x10))

// UART registers
#define UART_TX_DATA (*(volatile uint32_t *)(UART_BASE + 0x00))
#define UART_RX_DATA (*(volatile uint32_t *)(UART_BASE + 0x04))
#define UART_STATUS  (*(volatile uint32_t *)(UART_BASE + 0x08))
#define UART_CTRL    (*(volatile uint32_t *)(UART_BASE + 0x0C))

// Timer registers
#define TIMER_CTRL   (*(volatile uint32_t *)(TIMER_BASE + 0x00))
#define TIMER_STATUS (*(volatile uint32_t *)(TIMER_BASE + 0x04))
#define TIMER_COUNT  (*(volatile uint32_t *)(TIMER_BASE + 0x08))
#define TIMER_CMP    (*(volatile uint32_t *)(TIMER_BASE + 0x0C))

// Result storage in SRAM
#define RESULT_BASE  0x00000100
#define RESULT(n)    (*(volatile uint32_t *)(RESULT_BASE + (n)*4))

static void uart_putchar(char c) {
    UART_TX_DATA = (uint32_t)c;
}

static void uart_puts(const char *s) {
    while (*s) {
        uart_putchar(*s++);
    }
}

void main(void) {
    uint32_t pass = 0;
    uint32_t fail = 0;

    // --- Test 1: SRAM write/read ---
    volatile uint32_t *sram = (volatile uint32_t *)0x00000200;
    sram[0] = 0xDEADBEEF;
    sram[1] = 0x12345678;
    if (sram[0] == 0xDEADBEEF && sram[1] == 0x12345678)
        pass++;
    else
        fail++;

    // --- Test 2: UART TX (loopback) ---
    uart_putchar('H');
    uart_putchar('i');
    // In loopback mode, we can read back
    // Small delay for loopback
    for (volatile int i = 0; i < 10; i++);
    uint32_t rx = UART_RX_DATA;
    if ((rx & 0xFF) == 'H')
        pass++;
    else
        fail++;

    // --- Test 3: Timer ---
    TIMER_CMP  = 50;              // Compare at 50
    TIMER_CTRL = 0x03;            // Enable + IRQ enable
    // Wait for match
    for (volatile int i = 0; i < 200; i++);
    uint32_t timer_status = TIMER_STATUS;
    if (timer_status & 0x01)
        pass++;
    else
        fail++;
    TIMER_STATUS = 0x01;          // Clear match flag (W1C)
    TIMER_CTRL   = 0x00;          // Disable timer

    // --- Test 4: DMA register access ---
    DMA_SRC = 0x00000200;
    DMA_DST = 0x00000300;
    DMA_LEN = 4;
    uint32_t dma_src_rb = DMA_SRC;
    if (dma_src_rb == 0x00000200)
        pass++;
    else
        fail++;

    // Store results
    RESULT(0) = pass;
    RESULT(1) = fail;
    RESULT(2) = 0xA5A5A5A5;      // Magic marker: test complete

    // Signal completion via UART
    uart_puts("OK");

    // Done — return to boot.S which will ebreak
}
