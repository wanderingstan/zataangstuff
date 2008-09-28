#import <Foundation/Foundation.h>

int vibratecallback(void *connection, CFStringRef string, CFDictionaryRef dictionary, void *data) {
    return 1;
}

extern void * _CTServerConnectionCreate(CFAllocatorRef, int (*)(void *, CFStringRef, CFDictionaryRef, void *), int *);
extern int _CTServerConnectionSetVibratorState(int *, void *, int, int, float, float, float);

int main (int argc, char *argv[]) {
    int x;
    void *connection = _CTServerConnectionCreate(kCFAllocatorDefault, &vibratecallback, &x);
    _CTServerConnectionSetVibratorState(&x, connection, 0, 0, 0, 0, 0);
    return 0;
}
