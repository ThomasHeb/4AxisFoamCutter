# 4AxisFoamCutter

Arduino based CNC foam cutter with display and SD-Card.
Ruby Script for SketchUp Make 2017 to generate gcode.
Swift base post processing 

My goal was to build a foam based semi scale glider. So a lot of segments and very accurate working would have been necessary. This brought me to the idea to design the glider in SketchUp and build a 4 axis foam cutter.

the base idea ist very simple. four independent linear axis with NEMA 17 stepper and belts. this simple system is satisfying because the accuracy of the belt and stepper is better than the impact of the hot wire, its temperature and feed speed ans almost no force is required to cut the foam. The only mechanical topic is to keep the hot wire stretched. Therefore I found a very good Idea here on GitHub.

For controlling the four axis I found a solutions based on grbl 8c2 in combination with some Windows bases UIs and gcode sender. For generating the wing profiles I found some windows solutions or professional tools, but not free of charge. For the fuselage I found only ra professional tool. As I am a mac-user w/o a computer in the workshop (I don’t want it), I came to my project list.
- 4 independent axis 
- local display, SD card reader and control buttons
- Arduino bases gcode handling, based on grbl 8c2 version adapted for foam cutting.
- fixed frame based on 2020 profiles, v-slot based linear actors (it is my first cnc machine, so there are much easier and better mechanical constructions, have a lock on https://www.rckeith.co.uk)
- only one power supply
- wing design with WingHelper (I have a licence), export of gcode is possible but post process is required
- fuselage design with SketchUp, therefore I wrote a small tool
- post processing to adapt gcode to machine geometry


# Resources
Many thanks to all the guys giving me grad inspirations with their projects
- [rcKeith, Hot wire cutter](www.rckeith.co.uk/cnc-hot-wire-foam-cutter/)
- [4 axis foam cutter](https://github.com/rahulsarchive/4AxisFoamCutter)
- [4 axis foam hotwire cutter](https://www.rcgroups.com/forums/showthread.php?2915801-4-Axis-Hot-Wire-CNC-(Arduino-Ramps1-4)-Complete-Solution)


# Mechanics
- 4x linear v-slot actuator with NEMA 17
- 2020 profiles, screws, nuts
- nichrome wire
- 2-4x Retractable Reel 

# Hardware
- Arduino Mega 2560
- 128x64 LCD Display / SD card reader from RepRap with connector to Ramps 1.4
- Ramps 1.4 
- 4x stepper driver A4988
- 8x micro switch NC as limit switch
- 4x 100nF capacitor
- 12 buttons NO
- 2x LED + resistor 2k2
- DC-DC converter (in: > 30V, out 12V, app. 2A)
- optional: fans 12V
- wire / connector


Most of it is plugged together straight forward. A detailed list is included in the foamcutter.ino file.

TODO: Add Picture here 


### Modifications of Hardware:
- cut-off Arduino PIN 10 on Ramps 
- connect Arduino Pin 7 on Ramps to Socket off PIN 10
- to reduce EMC connect 100 nF between S and - close to Ramps for limit switches / end stops
- to reduce EMC connect 100 nF between D63 and GND directly on Ramps pin header for AUX-2 (not required if stopp button is close to ramps) 


### How to start:
the Arduino and the Ramps board are working without the stepper driver or motors or buttons,…. so only the limit switches should be disabled by setting 4 jumpers to the S and - Pin for X-/X+/Y-/Y+ an the Ramps. After downloading the firmware with the Arduino IDE please use the Serial Monitor (Baudrate 11520) with the [grbl commands](https://github.com/gnea/grbl/wiki/Grbl-v1.1-Commands) to disable hard limits and homing cycle. After testing all axis, SD card, …, you can activate the limit switches (hard limits) and the homing cycle again. If you are not disabling the limit switches, you will get an hard error, which blocks all communication to the Arduino.

# Firmware
The Firmware is based on the grbl version 8c2 modified for foam cutter, a modified version of U8G2 library for the display and SdFat with no changes.

Links to the original 
- [grbl 8c2 foam](https://www.rcgroups.com/forums/showthread.php?2915801-4-Axis-Hot-Wire-CNC-%28Arduino-Ramps1-4%29-Complete-Solution)
- [U8G2 Lib by Oli Kraus, tested with version 2.27.6](https://github.com/olikraus/u8g2)
- [SdFat by Bill Greiman, tested with version 1.2.3](https://github.com/greiman/SdFat)

Many thanks to you, for writing and sharing this fantastic code.

### How to install:
- Download the foamcutter firmware
- Download the U8G2 lib (GitHub or via the Arduino IDE) 
- Download the SdFat lib (GitHub or via the Arduino IDE)
- Open ../Arduino/libraries/U8G2/src and replace U8x8lib.h abd U8x8Lib.cpp

### Changes within the library U8G2:
Grbl uses almost all resources of the Arduino to control the stepper within an accurate timing. So the standard approach of Arduino is not working any more, because some resources are not available anymore for the Arduino framework. Within the U8G2 I use a software driven SPI on pin D50 to D52 (I didn’t check, if hardware driven SPI would work, too). the only thing I need to change, was the required delay within the SPI. Therefore I changes the delay function to the grbl supported delay.


### LCD, SD card and buttons, ….
The LCD display and the buttons are controlled inside the lcd.h and lcd.cpp. buttons are read within the lcd_process(), from where all processing functions of the sub menus are called.
Functions within the sub menus, which are related to cnc functionality are called as if they would have been called via UART/USB. So you will get an ok over the UART/USB for a local called cnc command, too. The firmware can still be controlled with gcode sender tools via the UART/USB.
SD card is processed inside lcd.cpp and lcd_process(), too. processing of the SD card is handled with a state machine, which reads the selected file char by char, similar as reading the UART. 
During processing a file from SD card, buttons are ignored, operation can only be stopped with an IRQ of the limit switches or the e-stop.
Fan can only be controlled locally on the display. Hotwire can be controlled via the display and with the gcode commands M3/4 for on and M5 for off and Sxxx (0…100) for regulating the power in %.

Please have a lock at the parameters (command $$ over Serial Monitor)

ToDo: Bild Parameter
ToDo Link to video firmare



### Functions on local display / buttons
- e-stop: IRQ based local stop, this does not match the requirements of any safety standard
- Idle stepper
- Homing
  - homing including pull-off
  - set current position as new pull off position: this function is used to travel from limit switches to machine zero position. adjust the position with the position menu
- Position
  - adjust each axis independent
  - set or travel to a temporary home position
  - set or travel to a temporary zero position
  - 8 buttons to control the movements
- SD-Card
  - read file list from SD-Card (only with defined file extensions (config.h), only from root directory, keep filenames short)
  - execute a file from the SD-Card
  - visualise the progress (bytes read and send to gcode processing, not bytes really executed)
- Hotwire
  - switch on/off or change the power in %  new value is stored in the eeprom
  - switch on/off with button
  - indicate status with LED
- Feed speed 
  - select the feed speed
  - new value is stored in the eeprom
  - if gcode includes feed rates, gcode values are used.
  - adjust in big steps withY- / Y+ buttons
- Cutting
  - this functions allows horizontal or vertical cutting w/o gcode
  - select the cutting direction with the 8 buttons for the axis
  - define the maximum x/y travel for cutting (use position menue)
  - executes a cut by preheating the hotwire for 5 seconds
- Fan
  - switch on/off or change the power in %  new value is stored in the eeprom
- The firmware can still be controlled with gcode sender tools via the UART/USB 

### How to start:
Please refer to grbl documentation for parameter settings and first steps. A good point to start is to 
- disable limit switches and homing cycle
- set the steps per mm for each axis
- check the direction and adjust with "step port invert mask"
- check travel distances and optimize
- activate homing cycle and check directions and adjust with "homing dir invert mask"


# Working with SketchUp

I use SketchUp for generating the stl-files for my 3D printed parts. I would love to use the easy handling for creating fuselages. I searched the web and found only one tool, which is not supported any more. so I decided to write a small tool or better plug in by myself.

What you need
SketchUp (I am Using SketchUp Make 2017)
Ruby Code Editor
CurviLoft
Download foamcutter.rb

Functionality of foamcutter.rb
Open the ruby code editor first and load and execute the foamcutter.rb. This adds 3 menus to the PlugIn menu. Inside the settings you can define some general settings, like inch/mm, used decimals, labels of the axis.

With the tool itself, you are asked to select 2 paths which are exported as gcode. The paths it self use the green (x and u) and blue (y and z) axis. positioning along the red axis does not matter.

The algorithm searches all related points to an edge. It follows two routes
# 1: go up first (Y/Z +)
# 2: go back first (X/U -)
It uses all edges only once. If you reach a dead end, you may use the third dimension do open up new paths/edges - please keep the rules in mind.

Both paths should have the same number of points and edges. To go for that with more complex objects, it is a good way to use CurviLoft
create your objects
use CurviLoft to generate the surface/area between the objects. 
select to show the related edges between the objects (connection lines)
split these connection lines (ungroup)
select and group the objects (otherwise the object is not splittet in points)
delete the connection lines
use foamcutter tool
select first and second edge
save the file
do the post processing is required

TODO Image

# Post processing

ToDo
 
