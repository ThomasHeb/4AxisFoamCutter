
/* The defaults.h file serves as a central default settings file for different machine
   types, from DIY CNC mills to CNC conversions of off-the-shelf machines. The settings
   here are supplied by users, so your results may vary. However, this should give you
   a good starting point as you get to know your machine and tweak the settings for your
   our nefarious needs. */

#ifndef defaults_h
#define defaults_h

#include "config.h"    // DEFAULTS_FOAMCUTTER, ...


//==============================================================================





#ifdef DEFAULTS_FOAMCUTTER
  //  step_per_revolution = number of motor steps per revolution
  #define USER_STEP_PER_REVOLUTION        200
  #define USER_MICROSTEPS                 16
  #define USER_PITCH_BELT                 2     // in mm
  #define USER_GEAR                       20    // No of Teeth
  
  ///  pitch_screw = pitch of screw
  #define USER_PITCH_SCREW                4  // 4mm for all linear axes
  #define USER_STEP_MM                    (USER_STEP_PER_REVOLUTION/USER_PITCH_SCREW)
  ///  ratio_table  =  the worm gear ratio
  #define USER_RATIO_TABLE                90   // for rotary axis
  // user values
  // calculated value Grbl = ratio_table*step_per_revolution/360
  #define USER_TABLE                      ((USER_RATIO_TABLE*USER_STEP_PER_REVOLUTION)/360.0)
//==============================================================================
  
  #define DEFAULT_X_STEPS_PER_MM          ((USER_STEP_PER_REVOLUTION * USER_MICROSTEPS) / (USER_PITCH_BELT * USER_GEAR))
  #define DEFAULT_Y_STEPS_PER_MM          ((USER_STEP_PER_REVOLUTION * USER_MICROSTEPS) / (USER_PITCH_BELT * USER_GEAR))
  
  #define DEFAULT_U_STEPS_PER_MM          ((USER_STEP_PER_REVOLUTION * USER_MICROSTEPS) / (USER_PITCH_BELT * USER_GEAR))
  #define DEFAULT_Z_STEPS_PER_MM          ((USER_STEP_PER_REVOLUTION * USER_MICROSTEPS) / (USER_PITCH_BELT * USER_GEAR))
 
  #define DEFAULT_STEP_PULSE_MICROSECONDS 10
  #define DEFAULT_MM_PER_ARC_SEGMENT      0.1

  #define DEFAULT_SEEKRATE                500         // mm/min
  #define DEFAULT_FEEDRATE                200

  #define DEFAULT_FEEDRATE_MAX            500
  #define DEFAULT_FEEDRATE_MIN            200

  
  #define DEFAULT_ACCELERATION            25.0*60*60  // 10*60*60 mm/min^2 = 10 mm/s^2
  #define DEFAULT_JUNCTION_DEVIATION      0.05        // mm
/// 8c1
  #define DEFAULT_STEPPING_INVERT_MASK    0           // b7=Z, b6=Y, b5=X, b0=U
  #define DEFAULT_REPORT_INCHES           0           // false
  #define DEFAULT_AUTO_START              1           // true
  #define DEFAULT_INVERT_ST_ENABLE        0           // false

#if (USE_LIMIT_SWITCHES == 1)
  #define DEFAULT_HARD_LIMIT_ENABLE       1           // true
  #define DEFAULT_HOMING_ENABLE           1           // true
#else
  #define DEFAULT_HARD_LIMIT_ENABLE       0           // false
  #define DEFAULT_HOMING_ENABLE           0           // false
#endif
  #define DEFAULT_HOMING_DIR_MASK         225         // b7=Z, b6=Y, b5=X, b0=U
  #define DEFAULT_HOMING_RAPID_FEEDRATE   500.0       // mm/min nicht zu schnell fahren, damit der Endschalter nicht angeschossen wird
  #define DEFAULT_HOMING_FEEDRATE         100.0       // mm/min
  #define DEFAULT_HOMING_DEBOUNCE_DELAY   250         // msec (0-65k)
  #define DEFAULT_HOMING_PULLOFF_X        1.0         // mm
  #define DEFAULT_HOMING_PULLOFF_Y        1.0         // mm
  #define DEFAULT_HOMING_PULLOFF_U        1.0         // mm
  #define DEFAULT_HOMING_PULLOFF_Z        1.0         // mm
  #define DEFAULT_STEPPER_IDLE_LOCK_TIME  255         // msec (0-255)
  #define DEFAULT_DECIMAL_PLACES          3
  #define DEFAULT_N_ARC_CORRECTION        25


  #define DEFAULT_HOTWIRE                 75.0        // default power for hotwire  (0...100)
  #define DEFAULT_FAN                     75.0        // default power for fan      (0...100)
  #define DEFAULT_CUTTING_HOR             310.0       // default cutting in horizontal direction in mm
  #define DEFAULT_CUTTING_VER             230.0       // default cutting in vertical direction in mm
#endif



#ifdef DEFAULTS_LASERCUTTER
  //  step_per_revolution = number of motor steps per revolution
  #define USER_STEP_PER_REVOLUTION        200
  #define USER_MICROSTEPS                 16
  #define USER_PITCH_BELT                 2     // in mm
  #define USER_GEAR                       16    // No of Teeth
  
  ///  pitch_screw = pitch of screw
  #define USER_PITCH_SCREW                4  // 4mm for all linear axes
  #define USER_STEP_MM                    (USER_STEP_PER_REVOLUTION/USER_PITCH_SCREW)
  ///  ratio_table  =  the worm gear ratio
  #define USER_RATIO_TABLE                90   // for rotary axis
  // user values
  // calculated value Grbl = ratio_table*step_per_revolution/360
  #define USER_TABLE                      ((USER_RATIO_TABLE*USER_STEP_PER_REVOLUTION)/360.0)
//==============================================================================
  
  #define DEFAULT_X_STEPS_PER_MM          ((USER_STEP_PER_REVOLUTION * USER_MICROSTEPS) / (USER_PITCH_BELT * USER_GEAR))
  #define DEFAULT_Y_STEPS_PER_MM          ((USER_STEP_PER_REVOLUTION * USER_MICROSTEPS) / (USER_PITCH_BELT * USER_GEAR))
  
  #define DEFAULT_STEP_PULSE_MICROSECONDS 10
  #define DEFAULT_MM_PER_ARC_SEGMENT      0.1

  #define DEFAULT_SEEKRATE                1000         // mm/min
  #define DEFAULT_FEEDRATE                500

  #define DEFAULT_FEEDRATE_MAX            1000
  #define DEFAULT_FEEDRATE_MIN            500

  
  #define DEFAULT_ACCELERATION            25.0*60*60  // 10*60*60 mm/min^2 = 10 mm/s^2
  #define DEFAULT_JUNCTION_DEVIATION      0.05        // mm
/// 8c1
  #define DEFAULT_STEPPING_INVERT_MASK    64          // b7=Z, b6=Y, b5=X, b0=U
  #define DEFAULT_REPORT_INCHES           0           // false
  #define DEFAULT_AUTO_START              1           // true
  #define DEFAULT_INVERT_ST_ENABLE        0           // false

#if (USE_LIMIT_SWITCHES == 1)
  #define DEFAULT_HARD_LIMIT_ENABLE       1           // true
  #define DEFAULT_HOMING_ENABLE           1           // true
#else
  #define DEFAULT_HARD_LIMIT_ENABLE       0           // false
  #define DEFAULT_HOMING_ENABLE           0           // false
#endif
  #define DEFAULT_HOMING_DIR_MASK         96          // b7=Z, b6=Y, b5=X, b0=U
  #define DEFAULT_HOMING_RAPID_FEEDRATE   1500.0      // mm/min nicht zu schnell fahren, damit der Endschalter nicht angeschossen wird
  #define DEFAULT_HOMING_FEEDRATE         200.0       // mm/min
  #define DEFAULT_HOMING_DEBOUNCE_DELAY   250         // msec (0-65k)
  #define DEFAULT_HOMING_PULLOFF_X        1.0         // mm
  #define DEFAULT_HOMING_PULLOFF_Y        1.0         // mm
  #define DEFAULT_STEPPER_IDLE_LOCK_TIME  255         // msec (0-255)
  #define DEFAULT_DECIMAL_PLACES          3
  #define DEFAULT_N_ARC_CORRECTION        25

  #define DEFAULT_LASER                   0.0         // default power for laser  (0...100)

  #define DEFAULT_LASER_DOT               0.2         // default power for laser DOT in % // this is not changeable with parameters, please test and set during FW compilation
  
#endif





#endif
