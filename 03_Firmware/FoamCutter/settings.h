#ifndef settings_h
#define settings_h

#include <math.h>
#include "nuts_bolts.h"

/// date of construction
#define GRBL_VERSION_BUILD "20140606"
#define GRBL_VERSION "0.8c2"

// Version of the EEPROM data. Will be used to migrate existing data from older versions of Grbl
// when firmware is upgraded. Always stored in byte 0 of eeprom
#define SETTINGS_VERSION           6

// Define bit flag masks for the boolean settings in settings.flag.
#define BITFLAG_REPORT_INCHES      bit(0)
#define BITFLAG_AUTO_START         bit(1)
#define BITFLAG_INVERT_ST_ENABLE   bit(2)
#define BITFLAG_HARD_LIMIT_ENABLE  bit(3)
#define BITFLAG_HOMING_ENABLE      bit(4)

// Define EEPROM memory address location values for Grbl settings and parameters
// NOTE: The Atmega328p has 1KB EEPROM. The upper half is reserved for parameters and
// the startup script. The lower half contains the global settings and space for future
// developments.
#define EEPROM_ADDR_GLOBAL        1
#define EEPROM_ADDR_PARAMETERS    512
#define EEPROM_ADDR_STARTUP_BLOCK 768

// Define EEPROM address indexing for coordinate parameters
#define N_COORDINATE_SYSTEM       6  // Number of supported work coordinate systems (from index 1)
#define SETTING_INDEX_NCOORD      N_COORDINATE_SYSTEM+1 // Total number of system stored (from index 0)
// NOTE: Work coordinate indices are (0=G54, 1=G55, ... , 6=G59)
#define SETTING_INDEX_G28         N_COORDINATE_SYSTEM    // Home position 1
#define SETTING_INDEX_G30         N_COORDINATE_SYSTEM+1  // Home position 2
// #define SETTING_INDEX_G92         N_COORDINATE_SYSTEM+2  // Coordinate offset (G92.2,G92.3 not supported)

// Global persistent settings (Stored from byte EEPROM_ADDR_GLOBAL onwards)
typedef struct {
/// 8c0
  float     steps_per_mm[N_AXIS];
  uint8_t   microsteps;
  uint8_t   pulse_microseconds;
  float     default_feed_rate;
  float     default_seek_rate;
  uint8_t   invert_mask;
  float     mm_per_arc_segment;
  float     acceleration;
  float     junction_deviation;
  uint8_t   flags;  // Contains default boolean settings
  uint8_t   homing_dir_mask;
  float     homing_feed_rate;
  float     homing_seek_rate;
  uint16_t  homing_debounce_delay;
  float     homing_pulloff[N_AXIS];
  uint8_t   stepper_idle_lock_time; // If max value 255, steppers do not disable.
  uint8_t   decimal_places;
  uint8_t   n_arc_correction;
  float     tool_pwr;
  float     fan_pwr;
  float     cutting_hor;
  float     cutting_ver;
//  uint8_t status_report_mask; // Mask to indicate desired report data.
} settings_t;
extern settings_t settings;
#define SETTINGS_DEFAULT_FEED_RATE  5
#define SETTINGS_INDEX_TOOL         27
#define SETTINGS_INDEX_FAN          28
#define SETTINGS_INDEX_PULLOFF_X    23
#define SETTINGS_INDEX_PULLOFF_Y    24
#define SETTINGS_INDEX_PULLOFF_U    25
#define SETTINGS_INDEX_PULLOFF_Z    26
#define SETTINGS_CUTTING_HOR        29 
#define SETTINGS_CUTTING_VER        30 
// Initialize the configuration subsystem (load settings from EEPROM)
void settings_init();

// A helper method to set new settings from command line
uint8_t settings_store_global_setting(int parameter, float value);

// Stores the protocol line variable as a startup line in EEPROM
void settings_store_startup_line(uint8_t n, char *line);

// Reads an EEPROM startup line to the protocol line variable
uint8_t settings_read_startup_line(uint8_t n, char *line);

// Writes selected coordinate data to EEPROM
void settings_write_coord_data(uint8_t coord_select, float *coord_data);

// Reads selected coordinate data from EEPROM
uint8_t settings_read_coord_data(uint8_t coord_select, float *coord_data);

// reset all Settings to default
void settings_reset(bool reset_all);
#endif
