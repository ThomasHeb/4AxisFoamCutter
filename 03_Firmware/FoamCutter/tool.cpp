#include "tool.h"
#include "pin_map.h"
#include "settings.h"
#include "gcode.h"


void tool_off() {
  gc.tool_state         = 5;                          // M5
  TCCR4A                &= 0b11110011;                // Disable PWM. Output voltage is zero.  
#ifdef FOAM_CUTTER
  WRITE(PIN_LED_HOTWIRE, 0); 
#endif
}


void tool_init() {
  gc.tool_pwr           = settings.tool_pwr;          // start with default power for tool

#ifdef FOAM_CUTTER
  SET_OUTPUT(PIN_LED_HOTWIRE);
#endif
  SET_OUTPUT(PIN_TOOL);
  WRITE(PIN_TOOL,0);
  
  // configure timer 4
  TCCR4A |= (1 << WGM41);  // | (1 << WGM40);  // mode 14, fast pwm, set on start, clear on compare
  TCCR4B |= (1 << CS40) | (1 << WGM43) | (1 << WGM42);    // Prescaler 1/1 
  ICR4    = 2047;   // maximal 2048 steps resolution
  
  tool_off();
}

void tool_run(int8_t state, float pwr) {            // state: 3 = M3   on
                                                    // state: 4 = M4   on
                                                    // state: 5 = M5   off
                                                    // pwr: 0.....100 as power of laser in %
  uint16_t utemp = 0;
  float    ftemp = 0;

  ftemp   = pwr;
  ftemp  *= 2047;
  ftemp  /= 100;
  
  if (ftemp > 2047) {
    utemp = 2047;
  } else if (ftemp < 0) {
    utemp = 0;
  } else {
    utemp = (uint16_t)ftemp; 
  }

  // perform a hard switch off
  if ((state != 3) && (state != 4)) {
    tool_off();
    return;
  }

  
#ifdef FOAM_CUTTER
  WRITE(PIN_LED_HOTWIRE, 1); 
#endif

  // otherwise update the parameter tool_state and tool_pwr
  gc.tool_state  = state; 
  if (pwr >= 0) {
    gc.tool_pwr = pwr;
  }

  // if tool_power = 0, disablee the pwm
  if (utemp == 0) {
    TCCR4A                &= 0b11110011;          // Disable PWM. Output voltage is zero.  
    return;
  }
  
  // otherwise set and start the timer for the pwm
  TCCR4A      |= (1 << COM4C1);
  OCR4C       = utemp;
}


void tool_isr(int8_t state, float pwr) {
  
  uint16_t utemp = 0;
  float    ftemp = 0;

  ftemp   = pwr;
  ftemp  *= 2047;
  ftemp  /= 100;
  
  if (ftemp > 2047) {
    utemp = 2047;
  } else if (ftemp < 0) {
    utemp = 0;
  } else {
    utemp = (uint16_t)ftemp; 
  }
  

  switch (state) {      // [M3,M4,M5]
    case 3:     
    case 4:     
#ifdef FOAM_CUTTER
                WRITE(PIN_LED_HOTWIRE, 1); 
#endif
                break;
    case 5:     TCCR4A                &= 0b11110011;                // Disable PWM. Output voltage is zero.
                return;
                break;
    default:    TCCR4A                &= 0b11110011;                // Disable PWM. Output voltage is zero.
#ifdef FOAM_CUTTER
                WRITE(PIN_LED_HOTWIRE, 0); 
#endif
                return;
                break;
  }
  
  // if tool_power = 0, disablee the pwm
  if (utemp == 0) {
    TCCR4A                &= 0b11110011;          // Disable PWM. Output voltage is zero.  
    return;
  }
  
  // otherwise set and start the timer for the pwm
  TCCR4A      |= (1 << COM4C1);
  OCR4C       = utemp;
}
