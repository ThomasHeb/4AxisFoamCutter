#ifndef planner_h
#define planner_h

/// 8c1
#include "config.h"    // BLOCK_BUFFER_SIZE

// The number of linear motions that can be in the plan at any give time
#ifndef BLOCK_BUFFER_SIZE
  #error
#endif
/// 8c1
#define C_ARC 1
#define C_LINE 0

// This struct is used when buffering the setup for each linear movement "nominal" values are as specified in
// the source g-code and may never actually be reached if acceleration management is active.
typedef struct {

  // Fields used by the bresenham algorithm for tracing the line
  uint8_t  direction_bits;            // The direction bit set for this block (refers to *_DIRECTION_BIT in config.h)
/// 8c1
  uint32_t steps_x, steps_y, steps_z, steps_u; // Step count along each axis
/// 8c0 int32_t -> uint32_t
  uint32_t  step_event_count;          // The number of step events required to complete this block

  // Fields used by the motion planner to manage acceleration
  float nominal_speed;               // The nominal speed for this block in mm/min
  float entry_speed;                 // Entry speed at previous-current block junction in mm/min
  float max_entry_speed;             // Maximum allowable junction entry speed in mm/min
  float millimeters;                 // The total travel of this block in mm
  uint8_t recalculate_flag;           // Planner flag to recalculate trapezoids on entry junction
  uint8_t nominal_length_flag;        // Planner flag for nominal speed always reached

  // Settings for the trapezoid generator
  uint32_t initial_rate;              // The step rate at start of block
  uint32_t final_rate;                // The step rate at end of block
  int32_t rate_delta;                 // The steps/minute to add or subtract when changing speed (must be positive)
  uint32_t accelerate_until;          // The index of the step event on which to stop acceleration
  uint32_t decelerate_after;          // The index of the step event on which to start decelerating
  uint32_t nominal_rate;              // The nominal step rate for this block in step_events/minute

} block_t;

// Initialize the motion plan subsystem
void plan_init();

// Add a new linear movement to the buffer. x, y, u and z is the signed, absolute target position in
// millimaters. Feed rate specifies the speed of the motion. If feed rate is inverted, the feed
// rate is taken to mean "frequency" and would complete the operation in 1/feed_rate minutes.
/// 8c1
void plan_buffer_line(float x, float y, float u, float z, float feed_rate, uint8_t invert_feed_rate, uint8_t t_arc);

// Called when the current block is no longer needed. Discards the block and makes the memory
// availible for new blocks.
void plan_discard_current_block();

// Gets the current block. Returns NULL if buffer empty
block_t *plan_get_current_block();

// Reset the planner position vector (in steps)
/// 8c1
void plan_set_current_position(int32_t x, int32_t y, int32_t u, int32_t z);

// Reinitialize plan with a partially completed block
void plan_cycle_reinitialize(int32_t step_events_remaining);

// Reset buffer
void plan_reset_buffer();

// Returns the status of the block ring buffer. True, if buffer is full.
uint8_t plan_check_full_buffer();

// Block until all buffered steps are executed
void plan_synchronize();

#endif
