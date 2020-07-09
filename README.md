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

[rcKeith, Hot wire cutter](www.rckeith.co.uk/cnc-hot-wire-foam-cutter/)

[4 axis foam cutter](https://github.com/rahulsarchive/4AxisFoamCutter)

[4 axis foam hotwire cutter](https://www.rcgroups.com/forums/showthread.php?2915801-4-Axis-Hot-Wire-CNC-(Arduino-Ramps1-4)-Complete-Solution)


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

Modifications of Hardware:
- cut-off Arduino PIN 10 on Ramps 
- connect Arduino Pin 7 on Ramps to Socket off PIN 10
- to reduce EMC connect 100 nF between S and - close to Ramps for limit switches / end stops
- to reduce EMC connect 100 nF between D63 and GND directly on Ramps pin header for AUX-2 (not required if stopp button is close to ramps) 


How to start:
the Arduino and the Ramps board are working without the stepper driver or motors or buttons,…. so only the limit switches should be disabled by setting 4 jumpers to the S and - Pin for X-/X+/Y-/Y+ an the Ramps. After downloading the firmware with the Arduino IDE please use the Serial Monitor with the [grbl commands](https://github.com/gnea/grbl/wiki/Grbl-v1.1-Commands) to disable hard limits and homing cycle. After testing all axis, SD card, …, you can activate the limit switches (hard limits) and the homing cycle again. If you are not disabling the limit switches, you will get an hard error, which blocks all communication to the Arduino.

