# STM32WL55JC1 Bare-Metal Development

Bare-metal development projects for the **STM32WL55JC1** microcontroller on the **NUCLEO-WL55JC1** development board.

The goal of this repository is to study the STM32WL55 architecture from the lowest software level, initially without relying on STM32 HAL, LL drivers, code generators, or an RTOS.

The project follows the complete execution path from the Cortex-M4 reset sequence to memory-mapped peripheral registers and, ultimately, to the physical hardware.

> **CPU → Memory → Bus → Peripheral Clock → Registers → GPIO → Physical Pin**

---

## Hardware

| Component | Description |
|---|---|
| Development board | NUCLEO-WL55JC1 |
| MCU | STM32WL55JCI7 |
| Main CPU | ARM Cortex-M4 |
| Secondary CPU | ARM Cortex-M0+ |
| Flash | 256 KB |
| SRAM | 64 KB |
| Debug interface | ST-LINK-V3E / SWD |
| First peripheral used | GPIO |
| First output | Green user LED on PB9 |

The first projects focus exclusively on the **Cortex-M4**.  
The dual-core architecture will be explored later.

---

## Development Environment

Development is performed on an **Apple Silicon Mac** using the ARM GNU toolchain.

Main tools:

- `arm-none-eabi-gcc`
- `arm-none-eabi-gdb`
- `arm-none-eabi-objcopy`
- `arm-none-eabi-size`
- GNU Make
- STM32CubeProgrammer
- ST-LINK-V3E

The initial projects intentionally avoid:

- STM32 HAL
- STM32 LL
- STM32CubeMX generated code
- CMSIS device headers
- RTOS abstractions

Peripheral registers are accessed directly through their memory-mapped addresses.

---

# Project 01 — Bare-Metal GPIO

The first firmware turns on the **green user LED connected to PB9** using direct register access.

No HAL function is involved.

The objective is not simply to turn on an LED, but to understand everything that happens between processor reset and the electrical state of the GPIO pin.

## Execution Flow

The firmware follows this sequence:

1. The Cortex-M4 comes out of reset.
2. The processor reads the initial stack pointer from the vector table.
3. The processor reads the reset vector and enters `Reset_Handler`.
4. `Reset_Handler` calls `main()`.
5. The GPIOB peripheral clock is enabled through RCC.
6. PB9 is configured as a general-purpose output.
7. PB9 is driven HIGH.
8. The green LED turns on.
9. The processor remains in an infinite loop.

Conceptually:

```text
Power / Reset
      │
      ▼
Cortex-M4
      │
      ▼
Vector Table @ 0x08000000
      │
      ├── Initial MSP
      │
      └── Reset_Handler
              │
              ▼
            main()
              │
              ▼
        RCC_AHB2ENR
              │
              ▼
       GPIOB clock ON
              │
              ▼
        GPIOB_MODER
              │
              ▼
        PB9 = Output
              │
              ▼
         GPIOB_ODR
              │
              ▼
          PB9 = HIGH
              │
              ▼
        Green LED ON
```

---

## GPIO Configuration

The green LED is connected to **PB9** and is **active HIGH**.

The firmware performs three fundamental operations.

### 1. Enable the GPIOB clock

GPIOB must receive a peripheral clock before its registers can be used.

The clock is enabled through:

```text
RCC_AHB2ENR
```

with:

```text
GPIOBEN = bit 1
```

The firmware performs a read-back after enabling the clock to allow the peripheral clock synchronization to complete before accessing GPIOB.

### 2. Configure PB9 as an output

PB9 is configured through the GPIO mode register:

```text
GPIOB_MODER
```

Each GPIO pin uses two mode bits.

For PB9:

```text
MODE9 = bits 19:18
```

The configuration:

```text
01
```

selects **General Purpose Output mode**.

### 3. Drive PB9 HIGH

The output state is controlled through:

```text
GPIOB_ODR
```

PB9 corresponds to:

```text
OD9 = bit 9
```

Setting this bit to `1` drives PB9 HIGH and turns on the green LED.

---

## Relevant Registers

| Register | Address | Relevant field | Purpose |
|---|---:|---|---|
| `RCC_AHB2ENR` | `0x5800004C` | `GPIOBEN` bit 1 | Enable GPIOB peripheral clock |
| `GPIOB_MODER` | `0x48000400` | `MODE9[1:0]` bits 19:18 | Configure PB9 mode |
| `GPIOB_ODR` | `0x48000414` | `OD9` bit 9 | Control PB9 output state |

The current implementation accesses these registers directly using volatile pointers:

```c
#define RCC_AHB2ENR   (*(volatile uint32_t *)0x5800004C)
#define GPIOB_MODER   (*(volatile uint32_t *)0x48000400)
#define GPIOB_ODR     (*(volatile uint32_t *)0x48000414)
```

---

## Current Firmware

The first `main()` implementation is intentionally minimal:

```c
#include <stdint.h>

#define RCC_AHB2ENR   (*(volatile uint32_t *)0x5800004C)
#define GPIOB_MODER   (*(volatile uint32_t *)0x48000400)
#define GPIOB_ODR     (*(volatile uint32_t *)0x48000414)

int main(void)
{
    // Enable GPIOB peripheral clock
    RCC_AHB2ENR |= (1U << 1);

    // Read-back: ensure GPIOB clock enable has taken effect
    (void)RCC_AHB2ENR;

    // Configure PB9 as general-purpose output (MODE9 = 01)
    GPIOB_MODER &= ~(3U << 18);
    GPIOB_MODER |=  (1U << 18);

    // PB9 HIGH -> Green LED ON
    GPIOB_ODR |= (1U << 9);

    while (1)
    {
    }
}
```

This code demonstrates direct **read-modify-write operations** on memory-mapped peripheral registers.

---

# Cortex-M4 Startup

The project does not use the standard STM32 startup files.

A minimal startup implementation is provided in:

```text
src/startup.s
```

It contains only:

- the initial Main Stack Pointer value;
- the reset vector;
- `Reset_Handler`;
- the call to `main()`.

The minimal vector table is:

```asm
.section .isr_vector, "a", %progbits

.word 0x20010000
.word Reset_Handler
```

At reset, the Cortex-M4 interprets the first two words as:

```text
0x08000000 → Initial MSP
0x08000004 → Reset vector
```

The initial stack pointer is:

```text
0x20010000
```

which corresponds to the address immediately above the SRAM region used by this minimal project. Since the ARM stack grows downward, the first stack operation moves into valid RAM.

The reset handler then calls `main()`:

```asm
Reset_Handler:
    bl main

Loop:
    b Loop
```

The infinite loop also prevents undefined execution if `main()` were ever to return.

---

# Memory Layout

The minimal linker configuration currently uses:

| Memory | Start | Size |
|---|---:|---:|
| Flash | `0x08000000` | 256 KB |
| RAM | `0x20000000` | 64 KB |

For this educational project, SRAM1 and SRAM2 are treated as one contiguous 64 KB RAM region.

The linker script defines:

```text
FLASH → 0x08000000
RAM   → 0x20000000
```

and places the vector table at the beginning of Flash.

The main sections are:

```text
.isr_vector
.text
.rodata
.data
.bss
```

The current startup code does **not yet initialize `.data` or `.bss`**. That functionality will be implemented in a later step.

---

# Project Structure

```text
STM32-WL55JC/
├── .gitignore
├── Makefile
├── README.md
├── linker.ld
├── docs/
│   └── ...
└── src/
    ├── main.c
    └── startup.s
```

### `src/main.c`

Contains the bare-metal application code and direct peripheral register accesses.

### `src/startup.s`

Contains the minimal Cortex-M4 vector table and reset handler.

### `linker.ld`

Defines the Flash and RAM memory regions and controls where the firmware sections are placed.

### `Makefile`

Builds the firmware using the ARM GNU toolchain.

### `docs/`

Contains additional technical notes and project documentation.

---

# Building the Firmware

From the project root:

```bash
make
```

The build generates:

```text
firmware.elf
firmware.bin
firmware.map
```

These generated files are excluded from Git through `.gitignore`.

To remove the generated files:

```bash
make clean
```

---

# Inspecting the Firmware

The generated ELF file can be inspected using the GNU ARM tools.

For example:

```bash
arm-none-eabi-objdump -h firmware.elf
```

can be used to inspect the ELF sections.

The vector table can be inspected with:

```bash
arm-none-eabi-objdump -s -j .isr_vector firmware.elf
```

and the generated machine instructions with:

```bash
arm-none-eabi-objdump -d firmware.elf
```

This makes it possible to follow the complete transformation:

```text
C / Assembly
      ↓
Compiler + Assembler
      ↓
Linker
      ↓
ELF
      ↓
ARM Thumb instructions
      ↓
Cortex-M4 execution
```

---

# Flashing

The firmware is programmed through the board's integrated **ST-LINK-V3E** using STM32CubeProgrammer.

The application is programmed starting at:

```text
0x08000000
```

The complete hardware path is:

```text
Mac
 │
 ▼
USB
 │
 ▼
ST-LINK-V3E
 │
 ▼
SWD
 │
 ▼
STM32WL55JCI7
 │
 ▼
Cortex-M4
```

The first firmware was successfully programmed and verified on the physical board, with the green PB9 LED turning on as expected.

---

# Current Limitations

The project is deliberately minimal and is intended to evolve progressively.

The current startup implementation does not yet provide:

- a complete interrupt vector table;
- `.data` initialization;
- `.bss` zero initialization;
- fault handlers;
- interrupt handlers;
- C runtime initialization.

GPIO output is currently modified through an `ODR` read-modify-write operation.

A future step will introduce `GPIOx_BSRR` for atomic GPIO set/reset operations.

---

# Documentation

Additional project documentation is available in the [`docs`](./docs) directory.

The documentation is intended to preserve not only the final implementation, but also the reasoning used to derive register addresses, bit fields, memory layout, startup behavior, and generated machine code.

---

# Learning Approach

This repository follows a bottom-up approach to embedded software development.

Instead of starting with:

```c
HAL_GPIO_WritePin(...);
```

the goal is to understand what such an abstraction ultimately performs at hardware level:

```text
Application
    ↓
C / Assembly
    ↓
Cortex-M4
    ↓
Memory-mapped I/O
    ↓
Bus architecture
    ↓
Peripheral clock
    ↓
Peripheral registers
    ↓
GPIO logic
    ↓
Physical pin
```
