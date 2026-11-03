//
//  TBBootContent.m
//

#import "TBBootContent.h"
#import "TBResolution.h"
#import "TBRootLayer.h"
#import "TBScene.h"
#import "TBAudio.h"

@implementation TBBootContent {
    CCDrawNode *_debugDraw;
    CCLabelTTF *_label;
    CCLabelTTF *_hint;
    int _tickCount;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        CGSize d = [TBResolution designSize];
        self.contentSize = d;
        self.anchorPoint = CGPointZero;

        // 画布边界（青色）
        _debugDraw = [CCDrawNode node];
        [self addChild:_debugDraw z:0];

        // 中心十字（洋红）
        // 安全区参考线（黄色）

        _label = [CCLabelTTF labelWithString:@"" fontName:@"Menlo" fontSize:9];
        _label.anchorPoint = CGPointMake(0, 1);
        _label.position = CGPointMake(6, d.height - 6);
        [self addChild:_label z:10];

        _hint = [CCLabelTTF labelWithString:@"Tappi Bear / arm64 port — P0 skeleton"
                                   fontName:@"Helvetica" fontSize:10];
        _hint.anchorPoint = CGPointMake(0.5, 0);
        _hint.position = CGPointMake(d.width * 0.5, 8);
        [self addChild:_hint z:10];

        [self redraw];

        // 试播一个音效，验证 AVAudioPlayer 通路。
        [[TBAudio sharedAudio] preloadEffect:@"coin.wav"];
    }
    return self;
}

- (void)onEnter
{
    [super onEnter];
    [self redraw];
    [self schedule:@selector(tick:) interval:1.0];
}

- (void)onExit
{
    [self unschedule:@selector(tick:)];
    [super onExit];
}

- (void)tick:(CCTime)dt
{
    (void)dt;
    _tickCount++;
    [self redraw];
    if (_tickCount == 2) {
        [[TBAudio sharedAudio] playEffect:@"coin.wav"];
    }
}

- (void)redraw
{
    [_debugDraw clear];
    CGSize d = self.contentSize;

    // 画布边框
    CCColor *cyan = [CCColor colorWithRed:0 green:1 blue:1 alpha:1];
    CGPoint bl = CGPointMake(0, 0), br = CGPointMake(d.width, 0);
    CGPoint tr = CGPointMake(d.width, d.height), tl = CGPointMake(0, d.height);
    const CGPoint quad[4] = {bl, br, tr, tl};
    [_debugDraw drawPolyWithVerts:quad count:4 fillColor:[CCColor clearColor]
                     borderWidth:1.0 borderColor:cyan];

    // 中心十字
    CCColor *magenta = [CCColor colorWithRed:1 green:0 blue:1 alpha:1];
    [_debugDraw drawSegmentFrom:CGPointMake(d.width * 0.5, 0)
                            to:CGPointMake(d.width * 0.5, d.height)
                         radius:0.5 color:magenta];
    [_debugDraw drawSegmentFrom:CGPointMake(0, d.height * 0.5)
                            to:CGPointMake(d.width, d.height * 0.5)
                         radius:0.5 color:magenta];

    // 安全区
    UIView *view = nil;
    id v = [CCDirector sharedDirector].view;
    if ([v isKindOfClass:[UIView class]]) view = (UIView *)v;
    TBSafeInsets in = [TBResolution safeInsetsForView:view];
    TBLayout L = [TBResolution layoutForView:view];

    CCColor *yellow = [CCColor colorWithRed:1 green:1 blue:0 alpha:1];
    if (L.scale > 0) {
        // 屏幕点 -> 设计坐标
        CGFloat top = d.height - (in.top / L.scale);
        CGFloat bottom = in.bottom / L.scale;
        CGFloat left = in.left / L.scale;
        CGFloat right = d.width - (in.right / L.scale);
        [_debugDraw drawSegmentFrom:CGPointMake(0, top) to:CGPointMake(d.width, top)
                             radius:0.5 color:yellow];
        [_debugDraw drawSegmentFrom:CGPointMake(0, bottom) to:CGPointMake(d.width, bottom)
                             radius:0.5 color:yellow];
        [_debugDraw drawSegmentFrom:CGPointMake(left, 0) to:CGPointMake(left, d.height)
                             radius:0.5 color:yellow];
        [_debugDraw drawSegmentFrom:CGPointMake(right, 0) to:CGPointMake(right, d.height)
                             radius:0.5 color:yellow];
    }

    // 文字
    NSString *txt = [NSString stringWithFormat:
                     @"design %.0fx%.0f\nscale %.3f\noffset %.1f,%.1f\nsafe t%.0f b%.0f l%.0f r%.0f\nscreen %.0f",
                     d.width, d.height, L.scale, L.offset.x, L.offset.y,
                     in.top, in.bottom, in.left, in.right, [UIScreen mainScreen].scale];
    _label.string = txt;
    // 每 4 秒换一次颜色，确认渲染循环在跑
    if (_tickCount % 2 == 0) {
        _hint.color = [CCColor colorWithRed:1 green:0.6 blue:0.2 alpha:1];
    } else {
        _hint.color = [CCColor whiteColor];
    }
}

@end
