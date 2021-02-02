#ifndef protocol_h
#define protocol_h

#include <avr/sleep.h>
/// 8c1
#include "config.h"    // LINE_BUFFER_SIZE

// Line buffer size from the serial input stream to be executed.
// NOTE: Not a problem except for extreme cases, but the line buffer size can be too small
// and g-code blocks can get truncated. Officially, the g-code standards support up to 256
// characters. In future versions, this will be increased, when we know how much extra
// memory space we can invest into here or we re-write the g-code parser not to have his
// buffer.
#ifndef LINE_BUFFER_SIZE
 // #define LINE_BUFFER_SIZE 70
  #error
#endif

// Initialize the serial protocol
void protocol_init();

// Read command lines from the serial port and execute them as they
// come in. Blocks until the serial buffer is emptied.
void protocol_process();

// Executes one line of input according to protocol
uint8_t protocol_execute_line(char *line);

// Checks and executes a runtime command at various stop points in main program
void protocol_execute_runtime();

// Execute the startup script lines stored in EEPROM upon initialization
void protocol_execute_startup();


// Block until all buffered steps are executed or in a cycle state. Works with feed hold
// during a synchronize call, if it should happen. Also, waits for clean cycle end.
// syncronized all executions with motions
void protocol_buffer_synchronize();

#endif
