# Firmware
The firmware is based on the grbl version 8c2 modified for foam cutter, a modified version of U8G2 library for the display and SdFat with no changes.

Links to the original 
- [grbl 8c2 foam](https://www.rcgroups.com/forums/showthread.php?2915801-4-Axis-Hot-Wire-CNC-%28Arduino-Ramps1-4%29-Complete-Solution)
- [U8G2 Lib by Oli Kraus, tested with version 2.27.6](https://github.com/olikraus/u8g2)
- [SdFat by Bill Greiman, tested with version 1.2.3](https://github.com/greiman/SdFat)

Many thanks to you, for writing and sharing this fantastic code.

### How to install:
- Download the foamcutter firmware
- Download the libraries
  - directly from this github (recommended):
    download: https://github.com/ThomasHeb/4AxisFoamCutter/tree/master/03_Firmware/libraries
    store in your ../Arduino/libraries/ folder (prefered, because updates of the original libraries may cause problems with grbl)
  - or from the original authors (not reccomended, updates of the lobrary may cause problems):   
    Download the U8G2 lib (GitHub or via the Arduino IDE)  
    Download the SdFat lib (GitHub or via the Arduino IDE)
    Open ../Arduino/libraries/U8G2/src and replace U8x8lib.h and U8x8Lib.cpp from the code section

### Changes within the library U8G2 - only for information:
Grbl uses almost all resources of the Arduino to control the stepper within an accurate timing. So the standard approach of Arduino is not working any more, because some resources are not available anymore for the Arduino framework. Within the U8G2 I use a software driven SPI on pin D50 to D52 (I didn’t check, if hardware driven SPI would work, too). The only thing I needed to change, was the required delay within the SPI. Therefore I changed the delay function to the grbl supported delay function.


### LCD, SD card and buttons, ….
The LCD display and the buttons are controlled inside the lcd.h and lcd.cpp. Buttons are read within the lcd_process(), from where all processing functions of the sub menus are called.
Functions within the sub menus, which are related to cnc functionality are called as if they would have been called via UART/USB. So you will get an ok over the UART/USB for a local called cnc command, too. The firmware can still be controlled with gcode sender tools via the UART/USB.
SD card is processed inside lcd.cpp and lcd_process(), too. Processing of the SD card is handled with a state machine, which reads the selected file char by char, similar as reading the UART. 
During processing a file from SD card, buttons are ignored, operation can only be stopped with an IRQ of the limit switches or the e-stop.
Fan can only be controlled locally on the display. Hotwire can be controlled via the display and with the gcode commands M3/4 for on and M5 for off and Sxxx (0…100) for regulating the power in %.

Please have a lock at the parameters (command $$ over Serial Monitor)

![grbl settings](https://github.com/ThomasHeb/4AxisFoamCutter/blob/master/img/grbl_settings.png)

[Video Firmware](https://youtu.be/fht_X7mQ-qg)



### Functions on local display / buttons
- e-stop: IRQ based local stop, this does not match the requirements of any safety standard (not available, if USE_BUTTONS is set to 0)
- Idle stepper
- Homing (not available, if USE_BUTTONS is set to 0)
  - homing including pull-off
  - set current position as new pull off position: This function is used to travel from limit switches to machine zero position. Adjust the position with the position menu
- Position
  - adjust each axis independent
  - set or travel to a temporary home position
  - set or travel to a temporary zero position
  - 8 buttons to control the movements (not available, if USE_BUTTONS is set to 0)
  - switch speed between feed and homing seek for fast traveling (selected homing seek speed is indicated by LED
- SD-Card
  - read file list from SD-Card (only with defined file extensions (config.h), only from root directory, keep filenames short)
  - valid gcode file extensions: .nc, .gcode (you may change the file extension to oneof these)
  - execute a file from the SD-Card
  - visualise the progress (bytes read and send to gcode processing, not bytes really executed)
- Hotwire
  - switch on/off or change the power in %. New value is stored in the eeprom
  - switch on/off with button (not available, if USE_BUTTONS is set to 0)
  - indicate status with LED
- Feed speed 
  - select the feed speed
  - new value is stored in the eeprom
  - if gcode includes feed rates, gcode values are used.
  - adjust in big steps with Y- / Y+ buttons (not available, if USE_BUTTONS is set to 0)
- Slicing (previous function name: Cutting)
  - this functions allows horizontal or vertical slicing w/o gcode
  - select the slicing direction with the 8 buttons for the axis (not available, if USE_BUTTONS is set to 0, direction is selected with jog)
  - define the maximum x/y travel for slicing (use position menue)
  - executes a cut by preheating the hotwire for 5 seconds
  - move back to starting position of the slice with seek-speed
- Fan
  - switch on/off or change the power in %. New value is stored in the eeprom
- The firmware can still be controlled with gcode sender tools via the UART/USB 

- [Video: Functions](https://youtu.be/SWv79BavgKs)

### How to start:
Please refer to grbl documentation for parameter settings and first steps. A good point to start is to:
- disable limit switches and homing cycle (not required, if USE_LIMIT_SWITCHES is set to 0)
- set the steps per mm for each axis
- check the direction and adjust with "step port invert mask"
- check travel distances and optimize
- activate homing cycle and check directions and adjust with "homing dir invert mask" (not required, if USE_LIMIT_SWITCHES is set to 0)
- a good setting to start is feedrate 300 mm/min, hotwire 80% on 30V DC for 75 cm hotwire


