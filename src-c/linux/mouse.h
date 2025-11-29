#ifndef EVDEV_H
#define EVDEV_H

#include <linux/input.h>  // For struct input_event and key codes

int evdev_open(const char* path);
int evdev_read(int fd, struct input_event* ev);
void evdev_close(int fd);

#endif
