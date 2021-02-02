#include "fan.h"
#include "pin_map.h"
#include "settings.h"

#ifdef FOAM_CUTTER
typedef struct {
  uint8_t state;                   // 0 = off, !0 = on
  float   pwr;                     // fan power 0...100%          
      
} fan_t;
fan_t fan_data;


void fan_off() {
  fan_data.state      =  0;
  TCCR4A              &= 0b11001111; // Disable PWM. Output voltage is zero.
}


void fan_init() {
  fan_data.pwr  =  settings.fan_pwr;
   
  SET_OUTPUT(PIN_FAN);
  WRITE(PIN_FAN,0);
  // configure timer 4
  TCCR4A |= (1 << WGM41);  // | (1 << WGM40);  // mode 14, fast pwm, set on start, clear on compare
  TCCR4B |= (1 << CS40) | (1 << WGM43) | (1 << WGM42);    // Prescaler 1/1 
  ICR4    = 2047;   // maximal 2048 steps resolution
  
  fan_off();  
}



void fan_run(uint8_t on, float pwr) {            // on = 0:  off
                                                     // on = !0: on 
                                                     // pwr: 0.....100 as power of hotwire in %
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
  
  if ((on == 0) || (utemp == 0)) {
    fan_off();
    return;
  }
  
  if (pwr > 0) {
    fan_data.pwr = pwr;
  }
  

  TCCR4A |= (1 << COM4B1);
  OCR4B    = utemp;
  fan_data.state = 1;
}

uint8_t fan_state() {
  return fan_data.state;
}

float fan_pwr() {
  return fan_data.pwr;
}
#endif
