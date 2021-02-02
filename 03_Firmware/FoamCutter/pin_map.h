#ifndef pin_map_h
#define pin_map_h
#include "config.h"    


//************************************************************************************************
//Adaptado para RAMPS 1.4:
#ifdef PIN_MAP_ARDUINO_MEGA_2560
  // For a custom pin map or different processor, copy and paste one of the default pin map
  // settings above and modify it to your needs. Then, make sure the defined name is also
  // changed in the config.h file.


  // Serial port pins
  #define SERIAL_RX         USART0_RX_vect
  #define SERIAL_UDRE       USART0_UDRE_vect

  // ======================================================================================
  // Stepper
  // NOTE: All step bit and direction pins must be on the same port.
  #define STEPPING_DDR      DDRA
  #define STEPPING_PORT     PORTA
  #define STEPPING_PIN      PINA
  #define X_STEP_BIT        2 // MEGA2560 Digital Pin 24
  #define Y_STEP_BIT        3 // MEGA2560 Digital Pin 25
  #define Z_STEP_BIT        4 // MEGA2560 Digital Pin 26
  #define U_STEP_BIT        1 // MEGA2560 Digital Pin 23

  #define X_DIRECTION_BIT   5 // MEGA2560 Digital Pin 27
  #define Y_DIRECTION_BIT   6 // MEGA2560 Digital Pin 28
  #define Z_DIRECTION_BIT   7 // MEGA2560 Digital Pin 29
  #define U_DIRECTION_BIT   0 // MEGA2560 Digital Pin 22
  // All step bits
  #define STEP_MASK         ((1<<X_STEP_BIT)|(1<<Y_STEP_BIT)|(1<<Z_STEP_BIT)|(1<<U_STEP_BIT) )
  // All direction bits
  #define DIRECTION_MASK    ((1<<X_DIRECTION_BIT)|(1<<Y_DIRECTION_BIT)|(1<<Z_DIRECTION_BIT)|(1<<U_DIRECTION_BIT))

  // All stepping-related bits (step/direction)
  #define STEPPING_MASK     (STEP_MASK | DIRECTION_MASK)

  // Define stepper driver enable/disable output pin.
  #define STEPPERS_DISABLE_DDR    DDRB
  #define STEPPERS_DISABLE_PORT   PORTB
  #define STEPPERS_DISABLE_BIT    7  // MEGA2560 Digital Pin 13
  // STEPPERS_DISABLE_INVERT: Set to 0 for active high stepper disable or 1
  // for active low stepper disable.
  #define STEPPERS_DISABLE_INVERT 0
  #define STEPPERS_DISABLE_MASK (1<<STEPPERS_DISABLE_BIT)
  
  // ======================================================================================
  // Hard Limits
  #define PIN_LIMIT_U         14    // MEGA2560 Digital Pin 14 / PCINT10
  #define PIN_LIMIT_Z         15    // MEGA2560 Digital Pin 15 / PCINT9
 
  
  #define PIN_LIMIT_X         3     // MEGA2560 Digital Pin 3 / INT5
  #define PIN_LIMIT_Y         2     // MEGA2560 Digital Pin 2 / INT4
  
  // ======================================================================================
 

 
  ////////Set Timer up to use TIMER4C which is attached to Digital Pin 8
  #define PWM_MAX_VALUE     255
  #define TCCRA_REGISTER    TCCR4A
  #define TCCRB_REGISTER    TCCR4B
  #define OCR_REGISTER      OCR4C
  #define OCR_REGISTER_TOP  ICR4
  
  #define COMB_BIT          COM4C1
  #define WAVE0_REGISTER    WGM40
  #define WAVE1_REGISTER    WGM41
  #define WAVE2_REGISTER    WGM42
  #define WAVE3_REGISTER    WGM43
  
  
  
  #define X_STEP_PIN         26 // E0 Position on Ramps
  #define X_DIR_PIN          28 
  #define X_ENABLE_PIN       24 
  
  #define Y_STEP_PIN         36 // E1 Position on Ramps
  #define Y_DIR_PIN          34 
  #define Y_ENABLE_PIN       30 
  
  #define Z_STEP_PIN         46 // Z Position on Ramps
  #define Z_DIR_PIN          48 
  #define Z_ENABLE_PIN       62 
  
  #define U_STEP_PIN         60 // Y Position on Ramps
  #define U_DIR_PIN          61 
  #define U_ENABLE_PIN       56 
  
  // not used
  #define E1_STEP_PIN         54 //36 
  #define E1_DIR_PIN          55 //34
  #define E1_ENABLE_PIN       58 //30
  
  
  #define PIN_FAN             7     // MEGA2560 Digital Pin 7
  #define PIN_TOOL            8     // MEGA2560 Digital Pin 8
  
  
  // RepRapDiscount FullGraphic Smart Controller
  #define PIN_LCD_E           23
  #define PIN_LCD_RW          17
  #define PIN_LCD_RS          16
  #define PIN_LCD_RST         U8X8_PIN_NONE
  
  #define PIN_BEEPER          37
  
  // Buttons
  #define PIN_BTN_ONBOARD     41
  
  #define PIN_BTN_STOP        63
  #define PIN_BTN_BACK        59
  #define PIN_BTN_HOTWIRE     40
  
  #define PIN_BTN_SPEED       44
  #define PIN_LED_HOTWIRE     65
  #define PIN_LED_SPEED       66
  
  #define PIN_BTN_X_MINUS     42
  #define PIN_BTN_X_PLUS      6
  #define PIN_BTN_Y_MINUS     58
  #define PIN_BTN_Y_PLUS      64
  #define PIN_BTN_U_MINUS     57
  #define PIN_BTN_U_PLUS      5
  #define PIN_BTN_Z_MINUS     4
  #define PIN_BTN_Z_PLUS      11
  
  // Rotary Button
  #define PIN_ENC             35
  #define PIN_EN1             33
  #define PIN_EN2             31
  
  // SD-Card
  #define PIN_SD_CS           53
  #define PIN_SD_DET          49
  #define PIN_SD_CLK          52
  #define PIN_SD_MISO         50
  #define PIN_SD_MOSI         51


#endif
//***************************************************************************************************

#endif
