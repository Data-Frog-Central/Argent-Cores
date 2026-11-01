#ifndef __FRONTEND_FUNCTIONS_H
#define __FRONTEND_FUNCTIONS_H

#include <stdint.h>

extern int (*xlog)(const char *, ...);
extern uint32_t get_time_ms(void);

#endif
