
#ifndef lcd_h
#define lcd_h


// Initialize the lcd
void lcd_init();

// processing of lcd, buttons, menu, ....
// process gcode from sd card
void lcd_process();

// displays a status message for critical error on the lcd (e-stopp or limit switch)
void lcd_crit_error();


#endif
