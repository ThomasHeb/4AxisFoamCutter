#ifndef motion_control_h
#define motion_control_h

#include <avr/io.h>
#include "planner.h"

// Execute linear motion in absolute millimeter coordinates. Feed rate given in millimeters/second
// unless invert_feed_rate is true. Then the feed_rate means that the motion should be completed in
// (1 minute)/feed_rate time.
/// 8c1
void mc_line(float x, float y, float u, float z, float feed_rate, uint8_t invert_feed_rate, uint8_t t_curve);

// Execute an arc in offset mode format. position == current xyz, target == target xyz,
// offset == offset from current xyz, axis_XXX defines circle plane in tool space, axis_linear is
// the direction of helical travel, radius == circle radius, isclockwise boolean. Used
// for vector transformation direction.
void mc_arc(float *position, float *target, float *offset, uint8_t axis_0, uint8_t axis_1,
  uint8_t axis_linear, float feed_rate, uint8_t invert_feed_rate, float radius, uint8_t isclockwise);

// Dwell for a specific number of seconds
void mc_dwell(float seconds);

// Perform homing cycle to locate machine zero. Requires limit switches.
void mc_go_home();

// Performs system reset. If in motion state, kills all motion and sets system alarm.
void mc_reset();

#endif
