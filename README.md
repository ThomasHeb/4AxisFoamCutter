# 4AxisFoamCutter

Arduino based CNC foam cutter with display and SD-Card.
Ruby Script for SketchUp Make 2017 to generate gcode.
Swift base post processing 

My goal was to build a foam based semi scale glider. So a lot of segments and very accurate working would have been necessary. This brought me to the idea to design the glider in SketchUp and build a 4 axis foam cutter.

The base idea ist very simple. Four independent linear axis with NEMA 17 stepper and belts. This simple system is satisfying,  because the accuracy of the belt and stepper is better than the impact of the hot wire, it's temperature and feed speed and almost no force is required to cut the foam. The only mechanical topic is to keep the hot wire stretched. Therefore I found a very good idea here on GitHub with retractable reels.

For controlling the four axis I found a solutions based on grbl 8c2 in combination with some Windows bases UIs and gcode sender. For generating the wing profiles I found some windows solutions or professional tools, but not free of charge, neither running on mac. For the fuselage I found only a professional tool. As I don't want a computer in my workshop, the gcode should be executed from a SD card, similar as my 3D printer does.  So I came to my project list:
- 4 independent axis 
- local display, SD card reader and control buttons
- Arduino bases gcode handling, based on grbl 8c2 version adapted for foam cutting.
- fixed frame based on 2020 profiles, v-slot based linear actors (it is my first cnc machine, so there are much easier and better mechanical constructions, have a lock on https://www.rckeith.co.uk)
- only one power supply
- wing design with WingHelper (I have a licence), export of gcode is possible but post process is required
- fuselage design with SketchUp, therefore I wrote a small tool to generate gcode
- post processing to adapt gcode to machine geometry


# Resources
Many thanks to all the guys giving me grad inspirations with their projects
- [rcKeith, Hot wire cutter](https://www.rckeith.co.uk/cnc-hot-wire-foam-cutter/)
- [4 axis foam cutter](https://github.com/rahulsarchive/4AxisFoamCutter)
- [4 axis foam hotwire cutter](https://www.rcgroups.com/forums/showthread.php?2915801-4-Axis-Hot-Wire-CNC-(Arduino-Ramps1-4)-Complete-Solution)

# Videos
- [Mechanic](https://youtu.be/zKdzEoycaa4)
- [Hardware](https://youtu.be/xaXfXsz1NG8)
- [Firmware](https://youtu.be/fht_X7mQ-qg)
- [Functions](https://youtu.be/SWv79BavgKs)
- [Working with SketchUp Part 1](https://youtu.be/MZSXp2stBLk)
- [Working with SketchUp Part 2](https://youtu.be/SIh3zpsxGX4)
- [Working with SketchUp Part 3](https://youtu.be/uU0HhuviuLE)
- [Post processing Basics](https://youtu.be/D0ZCudA9wv8)
- [Post processing merging shapes](https://youtu.be/Z-096iua6jk)
- [Feed speed optimization with preprocessor](https://youtu.be/2PEHMFtozhw)
- [Post processing code insides Part 1](https://youtu.be/n6ZeKAKcKlE)
- [Post processing code insides Part 2](https://youtu.be/POwDu0zc9eI)


# Mechanics
- 4x linear v-slot actuator with NEMA 17
- 2020 profiles, screws, nuts
- nichrome wire
- 2-4x retractable reel 

![mechanic_3](https://github.com/ThomasHeb/4AxisFoamCutter/blob/master/img/mechanic_3.JPG)
![mechanic_4](https://github.com/ThomasHeb/4AxisFoamCutter/blob/master/img/mechanic_4.JPG)

[Video: Mechanic](https://youtu.be/zKdzEoycaa4)

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

![hardware_1](https://github.com/ThomasHeb/4AxisFoamCutter/blob/master/img/hardware_1.JPG)
![hardware_2](https://github.com/ThomasHeb/4AxisFoamCutter/blob/master/img/hardware_2.JPG)


### Operation without buttons, leds and limit switches (minimum operation setup)
There are some sets available for 3D printer, including Arduino Mega, Ramps 1.4, 128x64 Display with SD card reader and stepper driver 4988. The firmware can be configured to operate especially with this hardware setup, without buttons, led and limit switches. The usability is limited, but almost no soldering is needed.
To use this setup, simply skip all steps related to limit switches, buttons and leds. the local button on the display is used as back button, all other operations can be handled with the jog.
- set USE_LIMIT_SWITCHES to 0 in config.h to disable the limit switches 
- set USE_BUTTONS to 0 in config.h to disable the buttons and leds 


### Modifications of Hardware:
- cut-off Arduino PIN 10 on Ramps (just cut of the pin-header on the Ramps 
- connect Arduino Pin 7 on Ramps to Socket off pin 10
- to reduce EMC connect 100 nF between S and - close to Ramps for limit switches / end stops
- to reduce EMC connect 100 nF between D63 and GND directly on Ramps pin header for AUX-2 (not required if stopp button is close to ramps) 


### How to start:
The Arduino and the Ramps board are working without the stepper driver or motors or buttons,…. so only the limit switches should be disabled by setting 4 jumpers to the S and - Pin for X-/X+/Y-/Y+ an the Ramps. After downloading the firmware with the Arduino IDE, please use the Serial Monitor (Baudrate 115200) with the [grbl commands](https://github.com/gnea/grbl/wiki/Grbl-v1.1-Commands) to disable hard limits and homing cycle in the parameter. After testing all axis, SD card, …, you can activate the limit switches (hard limits) and the homing cycle again. If you are not disabling the limit switches, you may get a hard error, which blocks all communication to the Arduino (not required, if USE_LIMIT_SWITCHES is set to 0). After that you should 
- connect the display to the Ramps
- connect the Arduino with the USB
- load the firmware and check if you get a welcome screen
- add the buttons and LEDs to the Ramps (not required, if USE_BUTTONS is set to 0)
- calculate the steps per mm and set the microstepps according with the jumpers (I use belt and pully with 80 steps / mm) 
- add the stepper driver to the Ramps
- adjust the driver [link](https://www.makerguides.com/a4988-stepper-motor-driver-arduino-tutorial/)
- connect 12V DC to Ramps 3/4
- add a stepper motor and test operation

[Video: Hardware](https://youtu.be/xaXfXsz1NG8)

# Firmware
The firmware is based on the grbl version 8c2 modified for foam cutter, a modified version of U8G2 library for the display and SdFat with no changes.

Links to the original 
- [grbl 8c2 foam](https://www.rcgroups.com/forums/showthread.php?2915801-4-Axis-Hot-Wire-CNC-%28Arduino-Ramps1-4%29-Complete-Solution)
- [U8G2 Lib by Oli Kraus, tested with version 2.27.6](https://github.com/olikraus/u8g2)
- [SdFat by Bill Greiman, tested with version 1.2.3](https://github.com/greiman/SdFat)

Many thanks to you, for writing and sharing this fantastic code.

### How to install:
- Download the foamcutter firmware
- Download the U8G2 lib (GitHub or via the Arduino IDE) 
- Download the SdFat lib (GitHub or via the Arduino IDE)
- Open ../Arduino/libraries/U8G2/src and replace U8x8lib.h and U8x8Lib.cpp from the code section

### Changes within the library U8G2:
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


# Working with SketchUp

I use SketchUp for generating the stl-files for my 3D printed parts. I would love to use the easy handling for creating fuselages. I searched the web and found only one hotwire related tool, which is not supported any more. so I decided to write a small tool by myself. This allowas you to generare G90 (abolute positioning) coordinates of combinded edges. Currently I use only linear extrapolation in combination with my post processor. The results are good.

### What you need
- SketchUp (I am Using SketchUp Make 2017)
- Ruby Code Editor
- CurviLoft
- Download foamcutter.rb from the code section

### Functionality and usage of foamcutter.rb
Open the ruby code editor first and load and execute the foamcutter.rb. This adds 3 menus to the PlugIn menu. Inside the settings you can define some general settings, like inch/mm, used decimals, labels of the axis.

With the tool itself, you are asked to select 2 paths which are exported as gcode. The paths it self use the green (x and u) and blue (y and z) axis. Positioning along the red axis does not matter.

The algorithm searches all related points to an edge. It follows two routes
### 1: go up first (Y/Z +)
### 2: go back first (X/U -)
It uses all edges only once. If you reach a dead end, you may use the third dimension do open up new paths/edges - please keep the rules in mind.

Both paths should have the same number of points and edges. To go for that with more complex objects, it is a good way to use CurviLoft
- create your objects
- use CurviLoft to generate the surface/area between the objects. 
- select to show the related edges between the objects (connection lines)
- split these connection lines (ungroup)
- select and group the objects (otherwise the object is not splittet in points)
- delete the connection lines
- use foamcutter tool
- select first and second edge
- save the file
- do the post processing if required

### Check out the tutorial video
- [Working with SketchUp Part 1](https://youtu.be/MZSXp2stBLk)
- [Working with SketchUp Part 2](https://youtu.be/SIh3zpsxGX4)
- [Working with SketchUp Part 3](https://youtu.be/uU0HhuviuLE)

![sketchup_1](https://github.com/ThomasHeb/4AxisFoamCutter/blob/master/img/sketchup_1.png)
![sketchup_2](https://github.com/ThomasHeb/4AxisFoamCutter/blob/master/img/sketchup_2.png)

In addition you can import how files from WingHelper

# Post processing
Designing the shape of a wing or a fuselage requires in most times an additional step to tell the machine / foam cutter how to produce it. This step is called post processing. It allows you to generate machine executable or interpretable code (gcode) and add machine, tool and material specific information (hot wire temperature, travel speed, position of foam block, …). I wrote a pice of code, do adopt my SketchUp files and my WingHelper Designs to my foam cutter. The code is written in swift for macOS, but the basic ideas can be easily adopted to other languages. All post processing functions are bundled in the class FCalc (FCalc.swift). Interfacing is handled with key to access the values and the labels/descriptions to the values. The values itself are exchanged as Strings, because most of them are changed by user, so all type checking stuff is integrated in FCalc, too. Detailed interface description is available in FCalc.swift.

![postprocessor_1](https://github.com/ThomasHeb/4AxisFoamCutter/blob/master/img/postprocessor_1.png)

### Overview of functions
- Import shapes from gcode, nc, SkechUp foamcutter.rb, Winghelper how, fcf-projects
- Export to gcode
- Load/Save projects as fcf file
- Move and rotate and mirror the shape 
- Move and rotate the foam block
- Calculates the movement of the axis
- Speed optimisation, to keep average speed at the edges of the shape close to target feed speed
- Merging of different shapes into one cutting job
- 3D preview and simulation of axis, shape and foam block

### Check out the tutorial video
- [Basics](https://youtu.be/D0ZCudA9wv8)
- [Merging shapes](https://youtu.be/Z-096iua6jk)


### Settings
- All settings have a unique ID (see SettingsTableKey for all values) for access
- Reading a setting:
  - dataTypeForKey(_ key: SettingsTableKey) -> DataType              
    the Datatype of the setting for correct visualisation/layout
  - labelForKey(_ key: SettingsTableKey) -> String                   
    the label for the setting
  - valueForKey(_ key: SettingsTableKey) -> String                   
    the value itself for the key as formatted string
- Writing:
  - isEditableForKey(_ key: SettingsTableKey) -> Bool                
    indicates wheather this type is editable
  - isValueValid(_ key: SettingsTableKey, value: String?) -> Bool    
    a string can be tested, if it is acceptable for this setting
  - valueForKey(_ key: SettingsTableKey, value: String?)             
    writes a string to the setting
- Usage: Generate an array of SettingsTableKey-values to be displayed and catch the content with the functions above
- All is handled with strings, so no need of type conversion

### Import a file / export GCode
- Supported filetypes;
  - gcode, nc: simple gcode wit G00/G0, G01, G1, G90, G91, ...
  - how: Winghelper ICE export with absolute coordinates
  - fcf: Foam Cuter File (project) previously saved
  - importShapeFromFile(_ file: String) -> Int       
    =  0 if ok / != 0 if not ok
- Save a file in gcode format
  exportGCodeToFile(_ file: String) -> Int         
  =  0 if ok / != 0 if not ok

###  Callbacks (FCalcCallback):
- updateSettingsTableView()  
  called, wenn the table for the settings needs to be updated
- updatePositionsTableView(_ atIndex: Int?)                                 
  called, wenn the table for the positions needs to be updated
- updatePreview(_ node: SCNNode)  
  called, whenn the Graph is updated, check if Node is already linked

###  Changing Values / Coordinates:
- optional, see FCalc.swift

###  Videos explaining some code insides:
- [Part 1](https://youtu.be/n6ZeKAKcKlE)
- [Part 2](https://youtu.be/POwDu0zc9eI)



