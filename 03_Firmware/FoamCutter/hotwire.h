#ifndef hotwire_h
#define hotwire_h
#include <avr/interrupt.h>
#include "fastio.h"

void hotwire_init();
void hotwire_run(uint8_t on, float pwr);             // on = 0:  off
                                                     // on = !0: on 
                                                     // pwr: 0.....100 as power of hotwire in %               
void hotwire_off();

#endif
