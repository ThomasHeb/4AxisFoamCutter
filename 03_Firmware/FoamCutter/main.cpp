

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
#include "tool.h"


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
      
#ifdef FOAM_CUTTER      
      fan_init();             // setup the fans
#endif
 
      tool_init();            // setup the tool
      st_reset();             // Clear stepper subsystem variables.
      
      // Sync cleared gcode and planner positions to current system position, which is only
      // cleared upon startup, not a reset/abort.
      sys_sync_current_position();

       // Reset system variables.
      sys.abort         = false;
      sys.err           = ERR_NO;     // No error
      sys.execute       = 0;
      if (bit_istrue(settings.flags,BITFLAG_AUTO_START)) {
        sys.auto_start  = true;
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
