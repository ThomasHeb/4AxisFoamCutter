#include <avr/io.h>
#include "protocol.h"
#include "report.h"
#include "stepper.h"
#include "nuts_bolts.h"
#include "settings.h"
#include "eeprom.h"
#include "limits.h"
#include "gcode.h"          // to_degrees()
#include "defaults.h"       //
#include "config.h"

#if (U_AXIS != 3)
  #error
#endif
#ifndef LINE_BUFFER_SIZE
  #error
#endif

settings_t settings;


// Method to store startup lines into EEPROM
void settings_store_startup_line(uint8_t n, char *line)
{
  uint16_t addr = n*(LINE_BUFFER_SIZE+1)+EEPROM_ADDR_STARTUP_BLOCK;
  memcpy_to_eeprom_with_checksum(addr,(char*)line, LINE_BUFFER_SIZE);
}

// Method to store coord data parameters into EEPROM
void settings_write_coord_data(uint8_t coord_select, float *coord_data)
{
  uint16_t addr = coord_select*(sizeof(float)*4+1) + EEPROM_ADDR_PARAMETERS;
  memcpy_to_eeprom_with_checksum(addr,(char*)coord_data, sizeof(float)*4);
}

// Method to store Grbl global settings struct and version number into EEPROM
void write_global_settings()
{
  eeprom_put_char(0, SETTINGS_VERSION);
  memcpy_to_eeprom_with_checksum(EEPROM_ADDR_GLOBAL, (char*)&settings, sizeof(settings_t));
}

// Method to reset Grbl global settings back to defaults.
void settings_reset(bool reset_all) {
  // Reset all settings or only the migration settings to the new version.
  if (reset_all) {
    settings.steps_per_mm[X_AXIS] = DEFAULT_X_STEPS_PER_MM;
    settings.steps_per_mm[Y_AXIS] = DEFAULT_Y_STEPS_PER_MM;

#ifdef FOAM_CUTTER
    settings.steps_per_mm[Z_AXIS] = DEFAULT_Z_STEPS_PER_MM;
    settings.steps_per_mm[U_AXIS] = DEFAULT_U_STEPS_PER_MM; 
#endif
#ifdef LASER_CUTTER
    settings.steps_per_mm[Z_AXIS] = DEFAULT_X_STEPS_PER_MM;       // Defaults
    settings.steps_per_mm[U_AXIS] = DEFAULT_Y_STEPS_PER_MM;       // Defaults
#endif    

   
    settings.pulse_microseconds   = DEFAULT_STEP_PULSE_MICROSECONDS;
    settings.default_feed_rate    = DEFAULT_FEEDRATE;
    settings.default_seek_rate    = DEFAULT_SEEKRATE;
    settings.acceleration         = DEFAULT_ACCELERATION;
    settings.mm_per_arc_segment   = DEFAULT_MM_PER_ARC_SEGMENT;
    settings.invert_mask          = DEFAULT_STEPPING_INVERT_MASK;
    settings.junction_deviation   = DEFAULT_JUNCTION_DEVIATION;    
  }
  // New settings since last version
  settings.flags = 0;
  if (DEFAULT_REPORT_INCHES)
    settings.flags |= BITFLAG_REPORT_INCHES;
  if (DEFAULT_AUTO_START)
    settings.flags |= BITFLAG_AUTO_START;
  if (DEFAULT_INVERT_ST_ENABLE)
    settings.flags |= BITFLAG_INVERT_ST_ENABLE;
  if (DEFAULT_HARD_LIMIT_ENABLE)
    settings.flags |= BITFLAG_HARD_LIMIT_ENABLE;
  if (DEFAULT_HOMING_ENABLE)
    settings.flags |= BITFLAG_HOMING_ENABLE;
  settings.homing_dir_mask        = DEFAULT_HOMING_DIR_MASK;
  settings.homing_feed_rate       = DEFAULT_HOMING_FEEDRATE;
  settings.homing_seek_rate       = DEFAULT_HOMING_RAPID_FEEDRATE;
  settings.homing_debounce_delay  = DEFAULT_HOMING_DEBOUNCE_DELAY;
  settings.homing_pulloff[X_AXIS] = DEFAULT_HOMING_PULLOFF_X;
  settings.homing_pulloff[Y_AXIS] = DEFAULT_HOMING_PULLOFF_Y;
#ifdef FOAM_CUTTER
  settings.homing_pulloff[U_AXIS] = DEFAULT_HOMING_PULLOFF_U;
  settings.homing_pulloff[Z_AXIS] = DEFAULT_HOMING_PULLOFF_Z;
#endif
#ifdef LASER_CUTTER
  settings.homing_pulloff[U_AXIS] = DEFAULT_HOMING_PULLOFF_X;       // Defaults
  settings.homing_pulloff[Z_AXIS] = DEFAULT_HOMING_PULLOFF_Y;       // Defaults
#endif    
  settings.stepper_idle_lock_time = DEFAULT_STEPPER_IDLE_LOCK_TIME;
  settings.decimal_places         = DEFAULT_DECIMAL_PLACES;
  settings.n_arc_correction       = DEFAULT_N_ARC_CORRECTION;
#ifdef FOAM_CUTTER
  settings.tool_pwr               = DEFAULT_HOTWIRE;
  settings.fan_pwr                = DEFAULT_FAN;
  settings.cutting_hor            = DEFAULT_CUTTING_HOR;
  settings.cutting_ver            = DEFAULT_CUTTING_VER;
#endif
#ifdef LASER_CUTTER
  settings.tool_pwr               = 0;
  settings.fan_pwr                = 0;
  settings.cutting_hor            = 0;
  settings.cutting_ver            = 0;
#endif    
 
  write_global_settings();
}

// Reads startup line from EEPROM. Updated pointed line string data.
uint8_t settings_read_startup_line(uint8_t n, char *line)
{
  uint16_t addr = n*(LINE_BUFFER_SIZE+1)+EEPROM_ADDR_STARTUP_BLOCK;
  if (!(memcpy_from_eeprom_with_checksum((char*)line, addr, LINE_BUFFER_SIZE))) {
    // Reset line with default value
    line[0] = 0;
    settings_store_startup_line(n, line);
    return(false);
  }
  else
    return true;
}

// Read selected coordinate data from EEPROM. Updates pointed coord_data value.
uint8_t settings_read_coord_data(uint8_t coord_select, float *coord_data)
{
  uint16_t addr = coord_select*(sizeof(float)*4+1) + EEPROM_ADDR_PARAMETERS;
  if (!(memcpy_from_eeprom_with_checksum((char*)coord_data, addr, sizeof(float)*4))) {
    // Reset with default zero vector
    clear_vector_float(coord_data);
    settings_write_coord_data(coord_select,coord_data);
    return(false);
  }
  else {
    return(true);
  }
}

// Reads Grbl global settings struct from EEPROM.
uint8_t read_global_settings() {
  // Check version-byte of eeprom
  uint8_t version = eeprom_get_char(0);

  if (version == SETTINGS_VERSION) {
    // Read settings-record and check checksum
    if (!(memcpy_from_eeprom_with_checksum((char*)&settings, EEPROM_ADDR_GLOBAL, sizeof(settings_t)))) {
      return(false); // report error
    } 
#if (ALWAYS_DEFAULTS_SETTINGS == 1)
    else {
      settings_reset(true);   
    }
#endif
  }
  else {
    settings_reset(true);   
  }

#if (USE_LIMIT_SWITCHES == 0)
  settings.flags &= ~BITFLAG_HARD_LIMIT_ENABLE;
  settings.flags &= ~BITFLAG_HOMING_ENABLE;
#endif
  return(true);
}


// A helper method to set settings from command line
uint8_t settings_store_global_setting(int parameter, float value) {
  switch(parameter) {
    case 0: 
      if (value <= 0.0)
        return(STATUS_SETTING_VALUE_NEG);
      settings.steps_per_mm[X_AXIS] = value;
      break;
    case 1: 
      if (value <= 0.0)
        return(STATUS_SETTING_VALUE_NEG);
      settings.steps_per_mm[Y_AXIS] = value;
      break;
    case 2:
      if (value <= 0.0)
        return(STATUS_SETTING_VALUE_NEG);
      settings.steps_per_mm[U_AXIS] = value;
      break;
    case 3:
      if (value <= 0.0)
        return(STATUS_SETTING_VALUE_NEG);
      settings.steps_per_mm[Z_AXIS] = value;
      break;
    case 4:
      if (value < 3) { return(STATUS_SETTING_STEP_PULSE_MIN); }
      settings.pulse_microseconds = round(value);
      break;
    case 5: settings.default_feed_rate = value;
    break;
    case 6: settings.default_seek_rate = value;
    break;
    case 7: settings.invert_mask = trunc(value);
    break;
    case 8: settings.stepper_idle_lock_time = round(value);
    break;
    case 9: settings.acceleration = value*60*60;
    break; // Convert to mm/min^2 for grbl internal use.
    case 10: settings.junction_deviation = fabs(value);
    break;
    case 11: settings.mm_per_arc_segment = value;
    break;
    case 12: settings.n_arc_correction = round(value);
    break;
    case 13: settings.decimal_places = round(value);
    break;
    case 14:
      if (value)
    settings.flags |= BITFLAG_REPORT_INCHES;
      else
        settings.flags &= ~BITFLAG_REPORT_INCHES;
      break;
    case 15: // Reset to ensure change. Immediate re-init may cause problems.
      if (value)
    settings.flags |= BITFLAG_AUTO_START;
      else
        settings.flags &= ~BITFLAG_AUTO_START;
      break;
    case 16: // Reset to ensure change. Immediate re-init may cause problems.
      if (value)
    settings.flags |= BITFLAG_INVERT_ST_ENABLE;
      else
    settings.flags &= ~BITFLAG_INVERT_ST_ENABLE;
      break;
    case 17:
      if (value)
        settings.flags |= BITFLAG_HARD_LIMIT_ENABLE;
      else
        settings.flags &= ~BITFLAG_HARD_LIMIT_ENABLE;
      limits_init(); // Re-init to immediately change. NOTE: Nice to have but could be problematic later.
      break;
    case 18:
      if (value)
        settings.flags |= BITFLAG_HOMING_ENABLE;
      else
        settings.flags &= ~BITFLAG_HOMING_ENABLE;
      break;
    case 19:
      settings.homing_dir_mask = trunc(value);
      break;
       
    case 20:
      settings.homing_feed_rate = value;
      break;
    case 21:
      settings.homing_seek_rate = value;
      break;
    case 22:
      settings.homing_debounce_delay = round(value);
      break;
    case 23:
      settings.homing_pulloff[X_AXIS] = value;
      break;
    case 24:
      settings.homing_pulloff[Y_AXIS] = value;
      break;
    case 25:
      settings.homing_pulloff[U_AXIS] = value;
      break;
    case 26:
      settings.homing_pulloff[Z_AXIS] = value;
      break;      
    case 27:
      settings.tool_pwr     = value;
      gc.tool_pwr           = value;
      break;
    case 28:
      settings.fan_pwr = value;
      break;
    case 29:
      settings.cutting_hor = value;
      break;
    case 30:
      settings.cutting_ver = value;
      break;
    default:
      return(STATUS_INVALID_STATEMENT);
  }
  write_global_settings();
  return(STATUS_OK);
}

// Initialize the config subsystem
void settings_init() {
  if(!read_global_settings()) {
    report_status_message(STATUS_SETTING_READ_FAIL);
    settings_reset(true);
    report_grbl_settings();
  }
  // Read all parameter data into a dummy variable. If error, reset to zero, otherwise do nothing.
  float coord_data[N_AXIS];
  uint8_t i;
  for (i=0; i<=SETTING_INDEX_NCOORD; i++) {
    if (!settings_read_coord_data(i, coord_data)) {
      report_status_message(STATUS_SETTING_READ_FAIL);
    }
  }
  // NOTE: Startup lines are handled and called by main.c at the end of initialization.
}
