#include <U8g2lib.h>
#include "lcd.h"
#include "fastio.h"
#include <SPI.h>
#include "SdFat.h"
#include "sdios.h"
#include "fan.h"
#include "hotwire.h"
#include "settings.h"
#include "stepper.h"
#include <avr/pgmspace.h>
#include "print.h"
#include "planner.h"

U8G2_ST7920_128X64_F_SW_SPI lcd(U8G2_R0, //orientation
                                PIN_LCD_E, 
                                PIN_LCD_RW, 
                                PIN_LCD_RS, 
                                PIN_LCD_RST);
#include "gcode.h"
#include "report.h"
#include "protocol.h"

// SdFat sd card
SdFat sd;
// Directory file.
SdFile root;
// Use for file creation in folders.
SdFile file;

#define SD_LINE_BUFFER_SIZE  256
void sd_protocol_process();
typedef struct {
  char      filename[18]; 
  uint8_t   fileIndex;
  uint32_t  fileSize;
  uint32_t  bytesProcessed;
  char      lineBuffer[SD_LINE_BUFFER_SIZE];
  uint16_t  lineBufferIndex;
  uint8_t   errors;
  uint8_t   stateProcessFile;        // state machine for processing a file from sd card
  bool      isComment;
} sd_t;
sd_t sd_data;

#define ERR_SDCARD      0x01


typedef struct {
  uint8_t   menue_id;                // id of the menue
  uint16_t  cursor_id;               // id or position of the cursor
  uint32_t  buttons;                 // pressed buttons
  uint32_t  buttons_redge;           // rising edge of buttons
  uint32_t  buttons_fedge;           // falling edge of buttons
  uint32_t  buttons_prev;            // previous state of buttons
  uint32_t  buttons_cnt;             // counter to stabilize the buttons
  uint32_t  buttons_image;           // image of the current buttons to be stabilized
  uint8_t   refresh; 
  float     fvalue;
  float     cutting_start_position[N_AXIS];
} lcd_t;
lcd_t lcd_data;


// menue_id:
#define MENUE_WELCOME                       0

#define MENUE_MAIN_0                        1
#define   MENUE_MAIN_0_IDLE_STEPPER         0
#define   MENUE_MAIN_0_HOMING               1
#define   MENUE_MAIN_0_POSITION             2
#define   MENUE_MAIN_0_SDCARD               3
#define   MENUE_MAIN_0_HOTWIRE              4
#define MENUE_MAIN_1                        2
#define   MENUE_MAIN_1_SDCARD               0
#define   MENUE_MAIN_1_HOTWIRE              1
#define   MENUE_MAIN_1_FEED                 2
#define   MENUE_MAIN_1_CUTTING              3
#define   MENUE_MAIN_1_FAN                  4
#define MENUE_MAIN_2                        3
#define   MENUE_MAIN_2_CUTTING              0
#define   MENUE_MAIN_2_FAN                  1

#define MENUE_POSITION_0                    4
#if (USE_BUTTONS == 1)
#define   MENUE_POSITION_SET_HOME           0
#define   MENUE_POSITION_GOTO_HOME          1
#define   MENUE_POSITION_100MM              2
#define   MENUE_POSITION_10MM               3
#define   MENUE_POSITION_1MM                4
#define   MENUE_POSITION_01MM               5
#define   MENUE_POSITION_GOTO_ZERO          6
#define   MENUE_POSITION_SET_ZERO           7
#else
#define   MENUE_POSITION_SET_HOME           0
#define   MENUE_POSITION_GOTO_HOME          1
#define   MENUE_POSITION_X100MM             2
#define   MENUE_POSITION_X10MM              3
#define   MENUE_POSITION_X1MM               4
#define   MENUE_POSITION_X01MM              5
#define   MENUE_POSITION_U100MM             6
#define   MENUE_POSITION_U10MM              7
#define   MENUE_POSITION_U1MM               8
#define   MENUE_POSITION_U01MM              9
#define   MENUE_POSITION_Y100MM             10
#define   MENUE_POSITION_Y10MM              11
#define   MENUE_POSITION_Y1MM               12
#define   MENUE_POSITION_Y01MM              13
#define   MENUE_POSITION_Z100MM             14
#define   MENUE_POSITION_Z10MM              15
#define   MENUE_POSITION_Z1MM               16
#define   MENUE_POSITION_Z01MM              17
#define   MENUE_POSITION_GOTO_ZERO          18
#define   MENUE_POSITION_SET_ZERO           19
#endif

#define   MENUE_POSITION_EXIT_MENUE         MENUE_MAIN_0
#define   MENUE_POSITION_EXIT_CURSOR        MENUE_MAIN_0_POSITION

#define MENUE_HOMING_0                      5
#define   MENUE_HOMING_EXIT_MENUE           MENUE_MAIN_0
#define   MENUE_HOMING_EXIT_CURSOR          MENUE_MAIN_0_HOMING

#define MENUE_SDCARD_0                      6
#define   MENUE_SDCARD_EXIT_MENUE           MENUE_MAIN_0
#define   MENUE_SDCARD_EXIT_CURSOR          MENUE_MAIN_0_SDCARD
#define PROCESS_SDCARD_0                    7

#define MENUE_FAN_0                         8
#define MENUE_FAN_1                         9
#define   MENUE_FAN_EXIT_MENUE              MENUE_MAIN_2
#define   MENUE_FAN_EXIT_CURSOR             MENUE_MAIN_2_FAN

#define MENUE_HOTWIRE_0                     10
#define MENUE_HOTWIRE_1                     11
#define   MENUE_HOTWIRE_EXIT_MENUE          MENUE_MAIN_1
#define   MENUE_HOTWIRE_EXIT_CURSOR         MENUE_MAIN_1_HOTWIRE

#define MENUE_IDLE_STEPPER_0                12
#define   MENUE_IDLE_STEPPER_EXIT_MENUE     MENUE_MAIN_0
#define   MENUE_IDLE_STEPPER_EXIT_CURSOR    MENUE_MAIN_0_IDLE_STEPPER

#define MENUE_CUTTING_0                     13
#define   MENUE_CUTTING_NONE                0
#define   MENUE_CUTTING_HOR_POS             1
#define   MENUE_CUTTING_HOR_NEG             2
#define   MENUE_CUTTING_VER_POS             3
#define   MENUE_CUTTING_VER_NEG             4
#define   MENUE_CUTTING_LIMIT               5
#define   MENUE_CUTTING_PREVIOUS_POSITION   6
#define   MENUE_CUTTING_EXIT_MENUE          MENUE_MAIN_1
#define   MENUE_CUTTING_EXIT_CURSOR         MENUE_MAIN_1_CUTTING

#define MENUE_FEED_0                        14
#define   MENUE_FEED_EXIT_MENUE             MENUE_MAIN_1
#define   MENUE_FEED_EXIT_CURSOR            MENUE_MAIN_1_FEED




// buttons:
#define BTN_ONBOARD                   0x00000001
#define BTN_ROTARY_PUSH               0x00000002
#define BTN_ROTARY_EN1                0x00000004
#define BTN_ROTARY_EN2                0x00000008
#define BTN_ROTARY_LEFT               0x00000010
#define BTN_ROTARY_RIGHT              0x00000020
#define BTN_ROTARY_UP                 0x00000010
#define BTN_ROTARY_DOWN               0x00000020
#define SD_DETECTED                   0x00000040
#define BTN_BACK                      0x00000080
#define BTN_HOTWIRE                   0x00000100
#define BTN_NONE_0                    0x00000200
#define BTN_Y_PLUS                    0x00000400
#define BTN_Y_MINUS                   0x00000800
#define BTN_X_PLUS                    0x00001000
#define BTN_X_MINUS                   0x00002000
#define BTN_Z_PLUS                    0x00004000
#define BTN_Z_MINUS                   0x00008000
#define BTN_U_PLUS                    0x00010000
#define BTN_U_MINUS                   0x00020000

// 
#define FONT_CURSOR_HOR               u8g2_font_helvB08_tr
#define FONT_CURSOR_VER               u8g2_font_helvR08_tr







void lcd_init() {
  lcd_data.menue_id                   = MENUE_WELCOME;
  lcd_data.cursor_id                  = 0;
  lcd_data.buttons                    = 0;
  lcd_data.buttons_redge              = 0;
  lcd_data.buttons_fedge              = 0;
  lcd_data.buttons_prev               = 0;
  lcd_data.buttons_cnt                = 0;
  lcd_data.refresh                    = 1;

  lcd_data.cutting_start_position[X_AXIS]  = 0;
  lcd_data.cutting_start_position[Y_AXIS]  = 0;
  lcd_data.cutting_start_position[U_AXIS]  = 0;
  lcd_data.cutting_start_position[Z_AXIS]  = 0;
  
  sd_data.errors                      = 0;
  sd_data.stateProcessFile            = 0;
  sd_data.lineBufferIndex             = 0;           
  sd_data.bytesProcessed              = 0;

  lcd.begin();

  // setup sd card reader
  pinMode(PIN_SD_DET,         INPUT_PULLUP);
  
  // setup beeper output
  SET_OUTPUT(PIN_BEEPER);
  WRITE(PIN_BEEPER, 0);

  // setup leds
  SET_OUTPUT(PIN_LED_NONE_0);
  WRITE(PIN_LED_NONE_0, 0);


  // setup button input
  pinMode(PIN_ENC,            INPUT_PULLUP);
  pinMode(PIN_EN1,            INPUT_PULLUP);
  pinMode(PIN_EN2,            INPUT_PULLUP);
  pinMode(PIN_BTN_BACK,       INPUT_PULLUP);

  pinMode(PIN_BTN_X_PLUS,     INPUT_PULLUP);
  pinMode(PIN_BTN_X_MINUS,    INPUT_PULLUP);
  pinMode(PIN_BTN_Y_PLUS,     INPUT_PULLUP);
  pinMode(PIN_BTN_Y_MINUS,    INPUT_PULLUP);
  pinMode(PIN_BTN_U_PLUS,     INPUT_PULLUP);
  pinMode(PIN_BTN_U_MINUS,    INPUT_PULLUP);
  pinMode(PIN_BTN_Z_PLUS,     INPUT_PULLUP);
  pinMode(PIN_BTN_Z_MINUS,    INPUT_PULLUP);
  pinMode(PIN_BTN_HOTWIRE,    INPUT_PULLUP);
  pinMode(PIN_BTN_NONE_0,     INPUT_PULLUP);
 
  pinMode(PIN_BTN_ONBOARD,    INPUT_PULLUP);
 

  
}


void lcd_crit_error() {
  lcd.clearBuffer();
  lcd.drawRFrame(0, 0, 128, 20, 3);
  lcd.setFont(u8g2_font_helvB10_tr);
  lcd.setCursor( 20, 16); lcd.print(F("Critical Error"));
    
  lcd.setFont(u8g2_font_helvR08_tr);
  lcd.setCursor(  2, 32); lcd.print(F("i.e. limits or e-stopp."));
  lcd.setCursor(  1, 44); lcd.print(F("Power down, remove error"));
  lcd.setCursor(  2, 56); lcd.print(F("and restart the system."));
  lcd.sendBuffer();
}

// ===============================================================================================
//  Welcome Menue 
// ===============================================================================================
void lcd_process_menue_welcome() {
  if (lcd_data.menue_id == MENUE_WELCOME) {
    if (lcd_data.refresh != 0) {                    // update the display on request
      lcd_data.refresh = 0;
      lcd.clearBuffer();
      // welcome screen
      // frame an title
      lcd.drawRFrame(0, 0, 128, 20, 3);
      lcd.setFont(u8g2_font_helvB10_tr);
      lcd.setCursor( 20, 15); lcd.print(F("Foam Cutter"));
  
      lcd.setFont(u8g2_font_helvB08_tr);
      lcd.setCursor(  2, 30); lcd.print(F("4-Axis Hot-Wire Cutting"));
      lcd.setCursor( 20, 40); lcd.print(F("(c) T. Heberlein"));
  
      lcd.setFont(u8g2_font_helvR08_tr);
      lcd.setCursor( 10, 62); lcd.print(F("press any key to continue"));
      lcd.sendBuffer();
    }
    // on any putton goto main menue
    if (lcd_data.buttons_redge & (~SD_DETECTED)) {
      lcd_data.menue_id       =  MENUE_MAIN_0;
      lcd_data.cursor_id      =  0;
      lcd_data.refresh        =  1;
    }
 
    lcd_data.buttons_redge        = 0;              // reset all edge indicators
    lcd_data.buttons_fedge        = 0;
  }
}
// ===============================================================================================
//  Main Menue 
// ===============================================================================================
void lcd_process_menue_main() {
  if (lcd_data.menue_id == MENUE_MAIN_0) {
    if (lcd_data.refresh != 0) {                    // update the display on request
      lcd_data.refresh = 0;
      lcd.clearBuffer();
      // main menue
       // title
      lcd.setFont(u8g2_font_helvB08_tr);
      lcd.setCursor(  0, 8); lcd.print(F("Main"));
      // menue items
      lcd.setFont(u8g2_font_helvR08_tr);
      lcd.setCursor(  6, 20 + 12 * MENUE_MAIN_0_IDLE_STEPPER);  lcd.print(F("Idle Stepper"));     
      lcd.setCursor(  6, 20 + 12 * MENUE_MAIN_0_HOMING);        lcd.print(F("Homing"));     
      lcd.setCursor(  6, 20 + 12 * MENUE_MAIN_0_POSITION);      lcd.print(F("Position"));     
      lcd.setCursor(  6, 20 + 12 * MENUE_MAIN_0_SDCARD);        lcd.print(F("SD-Card"));     
      lcd.setCursor(  6, 20 + 12 * MENUE_MAIN_0_HOTWIRE);       lcd.print(F("Hot wire"));     
      
      // cursor
      lcd.setFont(FONT_CURSOR_HOR);
      lcd.setCursor(  0, 20 + (lcd_data.cursor_id * 12));       lcd.print(F(">"));
      
      lcd.setDrawColor(0);
      lcd.drawBox   (117,  0, 10, 64);        // ... spacer to scrollbar
      lcd.setDrawColor(1);
      lcd.drawRFrame(120,  0,  8, 64,  2);    // ... frame for scrollbar
      lcd.drawBox   (122,  2,  4, 20);        // ... scrollbar

      lcd.sendBuffer();
    }
    if (lcd_data.buttons_redge & BTN_ROTARY_PUSH) {
      lcd_data.refresh        =  1;     // ... reload
      switch (lcd_data.cursor_id) {
        case MENUE_MAIN_0_POSITION: 
          lcd_data.menue_id   =  MENUE_POSITION_0;   
#if (USE_BUTTONS == 1)          
          lcd_data.cursor_id  =  MENUE_POSITION_1MM;   
#else
          lcd_data.cursor_id  =  MENUE_POSITION_X1MM;  
          lcd_data.fvalue     =  0;
#endif
          break;
        case MENUE_MAIN_0_SDCARD: 
          lcd_data.menue_id   =  MENUE_SDCARD_0;   
          lcd_data.cursor_id  =  0;
          break; 
        case MENUE_MAIN_0_IDLE_STEPPER:      
          lcd_data.menue_id   =  MENUE_IDLE_STEPPER_0;   
          lcd_data.cursor_id  =  0;
          break; 
        case MENUE_MAIN_0_HOMING:
          lcd_data.menue_id   =  MENUE_HOMING_0;   
          lcd_data.cursor_id  =  0;
          break;      
        default:
          lcd_data.refresh    =  0;     // ... no reload 
          break; 
      }
    }
    else if (lcd_data.buttons_redge & BTN_ROTARY_DOWN) {
      lcd_data.cursor_id      += 1;
      if (lcd_data.cursor_id > 3) {     // if cursur exceeds 4th entry
        lcd_data.menue_id     = MENUE_MAIN_1;     // ... goto next menue page
        lcd_data.cursor_id    =  1;     // ... set cursor to 2nd entry
      }
      lcd_data.refresh        =  1;     // ... reload
    }
    else if (lcd_data.buttons_redge & BTN_ROTARY_UP) {
      if (lcd_data.cursor_id > 0) {
        lcd_data.cursor_id    -= 1;
        lcd_data.refresh      =  1;
      }
    }
    
    lcd_data.buttons_redge        = 0;              // reset all edge indicators
    lcd_data.buttons_fedge        = 0;
  }
  else if (lcd_data.menue_id == MENUE_MAIN_1) {
    if (lcd_data.refresh != 0) {                    // update the display on request
      lcd_data.refresh = 0;
      lcd.clearBuffer();
      // main menue
      // title
      lcd.setFont(u8g2_font_helvB08_tr);
      lcd.setCursor(  0, 8); lcd.print(F("Main"));
      // menue items
      lcd.setFont(u8g2_font_helvR08_tr);
      lcd.setCursor(  6, 20 + 12 * MENUE_MAIN_1_SDCARD);        lcd.print(F("SD-Card"));     
      lcd.setCursor(  6, 20 + 12 * MENUE_MAIN_1_HOTWIRE);       lcd.print(F("Hot wire"));     
      lcd.setCursor(  6, 20 + 12 * MENUE_MAIN_1_FEED);          lcd.print(F("Feed speed"));     
      lcd.setCursor(  6, 20 + 12 * MENUE_MAIN_1_CUTTING);       lcd.print(F("Slicing"));     
      lcd.setCursor(  6, 20 + 12 * MENUE_MAIN_1_FAN);           lcd.print(F("Fan"));     
      // cursor
      lcd.setFont(FONT_CURSOR_HOR);
      lcd.setCursor(  0, 20 + (lcd_data.cursor_id * 12));       lcd.print(F(">"));
      
      lcd.setDrawColor(0);
      lcd.drawBox   (117,  0, 10, 64);        // ... spacer to scrollbar
      lcd.setDrawColor(1);
      lcd.drawRFrame(120,  0,  8, 64,  2);    // ... frame for scrollbar
      lcd.drawBox   (122, 22,  4, 20);        // ... scrollbar

      lcd.sendBuffer();
    }
    if (lcd_data.buttons_redge & BTN_ROTARY_DOWN) {
      lcd_data.cursor_id      += 1;
      if (lcd_data.cursor_id > 3) {     // if cursur exceeds 4th entry
        lcd_data.menue_id     = MENUE_MAIN_2;     // ... goto next menue page
        lcd_data.cursor_id    =  1;     // ... set cursor to 2nd entry
      }
      lcd_data.refresh        =  1;     // ... reload
    }
    else if (lcd_data.buttons_redge & BTN_ROTARY_UP) {
      if (lcd_data.cursor_id > 0) {     // if cursur goes up before first entry
        lcd_data.cursor_id    -= 1;     // ... select previous entry
      }
      else {                            // else
        lcd_data.menue_id     =  MENUE_MAIN_0;     // ... goto previous menue page
        lcd_data.cursor_id    =  2;     // ... set cursur to 3rd entry
      }
      lcd_data.refresh      =  1;       // ... reload
    }
    if (lcd_data.buttons_redge & BTN_ROTARY_PUSH) {
      lcd_data.refresh        =  1;     // ... reload
      switch (lcd_data.cursor_id) {
        case MENUE_MAIN_1_SDCARD: 
          lcd_data.menue_id   =  MENUE_SDCARD_0;   
          lcd_data.cursor_id  =  0;
          break;
        case MENUE_MAIN_1_HOTWIRE: 
          lcd_data.menue_id   =  MENUE_HOTWIRE_0;   
          lcd_data.cursor_id  =  gc.hotwire;
          break; 
        case MENUE_MAIN_1_FAN: 
          lcd_data.menue_id   =  MENUE_FAN_0;   
          lcd_data.cursor_id  =  fan_state();
          break;
        case MENUE_MAIN_1_CUTTING: 
          lcd_data.menue_id   =  MENUE_CUTTING_0;   
          lcd_data.cursor_id  =  0;
          break;  
        case MENUE_MAIN_1_FEED: 
          lcd_data.menue_id   =  MENUE_FEED_0;   
          lcd_data.fvalue     =  settings.default_feed_rate;
          lcd_data.cursor_id  =  0;
          break;  
        
        default:
          lcd_data.refresh    =  0;     // ... no reload 
          break; 
      }
    }
    
    lcd_data.buttons_redge        = 0;              // reset all edge indicators
    lcd_data.buttons_fedge        = 0;
  }
  else if (lcd_data.menue_id == MENUE_MAIN_2) {
    if (lcd_data.refresh != 0) {                    // update the display on request
      lcd_data.refresh = 0;
      lcd.clearBuffer();
      // main menue
      
      // title
      lcd.setFont(u8g2_font_helvB08_tr);
      lcd.setCursor(  0, 8); lcd.print(F("Main"));
      // menue items
      lcd.setFont(u8g2_font_helvR08_tr);
      lcd.setCursor(  6, 20 + 12 * MENUE_MAIN_2_CUTTING);       lcd.print(F("Slicing"));  
      lcd.setCursor(  6, 20 + 12 * MENUE_MAIN_2_FAN);           lcd.print(F("Fan"));     
      
      // cursor
      lcd.setFont(FONT_CURSOR_HOR);
      lcd.setCursor(  0, 20 + (lcd_data.cursor_id * 12));       lcd.print(F(">"));
      
      lcd.setDrawColor(0);
      lcd.drawBox   (117,  0, 10, 64);        // ... spacer to scrollbar
      lcd.setDrawColor(1);
      lcd.drawRFrame(120,  0,  8, 64,  2);    // ... frame for scrollbar
      lcd.drawBox   (122, 42,  4, 20);        // ... scrollbar
      
      lcd.sendBuffer();
    }

    if (lcd_data.buttons_redge & BTN_ROTARY_RIGHT) {
      if (lcd_data.cursor_id < 1) {     // if curser goes down before 3rd entry // TODO change for adding menues
        lcd_data.cursor_id      += 1;   // ... select next entry
        lcd_data.refresh        =  1;   // ... reload
      }
    }
    else if (lcd_data.buttons_redge & BTN_ROTARY_UP) {
      if (lcd_data.cursor_id > 0) {     // if cursur goes up before first entry
        lcd_data.cursor_id    -= 1;     // ... select previous entry
      }
      else {                            // else
        lcd_data.menue_id     =  MENUE_MAIN_1;   // ... goto previous menue page
        lcd_data.cursor_id    =  2;     // ... set cursur to 3rd entry
      }
      lcd_data.refresh        =  1;     // ... reload
    }
    if (lcd_data.buttons_redge & BTN_ROTARY_PUSH) {
      lcd_data.refresh        =  1;     // ... reload
      switch (lcd_data.cursor_id) {
        case MENUE_MAIN_2_FAN: 
          lcd_data.menue_id   =  MENUE_FAN_0;   
          lcd_data.cursor_id  =  fan_state();
          break;
        case MENUE_MAIN_2_CUTTING: 
          lcd_data.menue_id   =  MENUE_CUTTING_0;   
          lcd_data.cursor_id  =  0;
          break;    
        default:
          lcd_data.refresh    =  0;     // ... no reload 
          break; 
      }
    }
    
    
    lcd_data.buttons_redge        = 0;              // reset all edge indicators
    lcd_data.buttons_fedge        = 0;
  }
}




// ===============================================================================================
//  Idle Stepper Menue 
// ===============================================================================================
void lcd_process_menue_idle_stepper() {
  float progress;
  if (lcd_data.menue_id == MENUE_IDLE_STEPPER_0) {
    if (lcd_data.refresh != 0) {                    // update the display on request
      lcd_data.refresh = 0;
      lcd.clearBuffer();
      // title
      lcd.setFont(u8g2_font_helvB08_tr);
      lcd.setCursor(  0, 8); lcd.print(F("Idle stepper"));
      // menue items
      lcd.setFont(u8g2_font_helvR08_tr);
      lcd.setCursor(  6, 20);        
      lcd.print(F("Execute?"));     
      lcd.setCursor( 80, 20); 
      if (lcd_data.cursor_id == 0) {
        lcd.print(F("NO"));     
      
      } else {
        lcd.print(F("YES"));     
      }  
      lcd.sendBuffer();
    }

    if (lcd_data.buttons_redge & BTN_BACK) {
      lcd_data.refresh        =  1;     // ... back to main menue
      lcd_data.menue_id       =  MENUE_IDLE_STEPPER_EXIT_MENUE;   
      lcd_data.cursor_id      =  MENUE_IDLE_STEPPER_EXIT_CURSOR;
    }
    else if (lcd_data.buttons_redge & BTN_ROTARY_RIGHT) {
      if (lcd_data.cursor_id == 0) {
        lcd_data.cursor_id    =  1;     // ... select next mode
        lcd_data.refresh      =  1;     // ... reload
      }
    }
    else if (lcd_data.buttons_redge & BTN_ROTARY_LEFT) {
      if (lcd_data.cursor_id == 1) {     // 
        lcd_data.cursor_id    =  0;     // ... select previous mode
        lcd_data.refresh      =  1;     // ... reload
      }
    } else if (lcd_data.buttons_redge & BTN_ROTARY_PUSH) {
      if (lcd_data.cursor_id == 1) {
        // Idle Stepper
        st_force_idle();
      }
      lcd_data.refresh        =  1;     // ... back to main menue
      lcd_data.menue_id       =  MENUE_IDLE_STEPPER_EXIT_MENUE;   
      lcd_data.cursor_id      =  MENUE_IDLE_STEPPER_EXIT_CURSOR;
    }
    
    lcd_data.buttons_redge        = 0;              // reset all edge indicators
    lcd_data.buttons_fedge        = 0; 
  }
}

// ===============================================================================================
//  Cutting Menue 
// ===============================================================================================
void lcd_process_menue_cutting() {
  float progress;
  if (lcd_data.menue_id == MENUE_CUTTING_0) {
    if (lcd_data.refresh != 0) {                    // update the display on request
      lcd_data.refresh = 0;
      lcd.clearBuffer();
      // title
      lcd.setFont(u8g2_font_helvB08_tr);
      lcd.setCursor(0, 8);      lcd.print(F("Slicing"));
      // menue items
      lcd.setFont(u8g2_font_helvR08_tr);

      lcd.setCursor(6, 20);
      switch (lcd_data.cursor_id) {
        case MENUE_CUTTING_HOR_POS:
          lcd.print(F("Horizontal forward"));
          break;
        case MENUE_CUTTING_HOR_NEG:
          lcd.print(F("Horizontal backward"));
          break; 
        case MENUE_CUTTING_VER_POS:
          lcd.print(F("Vertical upward"));
          break;
        case MENUE_CUTTING_VER_NEG:
          lcd.print(F("Vertical downward"));
          break; 
        case MENUE_CUTTING_LIMIT:
          lcd.print(F("Set X/Y as max. position?"));
          break;
        case MENUE_CUTTING_PREVIOUS_POSITION:
          lcd.print(F("Back to previous position"));
          break;
        default:
          lcd.print(F("Choose direction?"));
          break;  
      }
      switch (lcd_data.cursor_id) {
        case MENUE_CUTTING_HOR_POS:
        case MENUE_CUTTING_HOR_NEG:
        case MENUE_CUTTING_VER_POS:
        case MENUE_CUTTING_VER_NEG:
        case MENUE_CUTTING_LIMIT:
        case MENUE_CUTTING_PREVIOUS_POSITION:
          lcd.setCursor(  6, 32);
          lcd.print(F("Execute?"));     
          lcd.setCursor( 80, 32); 
          lcd.print(F("YES"));  
          break;   
      } 
      lcd.sendBuffer();
    }

    if (lcd_data.buttons_redge & BTN_BACK) {
      lcd_data.refresh        =  1;     // ... back to main menue
      lcd_data.menue_id       =  MENUE_CUTTING_EXIT_MENUE;   
      lcd_data.cursor_id      =  MENUE_CUTTING_EXIT_CURSOR;
    }
    
#if (USE_BUTTONS == 1)
    else if (lcd_data.buttons_redge & (BTN_Y_PLUS | BTN_Z_PLUS)) {
      lcd_data.cursor_id    =  MENUE_CUTTING_VER_POS;   
      lcd_data.refresh      =  1;     // ... reload
    }
    else if (lcd_data.buttons_redge & (BTN_X_PLUS | BTN_U_PLUS)) {
      lcd_data.cursor_id    =  MENUE_CUTTING_HOR_POS;   
      lcd_data.refresh      =  1;     // ... reload
    }
    else if (lcd_data.buttons_redge & (BTN_X_MINUS | BTN_U_MINUS)) {
      lcd_data.cursor_id    =  MENUE_CUTTING_HOR_NEG;   
      lcd_data.refresh      =  1;     // ... reload
    }
    else if (lcd_data.buttons_redge & (BTN_Y_MINUS | BTN_Z_MINUS)) {
      lcd_data.cursor_id    =  MENUE_CUTTING_VER_NEG;   
      lcd_data.refresh      =  1;     // ... reload
    }
    else if (lcd_data.buttons_redge & (BTN_ROTARY_DOWN)) {
      lcd_data.cursor_id    =  MENUE_CUTTING_LIMIT;   
      lcd_data.refresh      =  1;     // ... reload
    }
    else if (lcd_data.buttons_redge & (BTN_ROTARY_UP)) {
      lcd_data.cursor_id    =  MENUE_CUTTING_PREVIOUS_POSITION;   
      lcd_data.refresh      =  1;     // ... reload
    }
 #else 
    else if (lcd_data.buttons_redge & BTN_ROTARY_DOWN) {
      if (lcd_data.cursor_id < MENUE_CUTTING_PREVIOUS_POSITION) {
        lcd_data.cursor_id    += 1;
        lcd_data.refresh      =  1;     // ... reload
      }
    }   
    else if (lcd_data.buttons_redge & BTN_ROTARY_UP) {
      if (lcd_data.cursor_id > MENUE_CUTTING_HOR_POS) {
        lcd_data.cursor_id    -= 1;
        lcd_data.refresh      =  1;     // ... reload
      }
    }
 #endif   
    else if (lcd_data.buttons_redge & BTN_ROTARY_PUSH) {
      if (lcd_data.cursor_id ==  MENUE_CUTTING_LIMIT) {
        settings_store_global_setting(SETTINGS_CUTTING_HOR, gc.position[X_AXIS]);
        settings_store_global_setting(SETTINGS_CUTTING_VER, gc.position[Y_AXIS]);
        lcd_data.refresh        =  1;     // ... to back menu
        lcd_data.menue_id       =  MENUE_CUTTING_0;   
        lcd_data.cursor_id      =  MENUE_CUTTING_PREVIOUS_POSITION;
      } 
      else if (lcd_data.cursor_id ==  MENUE_CUTTING_PREVIOUS_POSITION) {
        String gc_command;
        char gc_c[30];
      
        gc_command =  "G90F" + String(settings.homing_seek_rate, 0);
        gc_command.toCharArray(gc_c, 29);
        report_status_message(gc_execute_line(gc_c));         // switch to Absolute Mode and change speed

        gc_command =  "G1X"  + String(lcd_data.cutting_start_position[X_AXIS], 1);
        gc_command += "Y"    + String(lcd_data.cutting_start_position[Y_AXIS], 1);
        gc_command += "U"    + String(lcd_data.cutting_start_position[U_AXIS], 1);
        gc_command += "Z"    + String(lcd_data.cutting_start_position[Z_AXIS], 1);
        gc_command.toCharArray(gc_c, 29);
        report_status_message(gc_execute_line(gc_c));         // move
        plan_synchronize();                                   // wait until all movements are done

        lcd_data.refresh        =  1;     // ... Cutting menu
        lcd_data.menue_id       =  MENUE_CUTTING_0;   
        lcd_data.cursor_id      =  0;
  
      }
      else if (    (lcd_data.cursor_id ==  MENUE_CUTTING_HOR_POS) 
                || (lcd_data.cursor_id ==  MENUE_CUTTING_HOR_NEG) 
                || (lcd_data.cursor_id ==  MENUE_CUTTING_VER_POS) 
                || (lcd_data.cursor_id ==  MENUE_CUTTING_VER_NEG) ) {
        String gc_command;
        char gc_c[30];

        // store position
        lcd_data.cutting_start_position[X_AXIS]  = gc.position[X_AXIS];
        lcd_data.cutting_start_position[Y_AXIS]  = gc.position[Y_AXIS];
        lcd_data.cutting_start_position[U_AXIS]  = gc.position[U_AXIS];
        lcd_data.cutting_start_position[Z_AXIS]  = gc.position[Z_AXIS];


        // switch on the hotwire
        if (gc.hotwire == 0) {                              // preheat the hotwire, if it is not on
          report_status_message(gc_execute_line("M3"));     // switch on hotwire
          report_status_message(gc_execute_line("G4P5"));   // Wait for 5 seconds to heat up the hotwire
        }
      
        gc_command =  "G90F" + String(settings.default_feed_rate, 0);
        gc_command.toCharArray(gc_c, 29);
        report_status_message(gc_execute_line(gc_c));     // switch to Absolute Mode and change speed

        switch (lcd_data.cursor_id) {
          case MENUE_CUTTING_HOR_NEG:
            report_status_message(gc_execute_line("G1X0U0"));// move
            break;
          case MENUE_CUTTING_VER_NEG:
            report_status_message(gc_execute_line("G1Y0Z0"));// move
            break; 
          case MENUE_CUTTING_HOR_POS:
            // we use the full cutting distance beginning from zero based on the pulled homing position!
            // if zero ist moved, cutting distance must be adjusted
            gc_command =  "G1X"  + String(settings.cutting_hor, 1);
            gc_command += "U"    + String(settings.cutting_hor, 1);
            gc_command.toCharArray(gc_c, 29);
            report_status_message(gc_execute_line(gc_c));     // move
            break;
          case MENUE_CUTTING_VER_POS:
            // we use the full cutting distance beginning from zero based on the pulled homing position!
            // if zero ist moved, cutting distance must be adjusted
            gc_command =  "G1Y"  + String(settings.cutting_ver, 1);
            gc_command += "Z"    + String(settings.cutting_ver, 1);
            gc_command.toCharArray(gc_c, 29);
            report_status_message(gc_execute_line(gc_c));     // move
            break;
          default:
            break;
        }
        plan_synchronize();                                   // wait until all movements are done
        report_status_message(gc_execute_line("M5"));         // switch of hotwire     
        
        lcd_data.refresh        =  1;     // ... to back menu
        lcd_data.menue_id       =  MENUE_CUTTING_0;   
        lcd_data.cursor_id      =  MENUE_CUTTING_PREVIOUS_POSITION;
      }
    }
    
    lcd_data.buttons_redge        = 0;              // reset all edge indicators
    lcd_data.buttons_fedge        = 0; 
  }
}




// ===============================================================================================
//  Position Menue 
// ===============================================================================================
void lcd_print_cursor(uint8_t digit, uint8_t x, uint8_t y) {
#if (USE_BUTTONS == 1)
  x += 7+5+6 + 6;
  
  lcd.setFont(FONT_CURSOR_VER);
  x += digit * 6;
  if (digit > 2) 
    x += 3;
  lcd.setCursor(x, y);
  lcd.print(F("^")); 
  
#else
  if (digit >= 8) {
    y += 24;
    digit -= 8;
  }

  if (digit >= 4) {
    digit -= 4;
    x += 64;
  }
  
  x += 7+5+6 + 6;
  
  lcd.setFont(FONT_CURSOR_VER);
  x += digit * 6;
  if (digit > 2) 
    x += 3;
  lcd.setCursor(x, y);
  lcd.print(F("^")); 
  
#endif
}

void lcd_print_position(char label, float value, uint8_t x, uint8_t y) {
  // print label
  lcd.setCursor(x, y);
  lcd.print(label);

  x +=7;
  lcd.setCursor(x, y);
  lcd.print(F(":"));

  
  // print the sign
   x +=5;
 if (value < 0) {
    lcd.setCursor(x+1, y);
    lcd.print(F("-"));
    value *= -1;
  } else {
    lcd.setCursor(x, y); 
    lcd.print(F("+"));
  }
  x += 6;
     
  if (value < 1000) {
    lcd.setCursor(x, y);
    lcd.print(F("0"));
    x += 6;
  }
  if (value < 100) {
    lcd.setCursor(x, y);
    lcd.print(F("0"));
    x += 6;
  }
  if (value < 10) {
    lcd.setCursor(x, y);
    lcd.print(F("0"));
    x += 6;
  }
  lcd.setCursor(x, y);
  lcd.print(value, 1); 
}


void lcd_process_menue_position() {
  if (lcd_data.menue_id == MENUE_POSITION_0) {
    if (lcd_data.refresh != 0) {                    // update the display on request
      lcd_data.refresh = 0;
      lcd.clearBuffer();
      // position menue
      lcd.setFont(u8g2_font_helvB08_tr);
      lcd.setCursor(0, 8);      lcd.print(F("Position"));
      lcd.setFont(u8g2_font_helvR08_tr);
      lcd.setCursor(50, 8);      lcd.print(F("in mm"));
      // menue items
      lcd.setFont(u8g2_font_helvR08_tr);
#if (USE_BUTTONS == 1)
      lcd_print_position('X', gc.position[X_AXIS] - gc.coord_system[X_AXIS], 6,    20); 
      lcd_print_position('Y', gc.position[Y_AXIS] - gc.coord_system[Y_AXIS], 6,    32); 
      lcd_print_position('U', gc.position[U_AXIS] - gc.coord_system[U_AXIS], 6+64, 20); 
      lcd_print_position('Z', gc.position[Z_AXIS] - gc.coord_system[Z_AXIS], 6+64, 32); 
#else 
      lcd_print_position('X', gc.position[X_AXIS] - gc.coord_system[X_AXIS], 6,    20); 
      lcd_print_position('Y', gc.position[Y_AXIS] - gc.coord_system[Y_AXIS], 6,    32 + 12); 
      lcd_print_position('U', gc.position[U_AXIS] - gc.coord_system[U_AXIS], 6+64, 20); 
      lcd_print_position('Z', gc.position[Z_AXIS] - gc.coord_system[Z_AXIS], 6+64, 32 + 12); 
#endif
      // TODO löschen
      // lcd_print_position('X', gc.coord_offset[X_AXIS], 6,    56); 
      // lcd_print_position('X', gc.coord_system[X_AXIS], 6+64,    56); 
      
      
     
#if (USE_BUTTONS == 1) 
      if (lcd_data.cursor_id == MENUE_POSITION_SET_HOME) {              // cursor_id: 0
        lcd.setFont(FONT_CURSOR_HOR);
        lcd.setCursor( 0, 44);      lcd.print(F(">"));
        lcd.setFont(u8g2_font_helvR08_tr);
        lcd.setCursor( 6, 44);      lcd.print(F("Set as home position"));
      }
      else if (lcd_data.cursor_id == MENUE_POSITION_GOTO_HOME) {         // cursor_id: 1
        lcd.setFont(FONT_CURSOR_HOR);
        lcd.setCursor( 0, 44);      lcd.print(F(">"));
        lcd.setFont(u8g2_font_helvR08_tr);
        lcd.setCursor( 6, 44);      lcd.print(F("Goto home position"));
      } 
      else if (lcd_data.cursor_id < MENUE_POSITION_GOTO_ZERO) {          // cursor_id: 2...5
        lcd_print_cursor(lcd_data.cursor_id - 2, 6,    44);
        lcd_print_cursor(lcd_data.cursor_id - 2, 6+64, 44);
      }
      else if (lcd_data.cursor_id == MENUE_POSITION_GOTO_ZERO) {         // cursor_id: 6
        lcd.setFont(FONT_CURSOR_HOR);
        lcd.setCursor( 0, 44);      lcd.print(F(">"));
        lcd.setFont(u8g2_font_helvR08_tr);
        lcd.setCursor( 6, 44);      lcd.print(F("Goto zero position"));
      }
      if (lcd_data.cursor_id == MENUE_POSITION_SET_ZERO) {              // cursor_id: 7
        lcd.setFont(FONT_CURSOR_HOR);
        lcd.setCursor( 0, 44);      lcd.print(F(">"));
        lcd.setFont(u8g2_font_helvR08_tr);
        lcd.setCursor( 6, 44);      lcd.print(F("Set as zero position"));
      } 
 #else      
     if (lcd_data.cursor_id == MENUE_POSITION_SET_HOME) {              // cursor_id: 0
        lcd.setFont(FONT_CURSOR_HOR);
        lcd.setCursor( 0, 44 + 16);      lcd.print(F(">"));
        lcd.setFont(u8g2_font_helvR08_tr);
        lcd.setCursor( 6, 44 + 16);      lcd.print(F("Set as home position"));
      }
      else if (lcd_data.cursor_id == MENUE_POSITION_GOTO_HOME) {         // cursor_id: 1
        lcd.setFont(FONT_CURSOR_HOR);
        lcd.setCursor( 0, 44 + 16);      lcd.print(F(">"));
        lcd.setFont(u8g2_font_helvR08_tr);
        lcd.setCursor( 6, 44 + 16);      lcd.print(F("Goto home position"));
      } 
      else if (lcd_data.cursor_id < MENUE_POSITION_GOTO_ZERO) {        
        lcd_print_cursor(lcd_data.cursor_id - 2, 6,    32);
      }
      else if (lcd_data.cursor_id == MENUE_POSITION_GOTO_ZERO) {         
        lcd.setFont(FONT_CURSOR_HOR);
        lcd.setCursor( 0, 44 + 16);      lcd.print(F(">"));
        lcd.setFont(u8g2_font_helvR08_tr);
        lcd.setCursor( 6, 44 + 16);      lcd.print(F("Goto zero position"));
      }
      if (lcd_data.cursor_id == MENUE_POSITION_SET_ZERO) {              
        lcd.setFont(FONT_CURSOR_HOR);
        lcd.setCursor( 0, 44 + 16);      lcd.print(F(">"));
        lcd.setFont(u8g2_font_helvR08_tr);
        lcd.setCursor( 6, 44 + 16);      lcd.print(F("Set as zero position"));
      } 
 #endif     
      lcd.sendBuffer();
    }
 #if (USE_BUTTONS == 1) 
    char   gc_c[20];
    String gc_command;
    String gc_step;

    gc_step = "0";
    if (lcd_data.cursor_id == MENUE_POSITION_01MM)    gc_step = "0.1";
    if (lcd_data.cursor_id == MENUE_POSITION_1MM)     gc_step = "1";
    if (lcd_data.cursor_id == MENUE_POSITION_10MM)    gc_step = "10";
    if (lcd_data.cursor_id == MENUE_POSITION_100MM)   gc_step = "100";


    if (lcd_data.buttons_redge & BTN_BACK) {
      lcd_data.refresh        =  1;     // ... back to main menue
      lcd_data.menue_id       =  MENUE_POSITION_EXIT_MENUE;   
      lcd_data.cursor_id      =  MENUE_POSITION_EXIT_CURSOR;
    } 
    else if (lcd_data.buttons_redge & BTN_ROTARY_UP) {
      if (lcd_data.cursor_id > MENUE_POSITION_SET_HOME) {     // if cursur is in range
        lcd_data.cursor_id    -= 1;     // ... select previous entry
        lcd_data.refresh      =  1;     // ... reload
      }
    } 
    else if (lcd_data.buttons_redge & BTN_ROTARY_DOWN) {
      if (lcd_data.cursor_id < MENUE_POSITION_SET_ZERO) {     // if cursur is in range
        lcd_data.cursor_id    += 1;     // ... select next entry
        lcd_data.refresh      =  1;     // ... reload
      }
    } else if (lcd_data.buttons_redge & BTN_ROTARY_PUSH) {

      gc_command =  "F" + String(settings.default_feed_rate, 0);
      gc_command.toCharArray(gc_c, 19);
      report_status_message(gc_execute_line(gc_c));     // change speed

      if (lcd_data.cursor_id == MENUE_POSITION_SET_HOME) { 
        report_status_message(gc_execute_line("G28.1"));
        lcd_data.refresh      =  1;     // ... reload
      } else if (lcd_data.cursor_id == MENUE_POSITION_GOTO_HOME) { 
        report_status_message(gc_execute_line("G28"));
        lcd_data.refresh      =  1;     // ... reload
      } else if (lcd_data.cursor_id == MENUE_POSITION_GOTO_ZERO) { 
        report_status_message(gc_execute_line("G90"));
        report_status_message(gc_execute_line("G1X0Y0U0Z0"));
        lcd_data.refresh      =  1;     // ... reload
      } else if (lcd_data.cursor_id == MENUE_POSITION_SET_ZERO) { 
        report_status_message(gc_execute_line("G10L20P1X0Y0U0Z0"));
        lcd_data.refresh      =  1;     // ... reload
      }
    } else if (lcd_data.buttons_redge & BTN_X_PLUS) {

      gc_command =  "G91F" + String(settings.default_feed_rate, 0);
      gc_command.toCharArray(gc_c, 19);
      report_status_message(gc_execute_line(gc_c));     // change speed

      gc_command =  "G1X" + gc_step;
      gc_command.toCharArray(gc_c, 19);
      report_status_message(gc_execute_line(gc_c));
      lcd_data.refresh      =  1;     // ... reload
      
    } else if (lcd_data.buttons_redge & BTN_X_MINUS) {
      gc_command =  "G91F" + String(settings.default_feed_rate, 0);
      gc_command.toCharArray(gc_c, 19);
      report_status_message(gc_execute_line(gc_c));     // change speed

      gc_command =  "G1X-" + gc_step;
      gc_command.toCharArray(gc_c, 19);
      report_status_message(gc_execute_line(gc_c));
      lcd_data.refresh      =  1;     // ... reload
      
    } else if (lcd_data.buttons_redge & BTN_Y_PLUS) {
      gc_command =  "G91F" + String(settings.default_feed_rate, 0);
      gc_command.toCharArray(gc_c, 19);
      report_status_message(gc_execute_line(gc_c));     // change speed
      
      gc_command =  "G1Y" + gc_step;
      gc_command.toCharArray(gc_c, 19);
      report_status_message(gc_execute_line(gc_c));
      lcd_data.refresh      =  1;     // ... reload
      
    } else if (lcd_data.buttons_redge & BTN_Y_MINUS) {
      gc_command =  "G91F" + String(settings.default_feed_rate, 0);
      gc_command.toCharArray(gc_c, 19);
      report_status_message(gc_execute_line(gc_c));     // change speed

      gc_command =  "G1Y-" + gc_step;
      gc_command.toCharArray(gc_c, 19);
      report_status_message(gc_execute_line(gc_c));
      lcd_data.refresh      =  1;     // ... reload
      
    } else if (lcd_data.buttons_redge & BTN_U_PLUS) {
      gc_command =  "G91F" + String(settings.default_feed_rate, 0);
      gc_command.toCharArray(gc_c, 19);
      report_status_message(gc_execute_line(gc_c));     // change speed

      gc_command =  "G1U" + gc_step;
      gc_command.toCharArray(gc_c, 19);
      report_status_message(gc_execute_line(gc_c));
      lcd_data.refresh      =  1;     // ... reload
      
    } else if (lcd_data.buttons_redge & BTN_U_MINUS) {
      gc_command =  "G91F" + String(settings.default_feed_rate, 0);
      gc_command.toCharArray(gc_c, 19);
      report_status_message(gc_execute_line(gc_c));     // change speed

      gc_command =  "G1U-" + gc_step;
      gc_command.toCharArray(gc_c, 19);
      report_status_message(gc_execute_line(gc_c));
      lcd_data.refresh      =  1;     // ... reload
      
    } else if (lcd_data.buttons_redge & BTN_Z_PLUS) {
      gc_command =  "G1Z" + gc_step;
      gc_command.toCharArray(gc_c, 19);
      report_status_message(gc_execute_line("G91"));
      report_status_message(gc_execute_line(gc_c));
      lcd_data.refresh      =  1;     // ... reload
      
    } else if (lcd_data.buttons_redge & BTN_Z_MINUS) {
      gc_command =  "G91F" + String(settings.default_feed_rate, 0);
      gc_command.toCharArray(gc_c, 19);
      report_status_message(gc_execute_line(gc_c));     // change speed

      gc_command =  "G1Z-" + gc_step;
      gc_command.toCharArray(gc_c, 19);
      report_status_message(gc_execute_line(gc_c));
      lcd_data.refresh      =  1;     // ... reload
      
    }    
#else
    if (lcd_data.buttons_redge & BTN_BACK) {
      lcd_data.refresh        =  1;     // ... back to main menue
      lcd_data.menue_id       =  MENUE_POSITION_EXIT_MENUE;   
      lcd_data.cursor_id      =  MENUE_POSITION_EXIT_CURSOR;
    } 
    else if (lcd_data.buttons_redge & BTN_ROTARY_UP) {
      if (lcd_data.fvalue == 0) {
        if (lcd_data.cursor_id > MENUE_POSITION_SET_HOME) {     // if cursur is in range
          lcd_data.cursor_id    -= 1;     // ... select previous entry
          lcd_data.refresh      =  1;     // ... reload
        }
      } else {
        gc_command =  "G91F" + String(settings.default_feed_rate, 0);
        gc_command.toCharArray(gc_c, 19);
        report_status_message(gc_execute_line(gc_c));     // change speed

        if (lcd_data.cursor_id == MENUE_POSITION_X01MM)       report_status_message(gc_execute_line("G1X-0.1"));
        if (lcd_data.cursor_id == MENUE_POSITION_X1MM)        report_status_message(gc_execute_line("G1X-1"));
        if (lcd_data.cursor_id == MENUE_POSITION_X10MM)       report_status_message(gc_execute_line("G1X-10"));
        if (lcd_data.cursor_id == MENUE_POSITION_X100MM)      report_status_message(gc_execute_line("G1X-100"));
        if (lcd_data.cursor_id == MENUE_POSITION_U01MM)       report_status_message(gc_execute_line("G1U-0.1"));
        if (lcd_data.cursor_id == MENUE_POSITION_U1MM)        report_status_message(gc_execute_line("G1U-1"));
        if (lcd_data.cursor_id == MENUE_POSITION_U10MM)       report_status_message(gc_execute_line("G1U-10"));
        if (lcd_data.cursor_id == MENUE_POSITION_U100MM)      report_status_message(gc_execute_line("G1U-100"));
        if (lcd_data.cursor_id == MENUE_POSITION_Y01MM)       report_status_message(gc_execute_line("G1Y-0.1"));
        if (lcd_data.cursor_id == MENUE_POSITION_Y1MM)        report_status_message(gc_execute_line("G1Y-1"));
        if (lcd_data.cursor_id == MENUE_POSITION_Y10MM)       report_status_message(gc_execute_line("G1Y-10"));
        if (lcd_data.cursor_id == MENUE_POSITION_Y100MM)      report_status_message(gc_execute_line("G1Y-100"));
        if (lcd_data.cursor_id == MENUE_POSITION_Z01MM)       report_status_message(gc_execute_line("G1Z-0.1"));
        if (lcd_data.cursor_id == MENUE_POSITION_Z1MM)        report_status_message(gc_execute_line("G1Z-1"));
        if (lcd_data.cursor_id == MENUE_POSITION_Z10MM)       report_status_message(gc_execute_line("G1Z-10"));
        if (lcd_data.cursor_id == MENUE_POSITION_Z100MM)      report_status_message(gc_execute_line("G1Z-100"));
      
        lcd_data.refresh      =  1;     // ... reload
      }
    } 
    else if (lcd_data.buttons_redge & BTN_ROTARY_DOWN) {
      if (lcd_data.fvalue == 0) {
        if (lcd_data.cursor_id < MENUE_POSITION_SET_ZERO) {     // if cursur is in range
          lcd_data.cursor_id    += 1;     // ... select next entry
          lcd_data.refresh      =  1;     // ... reload
        }
      } else {
        gc_command =  "G91F" + String(settings.default_feed_rate, 0);
        gc_command.toCharArray(gc_c, 19);
        report_status_message(gc_execute_line(gc_c));     // change speed
        
        if (lcd_data.cursor_id == MENUE_POSITION_X01MM)       report_status_message(gc_execute_line("G1X0.1"));
        if (lcd_data.cursor_id == MENUE_POSITION_X1MM)        report_status_message(gc_execute_line("G1X1"));
        if (lcd_data.cursor_id == MENUE_POSITION_X10MM)       report_status_message(gc_execute_line("G1X10"));
        if (lcd_data.cursor_id == MENUE_POSITION_X100MM)      report_status_message(gc_execute_line("G1X100"));
        if (lcd_data.cursor_id == MENUE_POSITION_U01MM)       report_status_message(gc_execute_line("G1U0.1"));
        if (lcd_data.cursor_id == MENUE_POSITION_U1MM)        report_status_message(gc_execute_line("G1U1"));
        if (lcd_data.cursor_id == MENUE_POSITION_U10MM)       report_status_message(gc_execute_line("G1U10"));
        if (lcd_data.cursor_id == MENUE_POSITION_U100MM)      report_status_message(gc_execute_line("G1U100"));
        if (lcd_data.cursor_id == MENUE_POSITION_Y01MM)       report_status_message(gc_execute_line("G1Y0.1"));
        if (lcd_data.cursor_id == MENUE_POSITION_Y1MM)        report_status_message(gc_execute_line("G1Y1"));
        if (lcd_data.cursor_id == MENUE_POSITION_Y10MM)       report_status_message(gc_execute_line("G1Y10"));
        if (lcd_data.cursor_id == MENUE_POSITION_Y100MM)      report_status_message(gc_execute_line("G1Y100"));
        if (lcd_data.cursor_id == MENUE_POSITION_Z01MM)       report_status_message(gc_execute_line("G1Z0.1"));
        if (lcd_data.cursor_id == MENUE_POSITION_Z1MM)        report_status_message(gc_execute_line("G1Z1"));
        if (lcd_data.cursor_id == MENUE_POSITION_Z10MM)       report_status_message(gc_execute_line("G1Z10"));
        if (lcd_data.cursor_id == MENUE_POSITION_Z100MM)      report_status_message(gc_execute_line("G1Z100"));
        
        lcd_data.refresh      =  1;     // ... reload
      }

    } else if (lcd_data.buttons_redge & BTN_ROTARY_PUSH) {
      if (lcd_data.cursor_id == MENUE_POSITION_SET_HOME) { 
        report_status_message(gc_execute_line("G28.1"));
        lcd_data.refresh      =  1;     // ... reload
      } else if (lcd_data.cursor_id == MENUE_POSITION_GOTO_HOME) { 
        report_status_message(gc_execute_line("G28"));
        lcd_data.refresh      =  1;     // ... reload
      } else if (lcd_data.cursor_id == MENUE_POSITION_GOTO_ZERO) { 
        gc_command =  "G90F" + String(settings.default_feed_rate, 0);
        gc_command.toCharArray(gc_c, 19);
        report_status_message(gc_execute_line(gc_c));     // change speed
        report_status_message(gc_execute_line("G1X0Y0U0Z0"));
        lcd_data.refresh      =  1;     // ... reload
      } else if (lcd_data.cursor_id == MENUE_POSITION_SET_ZERO) { 
        report_status_message(gc_execute_line("G10L20P1X0Y0U0Z0"));
        lcd_data.refresh      =  1;     // ... reload
      } 
      else {
        if (lcd_data.fvalue == 0) {
          lcd_data.fvalue = 1;
        } else {
          lcd_data.fvalue = 0;
        }
        lcd_data.refresh      =  1;     // ... reload
      }
    } 
#endif

    lcd_data.buttons_redge        = 0;              // reset all edge indicators
    lcd_data.buttons_fedge        = 0; 
  }
}

// ===============================================================================================
//  Homing Menue 
// ===============================================================================================
void lcd_process_menue_homing() {
  float progress;
  if (lcd_data.menue_id == MENUE_HOMING_0) {
    if (lcd_data.refresh != 0) {                    // update the display on request
      lcd_data.refresh = 0;
      lcd.clearBuffer();
      // title
      lcd.setFont(u8g2_font_helvB08_tr);
      lcd.setCursor(  0, 8); lcd.print(F("Homing"));
      // menue items
      lcd.setFont(u8g2_font_helvR08_tr);
      lcd.setCursor(  6, 20);        
#if (USE_LIMIT_SWITCHES == 0)
      lcd.print(F("Not available"));  
#else 
      if (lcd_data.cursor_id == 0) {
        lcd.print(F("Execute?"));     
        lcd.setCursor( 80, 20); 
        lcd.print(F("NO"));     
      } else if (lcd_data.cursor_id == 1) {
        lcd.print(F("Execute?"));     
        lcd.setCursor( 80, 20); 
        lcd.print(F("YES"));     
      } else if (lcd_data.cursor_id == 2) {
        lcd.print(F("Set as new pull-off?  YES"));

        lcd_print_position('X', settings.homing_pulloff[X_AXIS] + gc.position[X_AXIS], 6,    38); 
        lcd_print_position('Y', settings.homing_pulloff[Y_AXIS] + gc.position[Y_AXIS], 6,    50); 
      
        lcd_print_position('U', settings.homing_pulloff[U_AXIS] + gc.position[U_AXIS], 6+64, 38); 
        lcd_print_position('Z', settings.homing_pulloff[Z_AXIS] + gc.position[Z_AXIS], 6+64, 50);       
      }   
#endif
      lcd.sendBuffer();
    }

    
#if (USE_LIMIT_SWITCHES == 1)
    if (lcd_data.buttons_redge & BTN_BACK) {
      lcd_data.refresh        =  1;     // ... back to main menue
      lcd_data.menue_id       =  MENUE_HOMING_EXIT_MENUE;   
      lcd_data.cursor_id      =  MENUE_HOMING_EXIT_CURSOR;
    }
    else if (lcd_data.buttons_redge & BTN_ROTARY_RIGHT) {
      if (lcd_data.cursor_id < 2)
          lcd_data.cursor_id  += 1;     // ... select next mode
        lcd_data.refresh      =  1;     // ... reload
    }
    else if (lcd_data.buttons_redge & BTN_ROTARY_LEFT) {
      if (lcd_data.cursor_id > 0)
          lcd_data.cursor_id  -= 1;     // ... select previous mode
        lcd_data.refresh      =  1;     // ... reload
    } 
    else if (lcd_data.buttons_redge & BTN_ROTARY_PUSH) {
      if (lcd_data.cursor_id == 1) {
        // Performe Homing
        report_status_message(protocol_execute_line("$H"));
      }
      if (lcd_data.cursor_id == 2) {
        // Calculate next homing pull-off and store it
        // new pull-off is old pull off + current position
        settings_store_global_setting(SETTINGS_INDEX_PULLOFF_X, settings.homing_pulloff[X_AXIS] + gc.position[X_AXIS]);
        settings_store_global_setting(SETTINGS_INDEX_PULLOFF_Y, settings.homing_pulloff[Y_AXIS] + gc.position[Y_AXIS]);
        settings_store_global_setting(SETTINGS_INDEX_PULLOFF_U, settings.homing_pulloff[U_AXIS] + gc.position[U_AXIS]);
        settings_store_global_setting(SETTINGS_INDEX_PULLOFF_Z, settings.homing_pulloff[Z_AXIS] + gc.position[Z_AXIS]);

 
        // The gcode parser position circumvented by the pull-off maneuver, so sync position vectors and set it to zero
        clear_vector_float(sys.position);         // Set machine zero
        clear_vector_float(gc.position);
        clear_vector_float(gc.coord_system);
        clear_vector_float(gc.coord_offset);
    
        sys_sync_current_position();

      }
      lcd_data.refresh        =  1;     // ... back to main menue
      lcd_data.menue_id       =  MENUE_HOMING_EXIT_MENUE;   
      lcd_data.cursor_id      =  MENUE_HOMING_EXIT_CURSOR;
    }
#else 
    if (lcd_data.buttons_redge & (BTN_BACK | BTN_ROTARY_PUSH)) {
      lcd_data.refresh        =  1;     // ... back to main menue
      lcd_data.menue_id       =  MENUE_HOMING_EXIT_MENUE;   
      lcd_data.cursor_id      =  MENUE_HOMING_EXIT_CURSOR;
    }
#endif
    
    lcd_data.buttons_redge        = 0;              // reset all edge indicators
    lcd_data.buttons_fedge        = 0; 
  }
}
// ===============================================================================================
//  Feed Speed Menue 
// ===============================================================================================
void lcd_print_speed(float value, uint8_t x, uint8_t y) {
  // print label
  lcd.setCursor(x, y);
  
  // print the sign
  if (value < 1000) {
    lcd.setCursor(x, y);
    lcd.print(F("0"));
    x += 6;
  }
  if (value < 100) {
    lcd.setCursor(x, y);
    lcd.print(F("0"));
    x += 6;
  }
  if (value < 10) {
    lcd.setCursor(x, y);
    lcd.print(F("0"));
    x += 6;
  }
  lcd.setCursor(x, y);
  lcd.print(value, 0); 
}



void lcd_process_menue_feed() {
  float progress;
  if (lcd_data.menue_id == MENUE_FEED_0) {
    if (lcd_data.refresh != 0) {                    // update the display on request
      lcd_data.refresh = 0;
      lcd.clearBuffer();
      // title
      lcd.setFont(u8g2_font_helvB08_tr);
      lcd.setCursor(  0, 8);  lcd.print(F("Feed speed"));
            lcd.setFont(u8g2_font_helvR08_tr);
      lcd.setCursor(70, 8);      lcd.print(F("in mm/min"));
      // menue items
      lcd.setFont(u8g2_font_helvR08_tr);
      lcd.setCursor(  0, 20); lcd.print(F(">")); 
      lcd_print_speed(lcd_data.fvalue, 6, 20);
      
      lcd.sendBuffer();
    }
    if (lcd_data.buttons_redge & BTN_BACK) {
      lcd_data.refresh        =  1;     // ... back to main menue
      lcd_data.menue_id       =  MENUE_FEED_EXIT_MENUE;   
      lcd_data.cursor_id      =  MENUE_FEED_EXIT_CURSOR;
    }
    else if (lcd_data.buttons_redge & BTN_ROTARY_RIGHT) {
      lcd_data.fvalue         += 10;
      if (lcd_data.fvalue > DEFAULT_FEEDRATE_MAX)
        lcd_data.fvalue       =  DEFAULT_FEEDRATE_MAX;
      lcd_data.refresh        =  1;     // ... reload
    }
    else if (lcd_data.buttons_redge & BTN_ROTARY_LEFT) {
      if (lcd_data.fvalue > (DEFAULT_FEEDRATE_MIN + 10)) {
        lcd_data.fvalue       -=  10;
      } else {
        lcd_data.fvalue       = DEFAULT_FEEDRATE_MIN;
      }
      lcd_data.refresh        =  1;     // ... reload
    }
    else if (lcd_data.buttons_redge & (BTN_Y_PLUS | BTN_Z_PLUS)) {
      lcd_data.fvalue         += 100;
      if (lcd_data.fvalue > DEFAULT_FEEDRATE_MAX)
        lcd_data.fvalue       =  DEFAULT_FEEDRATE_MAX;
      lcd_data.refresh        =  1;     // ... reload
    }
    else if (lcd_data.buttons_redge & (BTN_Y_MINUS | BTN_Z_MINUS)) {
      if (lcd_data.fvalue > (DEFAULT_FEEDRATE_MIN + 100)) {
        lcd_data.fvalue       -=  100;
      } else {
        lcd_data.fvalue       = DEFAULT_FEEDRATE_MIN;
      }
      lcd_data.refresh        =  1;     // ... reload
    } 
    else if (lcd_data.buttons_redge & BTN_ROTARY_PUSH) {
      settings.default_feed_rate    =  lcd_data.fvalue;
      settings_store_global_setting(SETTINGS_DEFAULT_FEED_RATE, settings.default_feed_rate);      // store the new setting
      
      String gc_command;
      char gc_c[30];
      gc_command =  "F" + String(settings.default_feed_rate, 0);
      gc_command.toCharArray(gc_c, 29);
      report_status_message(gc_execute_line(gc_c));     // change speed
        
      lcd_data.refresh        =  1;     // ... reload
      
      lcd_data.refresh        =  1;     // ... back to main menue
      lcd_data.menue_id       =  MENUE_FEED_EXIT_MENUE;   
      lcd_data.cursor_id      =  MENUE_FEED_EXIT_CURSOR;
    }
    
    lcd_data.buttons_redge        = 0;              // reset all edge indicators
    lcd_data.buttons_fedge        = 0; 
  }
}



// ===============================================================================================
//  Fan Menue 
// ===============================================================================================
void lcd_process_menue_fan() {
  float progress;
  if (lcd_data.menue_id == MENUE_FAN_0) {
    if (lcd_data.refresh != 0) {                    // update the display on request
      lcd_data.refresh = 0;
      lcd.clearBuffer();
      // title
      lcd.setFont(u8g2_font_helvB08_tr);
      lcd.setCursor(  0, 8);  lcd.print(F("Fan"));
      // menue items
          // menue items
      lcd.setFont(u8g2_font_helvR08_tr);
      lcd.setCursor(  0, 20); lcd.print(F(">"));       
      lcd.setCursor(  6, 20); lcd.print(F("Mode:"));       
      lcd.setCursor( 40, 20);
       switch (lcd_data.cursor_id) {
        case 0:
          lcd.print(F("OFF"));
          break;
        case 1:
          lcd.print(F("ON"));
          break;
        default:
          lcd.print(F("MANUEL"));
          break;
      }
      lcd.drawRFrame( 6,  30, 116,   15,  2);         // ... draw progressbar with actual fan speed
      if (lcd_data.cursor_id != 0) {
        progress = fan_pwr();
        progress *= 112;                                
        progress /= 100;
        if (progress > 112)
          progress = 112;
        lcd.drawBox   ( 8,  32, (u8g2_uint_t)progress,   11);   
      }

      lcd.sendBuffer();
    }

      if (lcd_data.buttons_redge & BTN_BACK) {
      lcd_data.refresh        =  1;     // ... back to main menue
      lcd_data.menue_id       =  MENUE_FAN_EXIT_MENUE;   
      lcd_data.cursor_id      =  MENUE_FAN_EXIT_CURSOR;
    }
    else if (lcd_data.buttons_redge & BTN_ROTARY_RIGHT) {
      if (lcd_data.cursor_id < 2) {
        lcd_data.cursor_id    += 1;     // ... select next mode
        lcd_data.refresh      =  1;     // ... reload
      }
    }
    else if (lcd_data.buttons_redge & BTN_ROTARY_LEFT) {
      if (lcd_data.cursor_id > 0) {     // 
        lcd_data.cursor_id    -= 1;     // ... select previous mode
        lcd_data.refresh      =  1;     // ... reload
      }
    } else if (lcd_data.buttons_redge & BTN_ROTARY_PUSH) {
      lcd_data.refresh        =  1;     
      fan_run(lcd_data.cursor_id, settings.fan_pwr);     // .. update the hotwire
      if (lcd_data.cursor_id == 2) {
        lcd_data.cursor_id    =  (uint8_t)fan_pwr();
        lcd_data.menue_id     =  MENUE_FAN_1; 
      } else {
        lcd_data.menue_id     =  MENUE_FAN_EXIT_MENUE;   
        lcd_data.cursor_id    =  MENUE_FAN_EXIT_CURSOR;
      }
    }
       
    lcd_data.buttons_redge        = 0;              // reset all edge indicators
    lcd_data.buttons_fedge        = 0; 
  }

  
  if (lcd_data.menue_id == MENUE_FAN_1) {
    if (lcd_data.refresh != 0) {                    // update the display on request
      lcd_data.refresh = 0;
      lcd.clearBuffer();
      uint8_t x;
      // title
      lcd.setFont(u8g2_font_helvB08_tr);
      lcd.setCursor(  0, 8);  lcd.print(F("Fan"));
      // menue items
     // menue items
      lcd.setFont(u8g2_font_helvR08_tr);
      lcd.setCursor(  6, 20); lcd.print(F("Mode:"));       
      lcd.setCursor( 40, 20); lcd.print(F("MANUAL"));
      lcd.setCursor(  0, 41); lcd.print(F(">"));       
      
      lcd.drawRFrame( 6,  30, 116,   15,  2);         // ... draw progressbar with selected fan speed
      progress = (float)lcd_data.cursor_id;
      progress *= 112;                                
      progress /= 100;
      if (progress > 112)
        progress = 112;
      lcd.drawBox   ( 8,  32, (u8g2_uint_t)progress,   11);   
      
      lcd.sendBuffer();
    }

    if (lcd_data.buttons_redge & BTN_BACK) {
      lcd_data.refresh        =  1;     // ... back to main menue
      lcd_data.menue_id       =  MENUE_FAN_EXIT_MENUE;   
      lcd_data.cursor_id      =  MENUE_FAN_EXIT_CURSOR;
      fan_off();                        // ... switch fan off
                                        // don't save to settings
    }
    else if (lcd_data.buttons_redge & BTN_ROTARY_RIGHT) {
      if (lcd_data.cursor_id < 100) {
        lcd_data.cursor_id    += 10;    // ... increase speed 
      } 
      if (lcd_data.cursor_id > 100) {
        lcd_data.cursor_id    =  100;   
      }
      fan_run(1, float(lcd_data.cursor_id));
      lcd_data.refresh        =  1;     // ... reload
    }
    else if (lcd_data.buttons_redge & BTN_ROTARY_LEFT) {
      if (lcd_data.cursor_id > 9) {     // 
        lcd_data.cursor_id    -= 10;    // ... decrease speed
        lcd_data.refresh      =  1;    
      } else {
        lcd_data.cursor_id    =  0;   
      }
      fan_run(1, float(lcd_data.cursor_id));
      lcd_data.refresh        =  1;     // ... reload
    } else if (lcd_data.buttons_redge & BTN_ROTARY_PUSH) {
      
      settings.fan_pwr        =  float(lcd_data.cursor_id);
      fan_run(1, settings.fan_pwr);
      settings_store_global_setting(SETTINGS_INDEX_FAN, settings.fan_pwr);      // store the new setting
      
      lcd_data.refresh        =  1;     // ... back 
      lcd_data.menue_id       =  MENUE_FAN_EXIT_MENUE;   
      lcd_data.cursor_id      =  MENUE_FAN_EXIT_CURSOR;
    }


    
    lcd_data.buttons_redge        = 0;              // reset all edge indicators
    lcd_data.buttons_fedge        = 0; 
  }
}

// ===============================================================================================
//  Hotwire Menue 
// ===============================================================================================
void lcd_process_menue_hotwire() {
  float progress;
  if (lcd_data.menue_id == MENUE_HOTWIRE_0) {
    if (lcd_data.refresh != 0) {                    // update the display on request
      lcd_data.refresh = 0;
      lcd.clearBuffer();
      // title
      lcd.setFont(u8g2_font_helvB08_tr);

      lcd.setCursor(  0, 8);  lcd.print(F("Hot wire"));
      // menue items
      lcd.setFont(u8g2_font_helvR08_tr);
      lcd.setCursor(  0, 20); lcd.print(F(">"));       
      lcd.setCursor(  6, 20); lcd.print(F("Mode:"));       
      lcd.setCursor( 40, 20);
       switch (lcd_data.cursor_id) {
        case 0:
          lcd.print(F("OFF"));
          break;
        case 1:
          lcd.print(F("ON"));
          break;
        default:
          lcd.print(F("MANUEL"));
          break;
      }
      lcd.drawRFrame( 6,  30, 116,   15,  2);         // ... draw progressbar with actual fan speed
      if (lcd_data.cursor_id != 0) {
        progress = settings.hotwire_pwr;
        progress *= 112;                                
        progress /= 100;
        if (progress > 112)
          progress = 112;
        lcd.drawBox   ( 8,  32, (u8g2_uint_t)progress,   11);   
      }
      
      lcd.sendBuffer();
    }

    if (lcd_data.buttons_redge & BTN_BACK) {
      lcd_data.refresh        =  1;     // ... back to main menue
      lcd_data.menue_id       =  MENUE_HOTWIRE_EXIT_MENUE;   
      lcd_data.cursor_id      =  MENUE_HOTWIRE_EXIT_CURSOR;
    }
    else if (lcd_data.buttons_redge & BTN_ROTARY_RIGHT) {
      if (lcd_data.cursor_id < 2) {
        lcd_data.cursor_id    += 1;     // ... select next mode
        lcd_data.refresh      =  1;     // ... reload
      }
    }
    else if (lcd_data.buttons_redge & BTN_ROTARY_LEFT) {
      if (lcd_data.cursor_id > 0) {     // 
        lcd_data.cursor_id    -= 1;     // ... select previous mode
        lcd_data.refresh      =  1;     // ... reload
      }
    } else if (lcd_data.buttons_redge & BTN_ROTARY_PUSH) {
      lcd_data.refresh        =  1;     
      hotwire_run(lcd_data.cursor_id, settings.hotwire_pwr);    // .. update the hotwire

      if (lcd_data.cursor_id == 2) {
        lcd_data.cursor_id    =  (uint8_t)settings.hotwire_pwr;
        lcd_data.menue_id     =  MENUE_HOTWIRE_1; 
      } else {
        lcd_data.menue_id     =  MENUE_HOTWIRE_EXIT_MENUE;   
        lcd_data.cursor_id    =  MENUE_HOTWIRE_EXIT_CURSOR;
      }
    }
   
    lcd_data.buttons_redge        = 0;              // reset all edge indicators
    lcd_data.buttons_fedge        = 0; 
  }

  
  if (lcd_data.menue_id == MENUE_HOTWIRE_1) {
    if (lcd_data.refresh != 0) {                    // update the display on request
      lcd_data.refresh = 0;
      lcd.clearBuffer();
      uint8_t x;
      // title
      lcd.setFont(u8g2_font_helvB08_tr);
      lcd.setCursor(  0, 8);  lcd.print(F("Hot wire"));
      // menue items
      lcd.setFont(u8g2_font_helvR08_tr);
      lcd.setCursor(  6, 20); lcd.print(F("Mode:"));       
      lcd.setCursor( 40, 20); lcd.print(F("MANUAL"));
      lcd.setCursor(  0, 41); lcd.print(F(">"));       
      
      lcd.drawRFrame( 6,  30, 116,   15,  2);         // ... draw progressbar with selected fan speed
      progress = (float)lcd_data.cursor_id;
      progress *= 112;                                
      progress /= 100;
      if (progress > 112)
        progress = 112;
      lcd.drawBox   ( 8,  32, (u8g2_uint_t)progress,   11);   
      
      lcd.sendBuffer();
    }

    if (lcd_data.buttons_redge & BTN_BACK) {
      lcd_data.refresh        =  1;     // ... back to main menue
      lcd_data.menue_id       =  MENUE_HOTWIRE_EXIT_MENUE;   
      lcd_data.cursor_id      =  MENUE_HOTWIRE_EXIT_CURSOR;
      hotwire_off();                    // ... switch hotwire off
                                        // don't save to settings
    }
    else if (lcd_data.buttons_redge & BTN_ROTARY_RIGHT) {
      if (lcd_data.cursor_id < 100) {
        lcd_data.cursor_id    += 10;    // ... increase speed 
      } 
      if (lcd_data.cursor_id > 100) {
        lcd_data.cursor_id    =  100;   
      }
      hotwire_run(1, float(lcd_data.cursor_id));
      lcd_data.refresh        =  1;     // ... reload
    }
    else if (lcd_data.buttons_redge & BTN_ROTARY_LEFT) {
      if (lcd_data.cursor_id > 9) {     // 
        lcd_data.cursor_id    -= 10;    // ... decrease speed
        lcd_data.refresh      =  1;    
      } else {
        lcd_data.cursor_id    =  0;   
      }
      hotwire_run(1, float(lcd_data.cursor_id));
      lcd_data.refresh        =  1;     // ... reload
    } else if (lcd_data.buttons_redge & BTN_ROTARY_PUSH) {
      
      settings.hotwire_pwr    =  float(lcd_data.cursor_id);
      hotwire_run(1, settings.hotwire_pwr);
      settings_store_global_setting(SETTINGS_INDEX_HOTWIRE, settings.hotwire_pwr);      // store the new setting
      
      lcd_data.refresh        =  1;     // ... back 
      lcd_data.menue_id       =  MENUE_HOTWIRE_EXIT_MENUE;   
      lcd_data.cursor_id      =  MENUE_HOTWIRE_EXIT_CURSOR;
    }
    
    lcd_data.buttons_redge        = 0;              // reset all edge indicators
    lcd_data.buttons_fedge        = 0; 
  }
}


// ===============================================================================================
//  SD-Card Menue
// ===============================================================================================
char *fileExtensions[] = SUPPORTED_FILE_EXTENSTIONS;
bool chk_file(SdFile *file) {
  if (!(file->isFile())) {
    return false;               
  }
  if (file->isHidden()) {
    return false;               
  }
  if (file->isSystem()) {
    return false;              
  }
  char filename[18];
  uint8_t i;
  file->getName(filename, 18);         // ... get filename
  for (i=0; i < 4; i++) {
    if (strcmp(fileExtensions[i], &filename[strlen(filename)-strlen(fileExtensions[i])]) == 0) {
      return true;
    }
  }
  return false;
}
void lcd_process_menue_sdcard() {
  if (lcd_data.menue_id == MENUE_SDCARD_0) {
    char filename[18];
    uint8_t nfiles, line;
    bool draw;
      
    if (lcd_data.refresh != 0) {                    // update the display on request
      lcd_data.refresh = 0;
      lcd.clearBuffer();
      // title
      lcd.setFont(u8g2_font_helvB08_tr);

      lcd.setCursor(  0, 8);  lcd.print(F("SD-Card"));
      // menue items
      lcd.setFont(u8g2_font_helvR08_tr);
      lcd.setCursor(  6, 20);        
      if (sd_data.errors & ERR_SDCARD) {
        lcd.print(F("Error on SD-Card slot."));
      } else if ((lcd_data.buttons & SD_DETECTED) == 0) {
        lcd.print(F("No SD-Card detected."));
        sd_data.errors   &= ~ERR_SDCARD;  
      } else {
        if (!sd.begin(PIN_SD_CS, SD_SCK_MHZ(50))) {
          sd_data.errors |= ERR_SDCARD;   
        } else {
          // Check for files in root directory
          if (!root.open("/")) {
            sd_data.errors       |= ERR_SDCARD;    // ... unable to open the files
            lcd_data.refresh     =  1;             // ... reload
          } else {
            line      = 0;                          // ... go through all files in root dir and list them
            nfiles    = 0;
            while (file.openNext(&root, O_RDONLY)) {
              if (chk_file(&file)) {                // if file is valid
                draw = false;
                if (lcd_data.cursor_id == 0) {      // ... first page
                  if (nfiles < 5) {
                    draw = true;
                  }
                } else {                            // ... other pages
                  if ((nfiles >= (lcd_data.cursor_id - 1)) && (nfiles <= (lcd_data.cursor_id + 3))) {
                    draw = true;  
                  }
                }
                if (draw == true) {                 // ... draw the line
                  file.getName(filename, 18);       // ... get filename
                  lcd.drawStr(  6, 20 + (line * 12), filename);
                  line++;
                }
                nfiles++;                       // ... count the total number of files
              } // if (chk_file(&file))  
              file.close();
            } // while (file.openNext(&root, O_RDONLY))  
            file.close();

            if (nfiles > 0) {                       // cursor and scrollbar only if files available
              lcd.setFont(FONT_CURSOR_HOR);         // ... draw cursor
              if (lcd_data.cursor_id == 0) {         
                lcd.setFont(FONT_CURSOR_HOR);
                lcd.drawStr(  0, 20,">");
              } else {     
                lcd.drawStr(  0, 32,">");
              }
              lcd.setFont(u8g2_font_helvR08_tr);
              lcd.setCursor( 50, 8);  lcd.print(F("root dir only"));
                                                    // ... draw the scrollbar
              lcd.setDrawColor(0);
              lcd.drawBox(117,  0, 10, 64);         // ... spacer to scrollbar
              lcd.setDrawColor(1);
              lcd.drawRFrame(120,  0,  8, 64,  2);  // ... frame for scrollbar
              if (lcd_data.cursor_id == 0) {        // ... top    
                if (nfiles == 1) {
                  lcd.drawBox (122,  2,  4, 60);    // ... only one file
                } else {
                  lcd.drawBox (122,  2,  4, 20);    // .. more than one file
                }
              } else if (lcd_data.cursor_id == (nfiles -1)) {            
                lcd.drawBox   (122, 42,  4, 20);    // ... bottom  
              } else {
                lcd.drawBox   (122, 22,  4, 20);    // ... middle
              }
            } else {
              lcd.drawStr(  6,    20,"No files in root dir.");
            }
            
          } // else of if (!root.open("/"))
          root.close();
        } // else of if (!sd.begin(PIN_SD_CS, SD_SCK_MHZ(50)))
        
      } // end else no sd card or error
      lcd.sendBuffer();
    }

    if ((lcd_data.buttons_redge & SD_DETECTED) || (lcd_data.buttons_fedge & SD_DETECTED)) {
      lcd_data.refresh        =  1;                 // ... update screen, if sd card has changed
      if ((lcd_data.buttons & SD_DETECTED) == 0) {  // ... if sd card was removed, 
        sd_data.errors        &= ~ERR_SDCARD;       // ... clear the errors
        lcd_data.cursor_id    =  0;                 // ... reset the cursur position
      }
    }
    if (lcd_data.buttons_redge & BTN_BACK) {
      lcd_data.refresh        =  1;     // ... back to main menue
      lcd_data.menue_id       =  MENUE_SDCARD_EXIT_MENUE;   
      lcd_data.cursor_id      =  MENUE_SDCARD_EXIT_CURSOR;
    }
    else if (lcd_data.buttons_redge & BTN_ROTARY_UP) {
      if (lcd_data.cursor_id > 0) {     // if cursur is in range
        lcd_data.cursor_id    -= 1;     // ... select previous entry
        lcd_data.refresh      =  1;     // ... reload
      }
    }
    else if (lcd_data.buttons_redge & BTN_ROTARY_DOWN) {
      if (lcd_data.cursor_id < (nfiles-1)) {     // if cursur is in range
        lcd_data.cursor_id    += 1;     // ... select next entry
        lcd_data.refresh      =  1;     // ... reload
      }
    } 
    else if (lcd_data.buttons_redge & BTN_ROTARY_PUSH) {
                                        // selection of file only if no errors....
        lcd_data.refresh            =  1;   // ... process the sd card
        lcd_data.menue_id           =  PROCESS_SDCARD_0;   
        sd_data.fileIndex           =  lcd_data.cursor_id;    // index of file to be processed
        sd_data.stateProcessFile    =  0;                     // start the processing of the sd card
    }
    
    lcd_data.buttons_redge        = 0;              // reset all edge indicators
    lcd_data.buttons_fedge        = 0; 
  }
}



void lcd_process(){
  // read the buttons and stabilize
  uint32_t image = 0;
#if (USE_BUTTONS == 0)  
  if (digitalRead(PIN_BTN_ONBOARD) == LOW)
    image                       |=  BTN_BACK;
#else
  if (digitalRead(PIN_BTN_ONBOARD) == LOW)
    image                       |=  BTN_ONBOARD;
  if (digitalRead(PIN_BTN_BACK) == LOW)
    image                       |=  BTN_BACK;
#endif

  if (digitalRead(PIN_ENC) == LOW)
    image                       |=  BTN_ROTARY_PUSH;
  if (digitalRead(PIN_EN1) == LOW)
    image                       |=  BTN_ROTARY_EN1;
  if (digitalRead(PIN_EN2) == LOW)
    image                       |=  BTN_ROTARY_EN2;
  if (digitalRead(PIN_SD_DET) == LOW)
    image                       |=  SD_DETECTED;

#if (USE_BUTTONS == 1)      
  if (digitalRead(PIN_BTN_HOTWIRE) == LOW)
    image                       |=  BTN_HOTWIRE;
  if (digitalRead(PIN_BTN_NONE_0) == LOW)
    image                       |=  BTN_NONE_0;
  if (digitalRead(PIN_BTN_X_PLUS) == LOW)
    image                       |=  BTN_X_PLUS;
  if (digitalRead(PIN_BTN_X_MINUS) == LOW)
    image                       |=  BTN_X_MINUS;
  if (digitalRead(PIN_BTN_Y_PLUS) == LOW)
    image                       |=  BTN_Y_PLUS;
  if (digitalRead(PIN_BTN_Y_MINUS) == LOW)
    image                       |=  BTN_Y_MINUS;
  if (digitalRead(PIN_BTN_Z_PLUS) == LOW)
    image                       |=  BTN_Z_PLUS;
  if (digitalRead(PIN_BTN_Z_MINUS) == LOW)
    image                       |=  BTN_Z_MINUS;
  if (digitalRead(PIN_BTN_U_PLUS) == LOW)
    image                       |=  BTN_U_PLUS;
  if (digitalRead(PIN_BTN_U_MINUS) == LOW)
    image                       |=  BTN_U_MINUS;
#endif
     
  // wait until all buttons are stable
  if (image == lcd_data.buttons_image) {
    if (lcd_data.buttons_cnt >= 50) {
      lcd_data.buttons_cnt      = 0;
      // set previous buttons state
      lcd_data.buttons_prev     = lcd_data.buttons;
      // set new button state
      lcd_data.buttons          = image;
      // check for rising edges
      lcd_data.buttons_redge    = (lcd_data.buttons ^ lcd_data.buttons_prev) & lcd_data.buttons;
      // check for falling edges
      lcd_data.buttons_fedge    = (lcd_data.buttons ^ lcd_data.buttons_prev) & lcd_data.buttons_prev; 
      // decode the rotary switch
      if (lcd_data.buttons_fedge & BTN_ROTARY_EN1) {
        if (lcd_data.buttons & BTN_ROTARY_EN2) {
          lcd_data.buttons_redge |= BTN_ROTARY_LEFT;
        } else {
          lcd_data.buttons_redge |= BTN_ROTARY_RIGHT;
        }
      }
    } else {
      lcd_data.buttons_cnt      +=  1;
    }
  } else {
    lcd_data.buttons_image      =   image;
    lcd_data.buttons_cnt        =   0;
  }

#if (USE_BUTTONS == 1)
  // process global buttons
  if (lcd_data.buttons_redge & BTN_HOTWIRE) { 
    // toggle hotwire
    if (gc.hotwire == 0) {
      hotwire_run(1, settings.hotwire_pwr);
    } else {
      hotwire_off();
    }
  }
#endif

  // show and handle menues
  lcd_process_menue_welcome();
  lcd_process_menue_main();
  lcd_process_menue_position();
  lcd_process_menue_sdcard();
  lcd_process_menue_fan();
  lcd_process_menue_hotwire();
  lcd_process_menue_homing();
  lcd_process_menue_idle_stepper();
  lcd_process_menue_cutting();
  lcd_process_menue_feed();
  // lcd_process_menue_btn(); // TODO

  // process gcode from sd card
  sd_protocol_process();  
            
  // delete the edge indicators
  lcd_data.buttons_redge        = 0;
  lcd_data.buttons_fedge        = 0;
}






void sd_protocol_getline() {
  // read a byte from sd
  char c;
  if  (file.read(&c, 1) == 1) {
    
    sd_data.bytesProcessed++;
    
    
    if ((c == '\n') || (c == '\r') || (c == '\0') || (sd_data.bytesProcessed == sd_data.fileSize)) {    
                                                                    // check is line end has been reached            
      if (sd_data.lineBufferIndex > 0) {                            // if valid gcode has been read
        
        if ((c == '\n') || (c == '\r') || (c == '\0')) {            // close the line
          sd_data.lineBuffer[sd_data.lineBufferIndex]      = '\0'; 
          sd_data.stateProcessFile                         = 7;     // and process it 
        } else {
          sd_data.lineBuffer[sd_data.lineBufferIndex + 1]  = '\0';
          sd_data.stateProcessFile                         = 8;     // and do final, processing 
        }
      } else {
        report_status_message(STATUS_OK);                           // empty or comment line >>> Skip block with ok
        if (sd_data.bytesProcessed == sd_data.fileSize) {           // if final line, 
          sd_data.stateProcessFile                         = 9;     // close processing
        }
      }
      sd_data.lineBufferIndex   = 0;
      sd_data.isComment         = 0;
      if ((sd_data.bytesProcessed == sd_data.fileSize)) {
        
      }
    } else {
      if (sd_data.isComment) {                                      // throw away all comments until end of comment
        if (c == ')') {
          sd_data.isComment     = 0;
        }
      } else {
        if (c <= ' ') {                                             // Throw away whitepace and control characters
          
        } else if (c == '/') {
                                                                    // Block delete not supported. Ignore character.
        } else if (c == '(') {                                      // Enable comments flag and ignore all characters until ')' or EOL.
          sd_data.isComment     = 1;
        } else if (sd_data.lineBufferIndex >= SD_LINE_BUFFER_SIZE-1) { // Report line buffer overflow and reset
          
          report_status_message(STATUS_OVERFLOW);   
          sd_data.lineBufferIndex   = 0;
          sd_data.isComment         = 0;
        } else if (c >= 'a' && c <= 'z') {                          // Upcase lowercase and store the byte
          sd_data.lineBuffer[sd_data.lineBufferIndex++] = c - 'a'+'A';
        } else {
          sd_data.lineBuffer[sd_data.lineBufferIndex++] = c;       // store the byte
        }
      }
    }
  } else {
    sd_data.stateProcessFile                         = 9;     // close processing
  }
}




void sd_protocol_process() {
  if (lcd_data.menue_id != PROCESS_SDCARD_0) {
    return;
  }
  if (sd_data.stateProcessFile == 0) {              // initialize processing ...
    
    sd_data.bytesProcessed        = 0;
    sd_data.lineBufferIndex       = 0;
    sd_data.stateProcessFile      = 1;
    return;
  }
  
  lcd_data.refresh            =  0;

  if (sd_data.stateProcessFile == 0xFE) {          // error idle state ... wait for button
    hotwire_off();                                 // witch the hotwire off
    if (lcd_data.buttons_redge & (BTN_BACK | BTN_ROTARY_PUSH)) {
      sd_data.stateProcessFile    =  0xFF;
    }  
    return;
  }
  
  if (sd_data.stateProcessFile == 0xFF) {          // error idle state ...
                                                    // reset the statemachines and close all files
    file.close();
    root.close();     
    lcd_data.refresh            =  1;               // ... back to main menue
    lcd_data.menue_id           =  MENUE_SDCARD_EXIT_MENUE;   
    lcd_data.cursor_id          =  MENUE_SDCARD_EXIT_CURSOR;           
    sd_data.stateProcessFile    =  0;
    lcd_data.buttons_redge      =  0;               // reset all edge indicators
    lcd_data.buttons_fedge      =  0; 
    return;
  }
  
  if (sd_data.stateProcessFile >= 0xF0) {           // error in file Handling ...
    lcd.clearBuffer();
    lcd.setFont(u8g2_font_helvB08_tr);
    lcd.setCursor(  0,  8);  lcd.print(F("Process from SD-Card"));
    lcd.setFont(u8g2_font_helvR08_tr);
    lcd.setCursor(  6, 20);  
    
    switch (sd_data.stateProcessFile) {
      case 0xF0:  lcd.print(F("Error with file handling."));            break;
      case 0xF1:  lcd.print(F("Execution interrupted."));               break;
      case 0xF2:  lcd.print(F("No SD-Card available."));                break;
      case 0xF3:  lcd.print(F("Unable to open SD-Card."));              break;
      case 0xF4:  lcd.print(F("Unable to open directory."));            break;
      case 0xF5:  lcd.print(F("Unable to open file."));                 break;
      case 0xF6:  lcd.print(F("Interrupted by user."));                 break;
      case 0xFD:  lcd.print(F("Finished."));                            break;
      default:    lcd.print(F("Error unknown."));                       break;
    }
    
    lcd.sendBuffer();    

    lcd_data.buttons_redge        = 0;              // reset all edge indicators
    lcd_data.buttons_fedge        = 0; 
    sd_data.stateProcessFile      = 0xFE;           // switch to error idle state ...
    return;
  }

  if ((lcd_data.buttons & SD_DETECTED) == 0) {
      sd_data.stateProcessFile   =  0xF2;
      return;
  }
  if (lcd_data.buttons_redge & BTN_BACK) {          // user abbroud
      sd_data.stateProcessFile   =  0xF6;
      return;
    }  
  if (sd_data.errors) {                             // TODO löschen?!?!?!
      sd_data.stateProcessFile   =  0xFE;           // check for errors
      return;
  }
  
  if (sd_data.stateProcessFile == 1) {              // find file and open it ...
    uint16_t fileIndex  = 0; 
    
    if (!sd.begin(PIN_SD_CS, SD_SCK_MHZ(50))) {     // try to find the file and open it
      sd_data.stateProcessFile = 0xF3;
      return;
    }
    if (!root.open("/")) {
      sd_data.stateProcessFile = 0xF4;
      return;
    }
    fileIndex  = 0;
    while (file.openNext(&root, O_RDONLY)) {
      if (chk_file(&file)) { 
        if (fileIndex == sd_data.fileIndex) {         // .. if this is the file to be opened
          file.getName(sd_data.filename, 18);         // ... get filename and sSize    
          sd_data.fileSize          = file.fileSize();   
          sd_data.stateProcessFile  = 2;
          lcd_data.cursor_id        = 0;
          return;
        }
        fileIndex++;
      } // if (chk_file(&file))
      file.close();
    } // while (fileOpened == false)
    sd_data.stateProcessFile = 0xF5;               // file not found
    return;
  } // if (sd_data.stateProcessFile == 1)
  if (sd_data.stateProcessFile == 2) {             // ask for execuzting the selected file...
    lcd.clearBuffer();
    lcd.setFont(u8g2_font_helvB08_tr);
    lcd.setCursor(  0,  8);  lcd.print(F("Process from SD-Card"));
    lcd.setFont(u8g2_font_helvR08_tr);
    lcd.setCursor(  6, 20);  lcd.print(sd_data.filename);
    lcd.setCursor(  6, 44);  lcd.print(F("Execute?"));
    lcd.setCursor( 80, 44);
    if (lcd_data.cursor_id == 0) {
      lcd.print(F("NO"));
    } else {
      lcd.print(F("YES"));
    }   
    lcd.sendBuffer();    
    lcd_data.buttons_redge        = 0;              // ... reset all edge indicators
    lcd_data.buttons_fedge        = 0; 
    sd_data.stateProcessFile      = 3;
    return;
  } // if (sd_data.stateProcessFile == 2)
  
  if (sd_data.stateProcessFile == 3) {              // wait for answer YES / NO  / BACK
    if (lcd_data.buttons_redge & BTN_BACK) {
      sd_data.stateProcessFile    =  0xFF;
    } else if (lcd_data.buttons_redge & BTN_ROTARY_LEFT) {
      lcd_data.cursor_id          =  0;             // ... select no   
      sd_data.stateProcessFile    =  2;
    } else if (lcd_data.buttons_redge & BTN_ROTARY_RIGHT) {
      lcd_data.cursor_id          =  1;             // ... select yes  
      sd_data.stateProcessFile    =  2;
    } else if (lcd_data.buttons_redge & BTN_ROTARY_PUSH) {
        if (lcd_data.cursor_id == 1) {              // ... yes selected
          sd_data.stateProcessFile    =  4;
        } else {                                    // ... no selected  
          sd_data.stateProcessFile    =  0xFF;
        }
    }  
    lcd_data.buttons_redge        = 0;              // reset all edge indicators
    lcd_data.buttons_fedge        = 0; 
    return;
  } // if (sd_data.stateProcessFile == 3)

  if (sd_data.stateProcessFile == 4) {             // prepare the processing 
    sd_data.bytesProcessed      = 0;
    sd_data.lineBufferIndex     = 0;
    sd_data.isComment           = false;
    sd_data.stateProcessFile    = 5;
    return;
  } // if (sd_data.stateProcessFile == 4)
  
  if (sd_data.stateProcessFile == 5) {             // display progress 
    lcd.clearBuffer();
    lcd.setFont(u8g2_font_helvB08_tr);
    lcd.setCursor(  0,  8);  lcd.print(F("Process from SD-Card"));
    lcd.setFont(u8g2_font_helvR08_tr);
    lcd.setCursor(  6, 20);  lcd.print(sd_data.filename);
    lcd.drawRFrame( 6,  30, 116,   15,  2);         // ... draw progressbar
    float progress = (float)sd_data.bytesProcessed;
    progress *= 112;                                // width of progressbar
    progress /= (float)sd_data.fileSize;
    if (progress > 112)
      progress = 112;
    lcd.drawBox   ( 8,  32, (u8g2_uint_t)progress,   11);   
    lcd.sendBuffer(); 

    lcd_data.buttons_redge        = 0;              // ... reset all edge indicators
    lcd_data.buttons_fedge        = 0; 
    sd_data.stateProcessFile      = 6;
    sd_data.lineBufferIndex       = 0;     
    return;

  } // if (sd_data.stateProcessFile == 5)

  if (sd_data.stateProcessFile == 6) {              // processing
    sd_protocol_getline();                          // read the line (char by char!!!!
    return;
  }

  if (sd_data.stateProcessFile == 7) {            
    // line is available, send to gcode
    report_status_message(gc_execute_line(sd_data.lineBuffer)); 
    // continue 
    sd_data.stateProcessFile  = 5;
    return;
  } 

  if (sd_data.stateProcessFile == 8) {            
    // last line is available, send to gcode
    report_status_message(gc_execute_line(sd_data.lineBuffer)); 
    plan_synchronize();                                   // wait until all movements are done
    // finish
    sd_data.stateProcessFile  = 0xFD;
    return;
  } 
  if (sd_data.stateProcessFile == 9) {            
    // last line w/o gcode
    plan_synchronize();                                   // wait until all movements are done
    // finish
    sd_data.stateProcessFile  = 0xFD;
    return;
  } 
  
  

}
