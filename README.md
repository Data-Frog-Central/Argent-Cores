# DartOS Core Builder
**This is used by DartOS but isn't necessarily DartOS specific**  

This core builder (mostly the json file format) is inspired by the core builder muOS uses. This uses shell script patches in an attempt to mitigate patch file issues. The overall core_api is based on Multicore for SF2000 and GB300.  

These cores are statically compiled with wrapper functions so DartOS can run these cores using the api defined in core_api.h. The frontend passes functions needed for libc and other helper functions when it runs the entry point and core_api returns the retro_header_t struct which contains a magic number and version number for identification along with a retro_core_t struct containing all the libretro functions for the frontend to call.
