#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>

static BOOL writeWindow(CGWindowID windowID, NSString *path) {
    CGImageRef image = CGWindowListCreateImage(
        CGRectNull,
        kCGWindowListOptionIncludingWindow,
        windowID,
        kCGWindowImageBoundsIgnoreFraming | kCGWindowImageBestResolution
    );
    if (!image) return NO;
    NSURL *url = [NSURL fileURLWithPath:path];
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL(
        (__bridge CFURLRef)url,
        CFSTR("public.png"),
        1,
        NULL
    );
    BOOL result = NO;
    if (destination) {
        CGImageDestinationAddImage(destination, image, NULL);
        result = CGImageDestinationFinalize(destination);
        CFRelease(destination);
    }
    CGImageRelease(image);
    return result;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) return 2;
        NSString *outputDirectory = [NSString stringWithUTF8String:argv[1]];
        NSArray *windows = CFBridgingRelease(CGWindowListCopyWindowInfo(
            kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements,
            kCGNullWindowID
        ));
        CGRect spacer = CGRectNull;
        for (NSDictionary *window in windows) {
            NSString *name = window[(id)kCGWindowName] ?: @"";
            if (![name hasPrefix:@"VibeIslandMenuSpacer.ConditionalSlot."]) continue;
            CGRectMakeWithDictionaryRepresentation(
                (__bridge CFDictionaryRef)window[(id)kCGWindowBounds],
                &spacer
            );
            break;
        }
        if (CGRectIsNull(spacer)) return 0;

        NSMutableArray *candidates = [NSMutableArray array];
        for (NSDictionary *window in windows) {
            if ([window[(id)kCGWindowLayer] intValue] != 25) continue;
            CGRect frame = CGRectNull;
            CGRectMakeWithDictionaryRepresentation(
                (__bridge CFDictionaryRef)window[(id)kCGWindowBounds],
                &frame
            );
            if (CGRectGetMaxX(frame) <= spacer.origin.x + 2) {
                [candidates addObject:window];
            }
        }
        [candidates sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            CGRect left = CGRectNull, right = CGRectNull;
            CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)a[(id)kCGWindowBounds], &left);
            CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)b[(id)kCGWindowBounds], &right);
            return left.origin.x < right.origin.x ? NSOrderedAscending : NSOrderedDescending;
        }];
        if (candidates.count < 2) return 0;
        NSArray *selected = [candidates subarrayWithRange:NSMakeRange(candidates.count - 2, 2)];
        for (NSUInteger index = 0; index < selected.count; index++) {
            CGWindowID windowID = [selected[index][(id)kCGWindowNumber] unsignedIntValue];
            NSString *path = [outputDirectory stringByAppendingPathComponent:
                [NSString stringWithFormat:@"right-icon-%lu.png", index + 1]
            ];
            if (!writeWindow(windowID, path)) return 3;
        }
    }
    return 0;
}
