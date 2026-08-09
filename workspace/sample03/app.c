#include "app.h"
#include "util.h"

const int touch_sensor = EV3_PORT_1;
const int color_sensor = EV3_PORT_3;
const int left_motor = EV3_PORT_A;
const int right_motor = EV3_PORT_C;

#define DR_POWER 20
int dr_power = DR_POWER;

void driver_turn_left(void) {
  ev3_motor_set_power(left_motor, 0);
  ev3_motor_set_power(right_motor, dr_power);
}

void driver_turn_right(void) {
  ev3_motor_set_power(left_motor, dr_power);
  ev3_motor_set_power(right_motor, 0);
}

void driver_init(void) {
  ev3_motor_config(left_motor, LARGE_MOTOR);
  ev3_motor_config(right_motor, LARGE_MOTOR);
}

void driver_stop(void) {
  ev3_motor_stop(left_motor, false);
  ev3_motor_stop(right_motor, false);
}

#define LM_THRESHOLD 20
int lm_threshold = LM_THRESHOLD;

void linemon_init(void) {
  ev3_sensor_config(color_sensor, COLOR_SENSOR);
}

int linemon_is_online(void) {
  return( ev3_color_sensor_get_reflect(color_sensor)
    < lm_threshold );
}

void bumper_init(void) {
  ev3_sensor_config(touch_sensor, TOUCH_SENSOR);
}

int bumper_is_pushed(void) {
  return ev3_touch_sensor_is_pressed(touch_sensor);
}

void tracer_init(void) {
  linemon_init();
  driver_init();
}

void tracer_stop(void) {
  driver_stop();
}

void tracer_run(void) {
  if( linemon_is_online() ) {
    driver_turn_left();
  } else {
    driver_turn_right();
  }
}

enum { TRANSPORTING, ARRIVED };
int current_state = TRANSPORTING;

void porter_init(void) {
  tracer_init();
  bumper_init();
}

void porter_transport(void) {
  switch(current_state) {
  case TRANSPORTING:
    tracer_run();
    if (bumper_is_pushed()) {
      current_state = ARRIVED;
    }
    break;
  case ARRIVED:
    tracer_stop();
    break;
  }
}

void main_task(intptr_t unused) {
  static int is_initialized = false;
  if(! is_initialized ) {
    is_initialized = true;
    init_f("sample03");
    porter_init();
  }

  porter_transport();

  ext_tsk();
}
