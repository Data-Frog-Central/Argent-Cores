/*
    Shim for SF2000 stuff that tries to use stockfw.h and functions from stockfw.h
*/

#ifndef __STOCKFW_H
#define __STOCKFW_H

#include <frontend_functions.h>

#define os_get_tick_count() get_time_ms()

#endif // __STOCKFW_H