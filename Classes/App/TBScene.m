//
//  TBScene.m
//

#import "TBScene.h"
#import "TBRootLayer.h"
#import "TBResolution.h"
#import "TBCompat.h"

@implementation TBScene {
    CCNode *_content;
    CCSprite *_backdropSprite;
}

+ (instancetype)scene
{
    return [[self alloc] init];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        CGSize design = [TBResolution designSize];

        // 1. 背景延伸层：铺满整个屏幕，避免画布外的纯黑边。
        _backdrop = [CCNode node];
        [self addChild:_backdrop z:-1000];

        // 2. 设计画布容器。
        _rootLayer = [[TBRootLayer alloc] initWithDesignSize:design];
        [self addChild:_rootLayer z:0];
    }
    return self;
}

- (void)onEnter
{
    [super onEnter];
    [self relayoutForCurrentView];
}

- (void)viewDidResizeTo:(CGSize)newViewSize
{
    [super viewDidResizeTo:newViewSize];
    [self relayoutForCurrentView];
}

#pragma mark - 背景图案

/// 用一张小图平铺填满整个屏幕（画布外的黑边区域）。
/// 原版是用 X2board1-4.png 拼边框；这里用同一张背景图平铺，观感更连续。
- (void)setBackdropTextureNamed:(NSString *)frameName
{
    [_backdropSprite removeFromParent];
    _backdropSprite = nil;

    if (!frameName.length) return;

    CCSprite *s = [CCSprite spriteWithSpriteFrameName:frameName];
    if (!s) {
        s = [CCSprite spriteWithImageNamed:frameName];
    }
    if (!s) return;

    s.anchorPoint = CGPointZero;
    s.position = CGPointZero;
    s.opacity = 0.55f;          // 压暗，避免抢画布内容
    [_backdrop addChild:s z:0];
    _backdropSprite = s;

    [self layoutBackdrop];
}

#pragma mark - 布局

- (void)relayoutForCurrentView
{
    [_rootLayer relayout];
    [self layoutBackdrop];
}

- (void)layoutBackdrop
{
    UIView *view = nil;
    id v = [CCDirector sharedDirector].view;
    if ([v isKindOfClass:[UIView class]]) view = (UIView *)v;
    CGSize screen = view ? view.bounds.size : [UIScreen mainScreen].bounds.size;

    _backdrop.position = CGPointZero;
    _backdrop.contentSize = screen;
    _backdrop.scaleX = 1.0;
    _backdrop.scaleY = 1.0;

    // 平铺：把一张图按屏幕尺寸拉伸（背景是重复图案，拉伸可接受且无接缝）
    if (_backdropSprite && _backdropSprite.contentSize.width > 0) {
        CGFloat sx = screen.width / _backdropSprite.contentSize.width;
        CGFloat sy = screen.height / _backdropSprite.contentSize.height;
        // 取较大值保证铺满，再居中裁剪
        CGFloat s = MAX(sx, sy);
        _backdropSprite.scaleX = s;
        _backdropSprite.scaleY = s;
        _backdropSprite.position = CGPointMake((screen.width - _backdropSprite.contentSize.width * s) * 0.5f,
                                               (screen.height - _backdropSprite.contentSize.height * s) * 0.5f);
    }
}

- (void)applyDesignSize:(CGSize)designSize
{
    [TBResolution setLandscapeDesign:(designSize.width > designSize.height)];
    [_rootLayer setDesignSize:designSize];
    [self layoutBackdrop];
}

- (void)presentContent:(CCNode *)content
{
    if (_content == content) return;
    [_content removeFromParent];
    _content = content;
    if (content) {
        [_rootLayer addChild:content z:0];
    }
}

@end
