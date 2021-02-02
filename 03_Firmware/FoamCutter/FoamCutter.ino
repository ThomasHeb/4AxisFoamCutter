/*
  Part of Grbl

  The MIT License (MIT)

  GRBL(tm) - Embedded CNC g-code interpreter and motion-controller
  Copyright (c) 2009-2011 Simen Svale Skogsrud
  Copyright (c) 2011-2013 Sungeun K. Jeon
  Copyright (c) 2020      Thomas Heberlein for Foam Cutter modifications
  Copyright (c) 2021      Thomas Heberlein for Laser Cutter modifications
  
  
  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.
*/

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
// Build for Foam Cutter
// =================================================================================================================================================================================
// Goto config.h and enable "#define FOAM_CUTTER" to compile for Foam Cutter
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
//
//    - 4x/8x Limit Switch NC
//      - X-axis on X- S/- on Ramps (1st from left, top view)
//      - Y-axis on X+ S/- on Ramps (2nd from left, top view)
//      - U-axis on Y- S/- on Ramps (3rd from left, top view)
//      - Z-axis on Y+ S/- on Ramps (4th from left, top view)
//      - to reduce EMC connect 100 nF between S and - close to Ramps
//
//      - if you do not want to use limit switches in general, 
//        set USE_LIMIT_SWITCHES to 0, see config.h 
// 
//  - Powersupply DC/DC Converter for Arduino set to 12V DC
//    https://www.amazon.de/gp/product/B00HV4EPG8/ref=ppx_yo_dt_b_asin_title_o01_s01?ie=UTF8&psc=1
//  - Fans 12V DC for cooling Stepper Driver, Ramps, Power Supply,....
//  - 2x LED + 2x 2k2 to GND
//    - Hotwire:    D65
//    - Speed:      D66
//  - 12x Buttons NO, connected to GND 
//    - Stopp:      D63     do not change, the stopp button is monitored by IRQ
//    - Back:       D59    
//    - Hotwire:    D40
//    - Speed:      D44     used to change between feed & seek during positioning
//    - X minus:    D42
//    - X plus:     D6   
//    - Y minus:    D58
//    - Y plus:     D64  
//    - U minus:    D57
//    - U plus:     D5  
//    - Z minus:    D4
//    - Z plus:     D11  
// 
//    - if you do not want to use buttons in general, 
//      set USE_BUTTONS to 0, see config.h 
// 
// Modifications of Hardware:
//  - cut-off Arduino PIN 10 on Ramps (not required if no Fan is connectet) 
//  - connect Arduino Pin 7 on Ramps to Socket of PIN 10 (not required if no Fan is connectet) 
//  - to reduce EMC connect 100 nF between S and - close to Ramps for limit switches
//  - to reduce EMC connect 100 nF between D63 and GND directly on Ramps pin header for AUX-2 (not required if stopp button is close to ramps) 
//
// Connections:
//  - Ramps 3/4: (5A) 12V DC Powersupply for Arduino / Stepper / ... from DC/DC converter
//  - Ramps 1/2: (11A) Powersupply for hot wire. app 28V DC
//  - Ramps D10: Fans
//  - Ramps D8:  Hot wire




// =================================================================================================================================================================================
// Build for Laser Cutter
// =================================================================================================================================================================================
// Goto config.h and enable "#define LASER_CUTTER" to compile for Laser Cutter
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
//
//    - 2x/4x Limit Switch NC
//      - X-axis on X- S/- on Ramps (1st from left, top view)
//      - Y-axis on X+ S/- on Ramps (2nd from left, top view)
//      - to reduce EMC connect 100 nF between S and - close to Ramps
//
//      - if you do not want to use limit switches in general, 
//        set USE_LIMIT_SWITCHES to 0, see config.h 
// 
//  - 1x Buttons NO, connected to GND
//    - Stopp:      D63     do not change, the stopp button is monitored by IRQ
// 
//  - 1x Buttons NO, optional soldered in parralel to the button on the display PCB
//    This operates as the back button, in addition to the button on the display PCB
//
//  - Laser module
//    I.e. NEJE 20W 450nm, 5,5W with PWM controll
//    https://www.banggood.com/de/NEJE-20W-Laser-Module-DIY-Kit-450nm-Professional-Continuous-5_5W-Laser-Cutting-Engraving-Module-Blue-Light-with-TTL-or-PWM-Modulation-for-Laser-Cutting-or-Engraving-Machine-CNC-DIY-Laser-Compatible-with-Arduino-p-1678967.html
//
//  - Powersupply: 
//    Check the supply Voltage of your Laser, if it is in the Range of 9 to 17 V DC, 
//    you can supply the Arduino and the Laser with a single Voltage SourceDC/DC Converter for Arduino set to 12V DC.
//    If your Laser needs more or different voltage then the Arduino, you can use a DC/DC voltage converter to 
//    supply the Arduino nor the laser from that source.
//    https://www.amazon.de/gp/product/B00HV4EPG8/ref=ppx_yo_dt_b_asin_title_o01_s01?ie=UTF8&psc=1
// 
// Modifications of Hardware:
//  - to reduce EMC connect 100 nF between S and - close to Ramps for limit switches 
//  - to reduce EMC connect 100 nF between D63 and GND directly on Ramps pin header for AUX-2 (not required if stopp button is close to ramps) 
//  - connect Pin D8 and GND from Arduino on the Ramps Board to drive the TTL control input on the laser (D8 Mosfet on Ramps is not direct usable due to low side switching)
//
// Connections:
//  - Ramps 3/4: (5A)  12V DC Powersupply for Arduino / Stepper 
//  - Pin D8 directly from Arduino and GND: TTL control signal for the laser




// =================================================================================================================================================================================
// Changes
// =================================================================================================================================================================================
// 15.12.2020   TH  Added LaserCutter, X/Y-Axis, w/o Buttons, only e-stop on D63, reduced menu.
// 17.01.2021   TH  Execution of M3/4/5 and Sxx commands to power the laser (or hotwire) should be syncrone to gcode line execution.
//                  Control of tool is transfered from gcode.cpp level to stepper.cpp level. this ensures that motion-calculation and planner scheduling is involved.
//                  stepper.cpp irq executes commands. Be aware a pure M-command does not call motion/planer/stepper
//                  combined hotwire and laser to common tool. 
//                  limit switches and e-stopp handling improved (debouncing, irq handling, improved start-up with 100nF on e-stopp)
//                  optimzed used of feed/seek rate and homing feed/seek rate
//                  error report on display for limit switches / estopp (critical errors)












// TODO
// U Achse fährt nicht kontinuierlich... gcode / motion control ansehen
