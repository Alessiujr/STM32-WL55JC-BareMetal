TARGET = firmware

CC      = arm-none-eabi-gcc
OBJCOPY = arm-none-eabi-objcopy
SIZE    = arm-none-eabi-size

CPUFLAGS = -mcpu=cortex-m4 -mthumb

CFLAGS = $(CPUFLAGS) \
         -Wall -Wextra \
         -O0 \
         -g3 \
         -ffreestanding

LDFLAGS = $(CPUFLAGS) \
          -T linker.ld \
          -nostdlib \
          -Wl,-Map=$(TARGET).map

SOURCES = src/startup.s src/main.c

all: $(TARGET).elf $(TARGET).bin

$(TARGET).elf: $(SOURCES) linker.ld
	$(CC) $(CFLAGS) $(SOURCES) $(LDFLAGS) -o $@
	$(SIZE) $@

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

clean:
	rm -f $(TARGET).elf $(TARGET).bin $(TARGET).map