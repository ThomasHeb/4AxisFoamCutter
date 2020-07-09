#include <avr/interrupt.h>
#include <avr/pgmspace.h>
#include "config.h"
#include "planner.h"
#include "nuts_bolts.h"
#include "stepper.h"

#include "motion_control.h"
#include "gcode.h"
#include "protocol.h"
#include "limits.h"
#include "report.h"
#include "settings.h"
#include "serial.h"
#include "fastio.h"
#include "lcd.h"

// =================================================================================================================================================================================
// Build
// =================================================================================================================================================================================
// Hardware:
//  - Arduino Mega 2560 
//    https://www.reichelt.de/arduino-mega-2560-atmega-2560-usb-arduino-mega-p119696.html?&nbc=1&trstct=lsbght_sldr::226825
//  - Ramps 1.4 
//    https://www.reichelt.de/arduino-3d-drucker-ramps-kit-1-4-a4988-ard-ramps-kit-1-p226825.html?&trstct=pos_0&nbc=1
//    https://www.roboter-bausatz.de/152/ramps-1.4-kit-12864-lcd-controller
//    - Display, Jog and SD-Card-Reader (RepRap)
//    - 4x Driver A4988 (or DRV8825 or ....), set the current limit https://www.makerguides.com/a4988-stepper-motor-driver-arduino-tutorial/
//      - X-axis on E0 socket on Ramps // 1/16 Microsteps (set all three jumpers)
//      - Y-axis on E1 socket on Ramps // 1/16 Microsteps (set all three jumpers)
//      - U-axis on Y Socket on Ramps  // 1/16 Microsteps (set all three jumpers)
//      - Z-axis on Z socket on Ramps  // 1/16 Microsteps (set all three jumpers)

//    - 4x/8x Limit Switch NC
//      - X-axis on X- S/- on Ramps (1st from left)
//      - Y-axis on X+ S/- on Ramps (2nd from left)
//      - U-axis on Y- S/- on Ramps (3rd from left)
//      - Z-axis on Y+ S/- on Ramps (4th from left)
//      - to reduce EMC connect 100 nF between S and - close to Ramps
//  - Powersupply DC/DC Converter for Arduino set to 12V DC
//    https://www.amazon.de/gp/product/B00HV4EPG8/ref=ppx_yo_dt_b_asin_title_o01_s01?ie=UTF8&psc=1
//  - Fans 12V DC for cooling Stepper Driver, Ramps, Power Supply,....
//  - 2x LED + 2x 2k2 to GND
//    - Hotwire:    D65
//    - unused:     D66
//  - 12x Buttons NO, connected to GND (see pin_map.h)
//    - Stopp:      D63     do not change the stopp button is monitored by IRQ
//    - Back:       D59    
//    - Hotwire:    D40
//    - unused:     D44
//    - X minus:    D42
//    - X plus:     D6   
//    - Y minus:    D58
//    - Y plus:     D64  
//    - U minus:    D57
//    - U plus:     D5  
//    - Z minus:    D4
//    - Z plus:     D11  
// 
// Modifications of Hardware:
//  - cut-off Arduino PIN 10 on Ramps 
//  - connect Arduino Pin 7 on Ramps to Socket off PIN 10
//  - to reduce EMC connect 100 nF between S and - close to Ramps for limit switches / end stopps
//  - to reduce EMC connect 100 nF between D63 and GND directly on Ramps pin header for AUX-2 (not required if stopp button is close to ramps) 
//
// Connections:
//  - Ramps 3/4: (5A) 12V DC Powersupply for Arduino / Stepper / ... from DC/DC converter
//  - Ramps 1/2: (11A) Powersupply for hot wire. app 28V DC
//  - Ramps D10: Fans
//  - Ramps D8:  Hot wire















// TODO
// U Achse fährt nicht kontinuierlich... gcode / motion control ansehen
