//
//  TBMovieClip+Data.m
//

#import "TBMovieClip+Data.h"
#import "TBAnimData.h"

@implementation TBMovieClip (Data)

- (BOOL)loadTableNamed:(NSString *)className
{
    const TBAnimTable *t = TBAnimTableForClass(className.UTF8String);
    if (!t) {
        NSLog(@"[TB] animation table not found: %@", className);
        return NO;
    }

    self.width  = t->width;
    self.height = t->height;
    self.anchorX = t->anchorX;
    self.anchorY = t->anchorY;
    self.totalFrames = t->totalFrames;

    NSMutableArray<NSString *> *clips = [NSMutableArray arrayWithCapacity:t->clipCount];
    for (int i = 0; i < t->clipCount; i++) {
        const char *s = t->clipNames[i];
        [clips addObject:(s ? @(s) : @"")];
    }
    self.clipNameList = clips;

    NSMutableArray<NSNumber *> *ax = [NSMutableArray arrayWithCapacity:t->clipCount];
    NSMutableArray<NSNumber *> *ay = [NSMutableArray arrayWithCapacity:t->clipCount];
    for (int i = 0; i < t->clipCount; i++) {
        [ax addObject:@(t->anchorXs[i])];
        [ay addObject:@(t->anchorYs[i])];
    }
    self.clipAnchorX = ax;
    self.clipAnchorY = ay;

    if (t->labelCount > 0 && t->labelNames && t->labelFrames) {
        NSMutableArray<NSString *> *ln = [NSMutableArray arrayWithCapacity:t->labelCount];
        NSMutableArray<NSNumber *> *lf = [NSMutableArray arrayWithCapacity:t->labelCount];
        for (int i = 0; i < t->labelCount; i++) {
            const char *s = t->labelNames[i];
            [ln addObject:(s ? @(s) : @"")];
            [lf addObject:@(t->labelFrames[i])];
        }
        self.labelNameList = ln;
        self.labelFrameList = lf;
    } else {
        self.labelNameList = @[];
        self.labelFrameList = @[];
    }

    // 帧变换表交给内部使用（每帧每 clip 一条）
    self.frameTable = t->xforms;
    self.frameClipCount = t->clipCount;

    return YES;
}

@end
