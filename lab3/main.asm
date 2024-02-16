//*****************************************************************************
// Universidad del Valle de Guatemala
// IE023: Programación de Microcontroladores
// Autor: Astryd Rolinda Magaly Beb Caal
// Proyecto: LAB 3, contador con interrupciones y anti-rebote
// Hardware: ATMEGA328P
// Created: 9-02-2024
//*****************************************************************************

.include "M328PDEF.inc"
.CSEG
.ORG 0x00
    RJMP MAIN  ; Vector RESET
.ORG 0x0006
    RJMP ISR_PCINT0 ; Vector de ISR: PCINT0
.ORG 0x0020
    RJMP ISR_TIMER0_OVF ; Vector ISR del timer0

//******************************************************************************
; VARIABLES
//******************************************************************************
.equ DISPLAY_PORT = PORTD       ; Puerto para el display
.equ BUTTON_PORT = PINB         ; Puerto para los botones
.equ BUTTON_MASK = (1 << PB1) | (1 << PB2)   ; Máscara para los botones
.equ DISPLAY_MASK = 0x7F        ; Máscara para el display
.equ DEBOUNCE_THRESHOLD = 10     ; Umbral de anti-rebote
.equ LED_PORT = PORTC            ; Puerto para los LEDs
.equ LED_MASK = 0x0F             ; Máscara para los LEDs

//******************************************************************************
; TABLA DE SEGMENTOS
//******************************************************************************
TABLA: .DB 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7C, 0x07, 0x7F, 0x6F

//******************************************************************************
; CONFIGURACIÓN
//******************************************************************************
MAIN:
    ; STACK POINTER
    LDI R16, LOW(RAMEND)
    OUT SPL, R16
    LDI R16, HIGH(RAMEND)
    OUT SPH, R16

    ; Configuración de puertos
    LDI R16, (1 << PCIE0)
    STS PCICR, R16  ; Habilitando PCINT 0-7 

    LDI R16, BUTTON_MASK
    OUT DDRB, R16   ; Configurar PB1 y PB2 como entrada
    LDI R16, (1 << PCINT1)|(1 << PCINT2)
    STS PCMSK0, R16  ; Registro de la mascara

    LDI R16, DISPLAY_MASK
    OUT DDRD, R16   ; Configurar PD0 a PD6 Como salida

    ; Configuración del timer0
    LDI R16, (1 << CS02)|(1 << CS00) ; Prescaler de 1024
    OUT TCCR0B, R16

    LDI R16, (1 << TOIE0) ; Habilitar interrupción de overflow
    STS TIMSK0, R16

    ; Configuración del puerto C como salida para los LEDs
    LDI R16, LED_MASK
    OUT DDRC, R16   ; Configurar todo el puerto C como salida

    ; Habilitar interrupciones globales
    SEI

    ; Inicializar contadores
    CLR R22 ; Unidades
    CLR R21 ; Decenas

    RJMP LOOP

//******************************************************************************
; LOOP PRINCIPAL
//******************************************************************************
LOOP:
    ; Mostrar unidades
    CALL DISPLAY_NUMBER
    NOP
    SBI DISPLAY_PORT, PD7 ; Habilitar display 1

    ; Retardar para visualizar
    CALL DELAY

    ; Apagar display 1
    CBI DISPLAY_PORT, PD7

    ; Mostrar decenas
    LDI ZL, LOW(TABLA) ; Puntero a la tabla
    ADD ZL, R21 ; Ajuste para decenas
    CALL DISPLAY_NUMBER
    NOP
    SBI DISPLAY_PORT, PD6 ; Habilitar display 2

    ; Retardar para visualizar
    CALL DELAY

    ; Apagar display 2
    CBI DISPLAY_PORT, PD6

    RJMP LOOP

//******************************************************************************
; FUNCIONES
//******************************************************************************
; Función para mostrar en el display
DISPLAY_NUMBER:
    ; Carga el dígito en el registro R25
    MOV R25, R16

    ; Ajusta el dígito para la tabla de segmentos
    CPI R25, 10
    BRCS SKIP_ADJUSTMENT
    SUBI R25, 10
    SKIP_ADJUSTMENT:

    ; Carga el segmento correspondiente
    LPM R25, Z+
    OUT DISPLAY_PORT, R25
    RET

; Función para el retardo
DELAY:
    LDI R24, 10 ; Valor de retardo
DELAY_LOOP:
    NOP
    DEC R24
    BRNE DELAY_LOOP
    RET

//******************************************************************************
; INTERRUPCIÓN DEL BOTÓN
//******************************************************************************
ISR_PCINT0:
    ; Conteo del botón
    LDI R18, DEBOUNCE_THRESHOLD     ; Cargar umbral de anti-rebote

    ; Debounce
    LDI R19, 0                      ; Inicializar contador de debounce
    DEBOUNCE_LOOP:
        SBIC BUTTON_PORT, PB1       ; Verificar si el botón está presionado
        RJMP DEBOUNCE_RESET         ; Reiniciar debounce si el botón no está presionado
        NOP                         ; Sin operación para retardo
        DEC R18                     ; Decrementar el contador de debounce
        BRNE DEBOUNCE_LOOP          ; Saltar si el contador de debounce no es cero
        INC R19                     ; Incrementar el contador de debounce completado
        JMP DEBOUNCE_RESET          ; Reiniciar el contador de debounce
    DEBOUNCE_RESET:

    ; Aumentar o disminuir
    SBIS BUTTON_PORT, PB2           ; Verificar si el botón de decremento está presionado
    RJMP DECREMENT                   ; Saltar a la rutina de decremento
    INCREMENT:
        CPI R22, 9                   ; Comparar si el valor de las unidades es 9
        BRNE INCREMENT_DONE          ; Saltar si no es 9
        CLR R22                      ; Limpiar las unidades si es 9
        INC R21                      ; Incrementar las decenas
    INCREMENT_DONE:
        INC R22                      ; Incrementar las unidades
        RJMP EXIT                     ; Saltar al final de la interrupción

    DECREMENT:
        CPI R22, 0                   ; Comparar si el valor de las unidades es 0
        BRNE DECREMENT_DONE          ; Saltar si no es 0
        LDI R22, 9                   ; Cargar 9 si es 0
        DEC R21                      ; Decrementar las decenas
    DECREMENT_DONE:
        DEC R22                      ; Decrementar las unidades

    EXIT:
        ; Encender LEDs en el puerto C
        OUT LED_PORT, R22           ; Mostrar las unidades en los LEDs
        RJMP LOOP                    ; Saltar al bucle principal

//******************************************************************************
; INTERRUPCIÓN DEL TIMER0
//******************************************************************************
ISR_TIMER0_OVF:
    ; Incrementar contador de tiempo
    INC R23
    RETI                             ; Retornar desde la interrupción

