#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

void FigVibratorPlayVibrationWithDictionary(CFDictionaryRef dict);
void FigVibratorStartOneShot(int, int, int, int);
int main(){
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    /*
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithFloat:1.0], @"Intensity",
        [NSNumber numberWithFloat:0.1], @"OffDuration",
        [NSNumber numberWithFloat:0.3], @"OnDuration",
        [NSNumber numberWithFloat:0.4], @"TotalDuration",
        nil];
        */

    CFStringRef keys [4];
    keys [0] = CFSTR("Intensity");
    keys [1] = CFSTR("OffDuration");
    keys [2] = CFSTR("OnDuration");
    keys [3] = CFSTR("TotalDuration");

    CFNumberRef values [4];
    float intensity = 1.0;
    float offDuration = 0.1;
    float onDuration = 0.3;
    float totalDuration = 0.4;

    values [0] = CFNumberCreate (kCFAllocatorDefault, kCFNumberFloatType, &intensity);
    values [1] = CFNumberCreate (kCFAllocatorDefault, kCFNumberFloatType, &offDuration);
    values [2] = CFNumberCreate (kCFAllocatorDefault, kCFNumberFloatType, &onDuration);
    values [3] = CFNumberCreate (kCFAllocatorDefault, kCFNumberFloatType, &totalDuration);

    CFDictionaryRef dict = CFDictionaryCreate (kCFAllocatorDefault, (void *) keys, (void *) values, 4, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    FigVibratorPlayVibrationWithDictionary (dict);

    [pool release];
    return 0;
}

