#ifndef tool_h
#define tool_h
#include <avr/interrupt.h>
#include "fastio.h"
#include "config.h"


void tool_init();                                // initialisation
void tool_run(int8_t state, float pwr);          // run the tool from the tasklevel (stores current state)
                                                 // state:  5 = M5 / Off
                                                 //         3 = M3 / On
                                                 //         4 = M4 / On
                                                 // pwr:    0...100 in %
void tool_isr(int8_t state, float pwr);          // controll for the tool from isr level (stepper synced) 
                                                 // state:  5 = M5 / Off
                                                 //         3 = M3 / On
                                                 //         4 = M4 / On
                                                 // pwr:    0...100 in %
void tool_off();

#endif
