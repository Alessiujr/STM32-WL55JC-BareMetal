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