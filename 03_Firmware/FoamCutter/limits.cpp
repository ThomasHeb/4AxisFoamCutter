#include <util/delay.h>
#include <avr/io.h>
#include <avr/interrupt.h>
#include "stepper.h"
#include "settings.h"
#include "nuts_bolts.h"
#include "config.h"
#include "motion_control.h"
#include "planner.h"
#include "protocol.h"
#include "limits.h"
#include "report.h"
#include "ramps.h"
#include <SPI.h>
#include "print.h"
/// 8c1
#include "gcode.h"     /// to_degrees()
#include "defaults.h" 

#define MICROSECONDS_PER_ACCELERATION_TICK  (1000000/ACCELERATION_TICKS_PER_SECOND)


void estopp_disable()
{
  // e-stopp interrupt: PCINT17
  PCMSK2  &=  ~(1 << PCINT17);      // disable Interrupt PCINT17
  PCICR   &=  ~(1 << PCIE2);        // disable Interrupt (PCIe2: PCINT24...16)
  PCIFR   &=  ~(1 << PCIF2);        // clear pending Interrupts (PCIF2: PCINT24...16)
}
void estopp_enable()
{
  // e-stopp interrupt: PCINT17
  PCMSK2  |=   (1 << PCINT17);      // enable Interrupt PCINT17
  PCIFR   &=  ~(1 << PCIF2);        // clear pending Interrupts (PCIF2: PCINT24...16)
  PCICR   |=   (1 << PCIE2);        // enable Interrupt (PCIe2: PCINT24...16)
}

void limits_init()
{
  
#ifdef FOAM_CUTTER
  // setup pins with pull-up
  pinMode(PIN_LIMIT_X, INPUT_PULLUP); // D3  = INT5
  pinMode(PIN_LIMIT_Y, INPUT_PULLUP); // D2  = INT4
  pinMode(PIN_LIMIT_U, INPUT_PULLUP); // D14 = PCINT10
  pinMode(PIN_LIMIT_Z, INPUT_PULLUP); // D15 = PCINT9

  #if (USE_BUTTONS == 1)
  pinMode(PIN_BTN_STOP,INPUT_PULLUP); // D63 = PCINT17
  estopp_enable();
  #endif
#endif
#ifdef LASER_CUTTER
  // setup pins with pull-up
  pinMode(PIN_LIMIT_X, INPUT_PULLUP); // D3  = INT5
  pinMode(PIN_LIMIT_Y, INPUT_PULLUP); // D2  = INT4

  pinMode(PIN_BTN_STOP,INPUT_PULLUP); // D63 = PCINT17
  estopp_enable();
#endif

  if (bit_istrue(settings.flags,BITFLAG_HARD_LIMIT_ENABLE)) {
    limits_enable();
  } else {
    limits_disable();
  }

#ifdef LIMITS_SW_DEBOUNCE
  MCUSR   &= ~(1<<WDRF);      // clear pending wdg irq
  WDTCSR  &= ~(1<<WDIF);      // clear pending wdg irq
  WDTCSR  |= ((1<<WDCE) | (1<<WDE));
  WDTCSR  =  (1<<WDP0);       // Set time-out at ~32msec

#endif
}

// Disables hard limits.
void limits_disable()
{
  // U andy Z Axis: PCINT10 and PCINT9
  PCMSK1        &=  ~((1 << PCINT9) | (1 << PCINT10));                 
                                          // disable Change IRQ for Limit Switches (PCINT10 and PCINT9)
  PCIFR         &=  ~(1 << PCIF1);        // clear pending Interrupts (PCIF2: PCINT15...8)
  
  
  PCMSK1        &=  0xF9;                 // Disable Change IRQ for Limit Switchesn (PCINT10 and PCINT9)
  PCIFR         &=  0xFD;                 // clear pending Interrupts
   
  // X andy Y Axis: INT4 and INT5
  EIMSK         &=  ~((1 << INT4) | (1 << INT5));                 
                                          // disable Interrupt for INT4 & INT5
  EIFR          &=  ~((1 << INTF4) | (1 << INTF5));
                                          // clear pending Interrupt               
 
}
void limits_enable()
{
#ifdef FOAM_CUTTER
  // U andy Z Axis: PCINT10 and PCINT9
  PCMSK1        |=  ((1 << PCINT9) | (1 << PCINT10));                 
                                          // Enable Change IRQ for Limit Switches (PCINT10 and PCINT9)
  PCIFR         &=  ~(1 << PCIF1);        // clear pending Interrupts (PCIF2: PCINT15...8)
  PCICR         |=  (1 << PCIE1);         // Enable Pin Change Interrupt (PCIE2: PCINT15...8)

  // X andy Y Axis: IN5 and INT4
  EICRB         &=  ~((1 << ISC40) | (1 << ISC41) | (1 << ISC50) | (1 << ISC51));
  EICRB         |=  ((1 << ISC40) | (1 << ISC41) | (1 << ISC50) | (1 << ISC51));                 
                                          // Rising Edge of Limit switches 
                                          // Falling Edge of Limit switches 
  EIFR          &=  ~((1 << INTF4) | (1 << INTF5));               
                                          // clear pending Interrupts
  EIMSK         |=  ((1 << INT4) | (1 << INT5));                 
                                          // enable Interrupt for INT4 & INT5
#endif
#ifdef LASER_CUTTER
  // X andy Y Axis: INT5 and INT4
  EICRB         &=  ~((1 << ISC40) | (1 << ISC41) | (1 << ISC50) | (1 << ISC51));
  EICRB         |=  ((1 << ISC40) | (1 << ISC41) | (1 << ISC50) | (1 << ISC51));                 
                                          // Rising Edge of Limit switches 
  EIFR          &=  ~((1 << INTF4) | (1 << INTF5));               
                                          // clear pending Interrupts
  EIMSK         |=  ((1 << INT4) | (1 << INT5));                 
                                          // enable Interrupt for INT4 & INT5
#endif
}

#ifdef LIMITS_SW_DEBOUNCE
void limits_get_state()
{
  uint8_t limit_state = 0;
  uint8_t limit_prev_state = 0;
  
  uint16_t readCount;
  uint16_t readTotal;

  readCount = 0;
  sys.err = ERR_NO;     // reset the Error
  
  for (readTotal = 0; readTotal <500; readTotal++) {
    limit_state = 0;
    delay_us(10);
    // Get limit pin state.
#ifdef FOAM_CUTTER
    if (digitalRead(PIN_LIMIT_X) == HIGH)
      limit_state |= (1<<X_AXIS);
    if (digitalRead(PIN_LIMIT_Y) == HIGH)
      limit_state |= (1 << Y_AXIS);
    if (digitalRead(PIN_LIMIT_U) == HIGH)
      limit_state |= (1<<U_AXIS);
    if (digitalRead(PIN_LIMIT_Z) == HIGH)
      limit_state |= (1 << Z_AXIS);
    if (digitalRead(PIN_BTN_STOP) == LOW)
      limit_state |= (1 << 7);
#endif
#ifdef LASER_CUTTER
   if (digitalRead(PIN_LIMIT_X) == HIGH)
      limit_state |= (1<<X_AXIS);
   if (digitalRead(PIN_LIMIT_Y) == HIGH)
      limit_state |= (1 << Y_AXIS);
    if (digitalRead(PIN_BTN_STOP) == LOW)
      limit_state |= (1 << 7);
#endif
    if (limit_prev_state == limit_state) {
      readCount++;
      if (readCount == 50) {
        // Check for error reason and set sys.err according
        if (limit_state & (1<<X_AXIS)) {
          sys.err = ERR_XAXIS;
        }
        else if (limit_state & (1<<Y_AXIS)) {
          sys.err = ERR_YAXIS;
        }
        else if (limit_state & (1<<U_AXIS)) {
          sys.err = ERR_UAXIS;
        }
        else if (limit_state & (1<<Z_AXIS)) {
          sys.err = ERR_ZAXIS;
        }
        else if (limit_state & (1<<4)) {
          sys.err = ERR_XYAXIS;
        }
        else if (limit_state & (1<<5)) {
          sys.err = ERR_UZAXIS;
        }
        else if (limit_state & (1<<6)) {
          sys.err = ERR_UZAXIS;
        }
        else if (limit_state & (1<<7)) {
          sys.err = ERR_ESTOPP;
        }
        else if (limit_state == 0) {
          sys.err = ERR_NO;
        }
        else {
          sys.err = ERR_UNDEFINED;
        }
        
        return;
      }
    } else {
      limit_prev_state = limit_state;
      readCount = 0;
    }
  }

 
  // wenn nach X x Lesen kein eindeutiges Signal vorliegt, dann ist das Limit verletzt // Fehler liegt vor
  sys.err = ERR_BOUNCE;
}
#endif


#ifdef LIMITS_SW_DEBOUNCE
void limits_isr() {       
  if (!(WDTCSR & (1<<WDIE))) { 
    WDTCSR |= (1<<WDIE);        // Aktiviere den wdg timer
  } 
}
#endif

#ifdef LIMITS_SW_DEBOUNCE
ISR(WDT_vect) {         // Watchdog timer ISR
  WDTCSR &= ~(1<<WDIE); // Disable watchdog timer.
#else
void limits_isr() {
#endif

  if (sys.state != STATE_ALARM) {
    if (bit_isfalse(sys.execute,EXEC_ALARM)) {
      
#ifdef LIMITS_SW_DEBOUNCE
      limits_get_state();                   // Debounce the Limit switches
      if (sys.err != ERR_NO) {              // check still an error is pending
#endif
        mc_reset();                         // Initiate system kill.
        sys.execute |= EXEC_CRIT_EVENT;     // Indicate hard limit critical event
#ifdef LIMITS_SW_DEBOUNCE
      }
      else {
       MCUSR   &= ~(1<<WDRF);      // clear pending wdg irq
       WDTCSR  &= ~(1<<WDIF);      // clear pending wdg irq
       WDTCSR  |= ((1<<WDCE) | (1<<WDE));
       WDTCSR  =  (1<<WDP0);       // Set time-out at ~32msec
      }
#endif
    }
  }
  
  if (bit_istrue(settings.flags,BITFLAG_HARD_LIMIT_ENABLE)) {
    limits_enable();
  } else {
    limits_disable();
  }
  estopp_enable();
}

ISR(PCINT2_vect) {
  estopp_disable(); 
  limits_disable();
  sys.err = ERR_ESTOPP;
  limits_isr();             // e-stopp isr
}

ISR(PCINT1_vect) {
  estopp_disable(); 
  limits_disable();         // U/Z isr
  sys.err = ERR_UZAXIS;
  limits_isr();
}

ISR(INT5_vect) {
  estopp_disable(); 
  limits_disable();         // X isr
  sys.err = ERR_XAXIS;
  limits_isr();
}

ISR(INT4_vect) {
  estopp_disable(); 
  limits_disable();         // y isr
  sys.err = ERR_YAXIS;
  limits_isr(); 
}

// Moves all specified axes in same specified direction (positive=true, negative=false)
// and at the homing rate. Homing is a special motion case, where there is only an
// acceleration followed by abrupt asynchronous stops by each axes reaching their limit
// switch independently. Instead of shoehorning homing cycles into the main stepper
// algorithm and overcomplicate things, a stripped-down, lite version of the stepper
// algorithm is written here. This also lets users hack and tune this code freely for
// their own particular needs without affecting the rest of Grbl.
// NOTE: Only the abort runtime command can interrupt this process.
static void homing_cycle(uint8_t cycle_mask, int8_t pos_dir, bool invert_pin, float homing_rate)
{
   // Determine governing axes with finest step resolution per distance for the Bresenham
  // algorithm. This solves the issue when homing multiple axes that have different
  // resolutions without exceeding system acceleration setting. It doesn't have to be
  // perfect since homing locates machine zero, but should create for a more consistent
  // and speedy homing routine.
  // NOTE: For each axes enabled, the following calculations assume they physically move
  // an equal distance over each time step until they hit a limit switch, aka dogleg.
/// 8c0
  uint32_t steps[N_AXIS];
  uint8_t dist = 0;
  clear_vector(steps);
  if (cycle_mask & (1<<X_AXIS)) {
    dist++;
    steps[X_AXIS] = lround(settings.steps_per_mm[X_AXIS]);
  }
  if (cycle_mask & (1<<Y_AXIS)) {
    dist++;
    steps[Y_AXIS] = lround(settings.steps_per_mm[Y_AXIS]);
  }
  if (cycle_mask & (1<<Z_AXIS)) {
    dist++;
    steps[Z_AXIS] = lround(settings.steps_per_mm[Z_AXIS]);
  }
  if (cycle_mask & (1<<U_AXIS)) {
    dist++;
    steps[U_AXIS] = lround(settings.steps_per_mm[U_AXIS]);
  }

  uint32_t step_event_count = max(steps[X_AXIS], max(steps[Y_AXIS], max (steps[Z_AXIS], steps[U_AXIS])));

  // To ensure global acceleration is not exceeded, reduce the governing axes nominal rate
  // by adjusting the actual axes distance traveled per step. This is the same procedure
  // used in the main planner to account for distance traveled when moving multiple axes.
  // NOTE: When axis acceleration independence is installed, this will be updated to move
  // all axes at their maximum acceleration and rate.
  float ds = step_event_count/sqrt(dist);

  // Compute the adjusted step rate change with each acceleration tick. (in step/min/acceleration_tick)
  uint32_t delta_rate = ceil( ds*settings.acceleration/(60*ACCELERATION_TICKS_PER_SECOND));

  #ifdef HOMING_RATE_ADJUST
    // Adjust homing rate so a multiple axes moves all at the homing rate independently.
    homing_rate *= sqrt(dist); // Eq. only works if axes values are 1 or 0.
  #endif

  // Nominal and initial time increment per step. Nominal should always be greater then 3
  // usec, since they are based on the same parameters as the main stepper routine. Initial
  // is based on the MINIMUM_STEPS_PER_MINUTE config. Since homing feed can be very slow,
  // disable acceleration when rates are below MINIMUM_STEPS_PER_MINUTE.
  uint32_t dt_min = lround(1000000*60/(ds*homing_rate)); // Cruising (usec/step)
  uint32_t dt = 1000000*60/MINIMUM_STEPS_PER_MINUTE; // Initial (usec/step)
  if (dt > dt_min) { dt = dt_min; } // Disable acceleration for very slow rates.

  // Set default out_bits.
  uint8_t out_bits0 = settings.invert_mask;
  out_bits0 ^= (settings.homing_dir_mask & DIRECTION_MASK); // Apply homing direction settings
  if (!pos_dir) { out_bits0 ^= DIRECTION_MASK; }   // Invert bits, if negative dir.

  // Initialize stepping variables
  int32_t counter_x = -(step_event_count >> 1); // Bresenham counters
  int32_t counter_y = counter_x;
  int32_t counter_z = counter_x;
  int32_t counter_u = counter_x;
  uint32_t step_delay = dt-settings.pulse_microseconds;  // Step delay after pulse
  uint32_t step_rate = 0;  // Tracks step rate. Initialized from 0 rate. (in step/min)
  uint32_t trap_counter = MICROSECONDS_PER_ACCELERATION_TICK/2; // Acceleration trapezoid counter
  uint8_t out_bits;
  uint8_t limit_state, limit_prev_state;
  uint8_t readCount;

  rampsWriteDirections(out_bits0);
    
  for(;;) {

    // Reset out bits. Both direction and step pins appropriately inverted and set.
    out_bits = out_bits0;

    // Get limit pin state.
    limit_state         = 0;
    limit_prev_state    = 0;
    readCount           = 0;
    while (readCount < 10) {
      if (digitalRead(PIN_LIMIT_X) == LOW)
        limit_state |= (1<<X_AXIS);
      if (digitalRead(PIN_LIMIT_Y) == LOW)
        limit_state |= (1 << Y_AXIS);
#ifdef FOAM_CUTTER
      if (digitalRead(PIN_LIMIT_U) == LOW)
        limit_state |= (1<<U_AXIS);
      if (digitalRead(PIN_LIMIT_Z) == LOW)
        limit_state |= (1 << Z_AXIS);
#endif

      if (limit_state == limit_prev_state) {
        readCount++;
      } else {
        readCount = 0;
        limit_prev_state = limit_state;
      }
    }
    

    if (invert_pin) { limit_state ^= 0xFF; } // If leaving switch, invert to move.

    
    // Set step pins by Bresenham line algorithm. If limit switch reached, disable and
    // flag for completion.
    if (cycle_mask & (1<<X_AXIS)) {
      counter_x += steps[X_AXIS];
      if (counter_x > 0) {
        if (limit_state & (1<<X_AXIS)) { 
          out_bits ^= (1<<X_STEP_BIT);
        } else { 
          cycle_mask &= ~(1<<X_AXIS); 
        }
        counter_x -= step_event_count;
      }
    }
    if (cycle_mask & (1<<Y_AXIS)) {
      counter_y += steps[Y_AXIS];
      if (counter_y > 0) {
        if (limit_state & (1<<Y_AXIS)) { 
          out_bits ^= (1<<Y_STEP_BIT); 
        } else { 
          cycle_mask &= ~(1<<Y_AXIS); 
        }
        counter_y -= step_event_count;
      }
    }
    if (cycle_mask & (1<<Z_AXIS)) {
      counter_z += steps[Z_AXIS];
      if (counter_z > 0) {
        if (limit_state & (1<<Z_AXIS)) { 
          out_bits ^= (1<<Z_STEP_BIT); 
        } else { 
          cycle_mask &= ~(1<<Z_AXIS); 
        }
        counter_z -= step_event_count;
      }
    }
    if (cycle_mask & (1<<U_AXIS)) {
      counter_u += steps[U_AXIS] ;
      if (counter_u > 0) {
        if (limit_state & (1<<U_AXIS)) { 
          out_bits ^= (1<<U_STEP_BIT); 
        } else { 
          cycle_mask &= ~(1<<U_AXIS); 
        }
        counter_u -= step_event_count;
      }
    }

    // Check if we are done or for system abort
    if (!(cycle_mask) || (sys.execute & EXEC_RESET)) {
      return; }

    // Perform step.
    rampsWriteSteps(out_bits);
    delay_us(settings.pulse_microseconds);
    rampsWriteSteps(out_bits0);
    delay_us(step_delay);

    // Track and set the next step delay, if required. This routine uses another Bresenham
    // line algorithm to follow the constant acceleration line in the velocity and time
    // domain. This is a lite version of the same routine used in the main stepper program.
    if (dt > dt_min) { // Unless cruising, check for time update.
      trap_counter += dt; // Track time passed since last update.
      if (trap_counter > MICROSECONDS_PER_ACCELERATION_TICK) {
        trap_counter -= MICROSECONDS_PER_ACCELERATION_TICK;
        step_rate += delta_rate; // Increment velocity
        dt = (1000000*60)/step_rate; // Compute new time increment
        if (dt < dt_min) {dt = dt_min;}  // If target rate reached, cruise.
        step_delay = dt-settings.pulse_microseconds;
      }
    }
  }
}


void limits_go_home()
{
  // Enable only the steppers, not the cycle. Cycle should be inactive/complete.
  st_wake_up();

  // Search to engage all axes limit switches at faster homing seek rate.
   homing_cycle(HOMING_SEARCH_CYCLE_0, true, false, settings.homing_seek_rate);  // Search cycle 0
  #ifdef HOMING_SEARCH_CYCLE_1
    homing_cycle(HOMING_SEARCH_CYCLE_1, true, false, settings.homing_seek_rate);  // Search cycle 1
  #endif
  #ifdef HOMING_SEARCH_CYCLE_2
    homing_cycle(HOMING_SEARCH_CYCLE_2, true, false, settings.homing_seek_rate);  // Search cycle 2
  #endif
  delay_ms(settings.homing_debounce_delay); // Delay to debounce signal

  // Now in proximity of all limits. Carefully leave and approach switches in multiple cycles
  // to precisely hone in on the machine zero location. Moves at slower homing feed rate.
  int8_t n_cycle = N_HOMING_LOCATE_CYCLE;
  while (n_cycle--) {
    // Leave all switches to release them. After cycles complete, this is machine zero.
    homing_cycle(HOMING_LOCATE_CYCLE, false, true, settings.homing_feed_rate);
    delay_ms(settings.homing_debounce_delay);
    
    if (n_cycle > 0) {
      // Re-approach all switches to re-engage them.
      homing_cycle(HOMING_LOCATE_CYCLE, true, false, settings.homing_feed_rate);
      delay_ms(settings.homing_debounce_delay);
    }
  }

  st_go_idle(); // Call main stepper shutdown routine.
}
