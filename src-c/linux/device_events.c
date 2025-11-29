#include "device_events.h"
#include <fcntl.h>    // For open
#include <unistd.h>   // For read, close
#include <errno.h>    // For error handling

#include <dirent.h>
#include <string.h>  // For strcmp

#define INPUT_DEVICE_DIR "/dev/input/by-id/"
#define MOUSE_DEVICE_SUFFIX "-event-mouse"
#define KEYBOARD_DEVICE_SUFFIX "-event-kbd"

int evdev_open(const char* path) {
    int fd = open(path, O_RDONLY | O_NONBLOCK);
    if (fd < 0) {
        return -1;  // Error
    }
    return fd;
}

int evdev_read(int fd, struct input_event* ev) {
    ssize_t bytes = read(fd, ev, sizeof(struct input_event));
    if (bytes < 0) {
        if (errno == EAGAIN || errno == EWOULDBLOCK) {
            return 0;  // No event available
        }
        return -1;  // Error
    }
    if (bytes != sizeof(struct input_event)) {
        return -1;  // Incomplete read
    }
    return 1;  // Success
}

void evdev_close(int fd) {
    close(fd);
}

int ends_with(const char *str, const char *suffix) {
    if (str == NULL || suffix == NULL) return 0;

    size_t str_len = strlen(str);
    size_t suffix_len = strlen(suffix);
    if (suffix_len > str_len) return 0;

    return strcmp(str + (str_len - suffix_len), suffix) == 0;
}

void find_device_path(char* path, enum InputDevice dev){
    DIR *dir;
    struct dirent *entry;

    dir = opendir(INPUT_DEVICE_DIR);
    if (dir == NULL) {  return; }

    const char* suffix = (dev == INPUT_MOUSE) ? MOUSE_DEVICE_SUFFIX : KEYBOARD_DEVICE_SUFFIX;

    while ((entry = readdir(dir)) != NULL) {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) continue;

        if (ends_with(entry->d_name, suffix)){
            strcpy(path, entry->d_name);
            break;
        }
    }
    closedir(dir);
}
