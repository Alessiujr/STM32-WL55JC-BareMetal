.syntax unified
.cpu cortex-m4
.thumb

.section .isr_vector, "a", %progbits
.word 0x20010000
.word Reset_Handler

.section .text.Reset_Handler
.global Reset_Handler
.type Reset_Handler, %function

Reset_Handler:
    bl main

Loop:
    b Loop
    