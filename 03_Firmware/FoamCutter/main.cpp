/*
  main.c - An embedded CNC Controller with rs274/ngc (g-code) support
  Part of Grbl

   The MIT License (MIT)

  GRBL(tm) - Embedded CNC g-code interpreter and motion-controller
  Copyright (c) 2009-2011 Simen Svale Skogsrud
  Copyright (c) 2011-2013 Sungeun K. Jeon

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

/* A big thanks to Alden Hart of Synthetos, supplier of grblshield and TinyG, who has
   been integral throughout the development of the higher level details of Grbl, as well
   as being a consistent sounding board for the future of accessible and free CNC. */

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
#include "lcd.h"
#include "fan.h"
#include "hotwire.h"


// Declare system global variable structure
system_t sys;

int main(void)
{
  

  
   
  // Initialize system
  serial_init();          // Setup serial baud rate and interrupts
  settings_init();        // Load grbl settings from EEPROM
  lcd_init();             // setup the lcd display
  

  st_init();              // Setup stepper pins and interrupt timers
  sei();                  // Enable interrupts

    
  memset(&sys, 0, sizeof(sys));  // Clear all system variables
  sys.abort = true;   // Set abort to complete initialization
  sys.state = STATE_INIT;  // Set alarm state to indicate unknown initial position

  for(;;) {

    // Execute system reset upon a system abort, where the main program will return to this loop.
    // Once here, it is safe to re-initialize the system. At startup, the system will automatically
    // reset to finish the initialization process.
    if (sys.abort) {
      // Reset system.
      serial_reset_read_buffer(); // Clear serial read buffer
      plan_init(); // Clear block buffer and planner variables
      gc_init(); // Set g-code parser to default state
      protocol_init(); // Clear incoming line data and execute startup lines
      
      limits_init();
      fan_init();             // setup the fans
      hotwire_init();         // setup the hotwire
  
      st_reset(); // Clear stepper subsystem variables.
      
      // Sync cleared gcode and planner positions to current system position, which is only
      // cleared upon startup, not a reset/abort.
      sys_sync_current_position();

      

      // Reset system variables.
      sys.abort = false;
      sys.execute = 0;
      if (bit_istrue(settings.flags,BITFLAG_AUTO_START)) {
        sys.auto_start = true;
      }

      // Check for and report alarm state after a reset, error, or an initial power up.
      if (sys.state == STATE_ALARM) {
        report_feedback_message(MESSAGE_ALARM_LOCK);
      }
      else {
        // All systems go. Set system to ready and execute startup script.
        sys.state = STATE_IDLE;
        protocol_execute_startup();
      }
    }

    protocol_execute_runtime();
    protocol_process();             // ... process the serial protocol
    
    lcd_process();                  // ... lcd, menu, buttons
                                    // ... process gcode from sd-card
  }
  return 0;   /* never reached */
}
