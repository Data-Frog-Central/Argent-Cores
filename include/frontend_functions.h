#ifndef __FRONTEND_FUNCTIONS_H
#define __FRONTEND_FUNCTIONS_H

#include <stdint.h>

void xlog(const char *fmt, ...);
#define XLOG(format, ...) xlog("%s:%d:%s " format, __FILE__, __LINE__, __func__, ##__VA_ARGS__)

extern uint32_t get_time_ms(void);

#endif
