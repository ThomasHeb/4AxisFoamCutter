

#ifndef fan_h
#define fan_h
#include <avr/interrupt.h>
#include "fastio.h"

void fan_init();
void fan_run(uint8_t on, float pwr);             // on = 0:  off
                                                 // on = !0: on 
                                                 // pwr: 0.....100 as power of fan in %               
void fan_off();

uint8_t fan_state();
float fan_pwr();
#endif
