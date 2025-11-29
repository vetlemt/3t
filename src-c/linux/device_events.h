#ifndef DEVICE_EVENTS_H
#define DEVICE_EVENTS_H

#include <linux/input.h>  // For struct input_event and key codes

enum InputDevice {
    INPUT_KBD,
    INPUT_MOUSE
};

int evdev_open(const char* path);
int evdev_read(int fd, struct input_event* ev);
void evdev_close(int fd);

void find_device_path(char* path, enum InputDevice dev);
#endif
