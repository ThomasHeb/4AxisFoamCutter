#ifndef stepper_h
#define stepper_h

#include <avr/io.h>

// Initialize and setup the stepper motor subsystem
void st_init();

// Enable steppers, but cycle does not start unless called by motion control or runtime command.
void st_wake_up();

// Immediately disables steppers
void st_go_idle();

// Forces the steppers to go idle, use for manual idle command
void st_force_idle();

// Reset the stepper subsystem variables
void st_reset();

// Notify the stepper subsystem to start executing the g-code program in buffer.
void st_cycle_start();

// Reinitializes the buffer after a feed hold for a resume.
void st_cycle_reinitialize();

// Initiates a feed hold of the running program
void st_feed_hold();

#endif
