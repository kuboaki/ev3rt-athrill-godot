#include "app.h"
#include "util.h"
#include "timer.h" // <1>
#include "horn.h"  // <2>

const int carrier_sensor = EV3_PORT_2;

int carrier_cargo_is_loaded(void) {
  return ev3_touch_sensor_is_pressed(carrier_sensor);
}

const int walldetector_sensor = EV3_PORT_4;
#define WD_DISTANCE 10
int wd_distance = WD_DISTANCE;

int wall_detector_is_detected(void) {
  return ev3_ultrasonic_sensor_get_distance(walldetector_sensor)
    < wd_distance;
}

const int bumper_sensor = EV3_PORT_1;

int bumper_is_pushed(void) {
  return ev3_touch_sensor_is_pressed(bumper_sensor);
}

const int linemon_sensor = EV3_PORT_3;
#define LM_THRESHOLD 20
int lm_threshold = LM_THRESHOLD;

int linemon_is_online(void) {
  return ev3_color_sensor_get_reflect(linemon_sensor) < lm_threshold;
}

const int left_motor = EV3_PORT_A;
const int right_motor = EV3_PORT_C;
#define DR_POWER 20
int dr_power = DR_POWER;

void driver_turn_left(void) {
  ev3_motor_set_power(EV3_PORT_A, 0);
  ev3_motor_set_power(EV3_PORT_C, dr_power);
}

void driver_turn_right(void) {
  ev3_motor_set_power(EV3_PORT_A, dr_power);
  ev3_motor_set_power(EV3_PORT_C, 0);
}

void driver_stop(void) {
  ev3_motor_stop(left_motor, false);
  ev3_motor_stop(right_motor, false);
}

void tracer_run(void) {
  if( linemon_is_online() ) {
    driver_turn_left();
  } else {
    driver_turn_right();
  }
}

void tracer_stop(void) {
  driver_stop();
}

void porter_init(void) {
  init_f("sample04-01");
  ev3_motor_config(left_motor, LARGE_MOTOR);
  ev3_motor_config(right_motor, LARGE_MOTOR);
  ev3_sensor_config(walldetector_sensor, ULTRASONIC_SENSOR);
  dly_tsk(5000U * 1000U);
  ev3_sensor_config(linemon_sensor, COLOR_SENSOR);
  ev3_sensor_config(bumper_sensor, TOUCH_SENSOR);
  ev3_sensor_config(carrier_sensor, TOUCH_SENSOR);
}

typedef enum {
  P_INIT, P_WAIT_FOR_LOADING, P_TRANSPORTING,
  P_TIMEDOUT, P_CARGO_SHIFTING,
  P_WAIT_FOR_UNLOADING, P_RETURNING, P_ARRIVED
} porter_state;

static const char *const p_state_name[] = {
  "P_INIT",
  "P_WAIT_FOR_LOADING",
  "P_TRANSPORTING",
  "P_TIMEDOUT",
  "P_CARGO_SHIFTING",
  "P_WAIT_FOR_UNLOADING",
  "P_RETURNING",
  "P_ARRIVED"
};

porter_state p_state = P_INIT;

int p_entry = true;

void porter_transport(void) {
  msg_f(p_state_name[p_state], 2);
  switch(p_state) {
  /* Porting fix: the original exercise source omitted P_INIT handling. */
  case P_INIT:
    if( p_entry ) {
      p_entry = false;
      porter_init();
    }
    p_state = P_WAIT_FOR_LOADING;
    p_entry = true;
    break;
  case P_WAIT_FOR_LOADING:
    if( p_entry ) {
      p_entry = false;
      timer_start( 10000 * 1000 );
    }
    if( carrier_cargo_is_loaded() ) {
      p_state = P_TRANSPORTING;
      p_entry = true;
    }
    if( timer_is_timedout() ) {
      p_state = P_TIMEDOUT;
      p_entry = true;
    }
    if( p_entry ) {
      timer_stop();
    }
    break;
  case P_TIMEDOUT:
    if( p_entry ) {
      p_entry = false;
      horn_confirmation();
    }
    if( true ) {
      p_state = P_WAIT_FOR_LOADING;
      p_entry = true;
    }
    if( p_entry ) {
      // exit
    }
    break;
  case P_TRANSPORTING:
    if( p_entry ) {
      p_entry = false;
    }
    tracer_run();
    if( wall_detector_is_detected() ) {
      p_state = P_WAIT_FOR_UNLOADING;
      p_entry = true;
    }
    if(! carrier_cargo_is_loaded() ) {
      p_state = P_CARGO_SHIFTING;
      p_entry = true;
    }
    if( p_entry ) {
      tracer_stop();
    }
    break;
  case P_CARGO_SHIFTING:
    if( p_entry ) {
      p_entry = false;
      horn_warning();
      timer_start( 5000 * 1000 );
    }
    if( carrier_cargo_is_loaded() ) {
      p_state = P_TRANSPORTING;
      p_entry = true;
    }
    if( timer_is_timedout() ) {
      p_state = P_CARGO_SHIFTING;
      p_entry = true;
    }
    if( p_entry ) {
      timer_stop();
    }
    break;
  case P_WAIT_FOR_UNLOADING:
    if( p_entry ) {
      p_entry = false;
      horn_arrived();
    }
    if(! carrier_cargo_is_loaded() ) {
      p_state = P_RETURNING;
      p_entry = true;
    }
    // do
    if( p_entry ) {
      // exit
    }
    break;
  case P_RETURNING:
    if( p_entry ) {
      p_entry = false;
    }
    tracer_run();
    if( bumper_is_pushed() ) {
      p_state = P_ARRIVED;
      p_entry = true;
    }
    if( p_entry ) {
      tracer_stop();
    }
    break;
  case P_ARRIVED:
    if( p_entry ) {
      p_entry = false;
      horn_arrived();
    }
    break;
  default:
    break;
  }
}

void main_task(intptr_t unused) {
  porter_transport();
  ext_tsk();
}
