#include "hotwire.h"
#include "pin_map.h"
#include "settings.h"
#include "gcode.h"

void hotwire_off() {
  gc.hotwire            = 0;
  TCCR4A                &= 0b11110011;          // Disable PWM. Output voltage is zero.
  WRITE(PIN_LED_HOTWIRE, 0);   
}


void hotwire_init() {
  gc.hotwire_pwr   =  settings.hotwire_pwr;     // start with default temperature for hotwire
  
  SET_OUTPUT(PIN_LED_HOTWIRE);
  SET_OUTPUT(PIN_HOTWIRE);
  WRITE(PIN_HOTWIRE,0);
  
  // configure timer 4
  TCCR4A |= (1 << WGM41);  // | (1 << WGM40);  // mode 14, fast pwm, set on start, clear on compare
  TCCR4B |= (1 << CS41) | (1 << WGM43) | (1 << WGM42);    // Prescaler 1/8
  ICR4    = 255;
  
  hotwire_off();
}

void hotwire_run(uint8_t on, float pwr) {            // on = 0:  off
                                                     // on = !0: on 
                                                     // pwr: 0.....100 as power of hotwire in %
  uint8_t utemp = 0;
  pwr *= 255;
  pwr /= 100;

  if (pwr > 255) {
    utemp = 255;
  } else if (pwr < 0) {
    utemp = 0;
  } else {
    utemp = (uint8_t)pwr; 
  }

  
  if ((on == 0) || (utemp == 0)) {
    hotwire_off();
    return;
  }
  
  if (pwr > 0) {
    gc.hotwire_pwr = pwr;
  }

  // set and start the timer
  TCCR4A      |= (1 << COM4C1);
  OCR4C       = utemp;
  gc.hotwire  = 1;

  WRITE(PIN_LED_HOTWIRE, 1);   
}
