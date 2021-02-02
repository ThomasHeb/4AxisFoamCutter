#ifndef limits_h
#define limits_h


// Initialize the limits module
void limits_init();

// enable/disables hard limits.
void limits_enable();
void limits_disable();

// Perform one portion of the homing cycle based on the input settings.
void limits_go_home();



#endif
