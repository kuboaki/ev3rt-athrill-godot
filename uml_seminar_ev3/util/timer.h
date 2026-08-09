#ifndef MY_TIMER_H_
#define MY_TIMER_H_

#include "ev3api.h"
#include "stdbool.h"

extern void timer_start(int delay_ms);
extern void timer_stop(void);
extern bool timer_is_started(void);
extern bool timer_is_timedout(void);

#endif  // MY_TIMER_H_
