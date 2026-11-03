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
    CCNodeColor *_backdropColor;
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

        // 默认深色底，避免 letterbox 区域纯黑显得突兀
        [self setBackdropColor:[CCColor colorWithRed:0.10f green:0.10f blue:0.12f alpha:1.0f]];
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

#pragma mark - 背景

- (void)setBackdropColor:(CCColor *)color
{
    [_backdropColor removeFromParent];
    _backdropColor = nil;
    if (!color) return;

    CGSize screen = [self screenSize];
    CCNodeColor *c = [CCNodeColor nodeWithColor:color width:screen.width height:screen.height];
    c.anchorPoint = CGPointZero;
    c.position = CGPointZero;
    [_backdrop addChild:c z:-1];
    _backdropColor = c;
    [self layoutBackdrop];
}

/// 用一张小图平铺填满整个屏幕（画布外的黑边区域）。
/// 注意：不要用含文字/logo 的整图（放大会糊）。
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

- (CGSize)screenSize
{
    UIView *view = nil;
    id v = [CCDirector sharedDirector].view;
    if ([v isKindOfClass:[UIView class]]) view = (UIView *)v;
    return view ? view.bounds.size : [UIScreen mainScreen].bounds.size;
}

#pragma mark - 布局

- (void)relayoutForCurrentView
{
    [_rootLayer relayout];
    [self layoutBackdrop];
}

- (void)layoutBackdrop
{
    CGSize screen = [self screenSize];

    _backdrop.position = CGPointZero;
    _backdrop.contentSize = screen;
    _backdrop.scaleX = 1.0;
    _backdrop.scaleY = 1.0;

    if (_backdropColor) {
        _backdropColor.contentSize = screen;
        _backdropColor.position = CGPointZero;
    }

    // 平铺：把一张图按屏幕尺寸拉伸（背景是重复图案，拉伸可接受且无接缝）
    if (_backdropSprite && _backdropSprite.contentSize.width > 0) {
        CGFloat sx = screen.width / _backdropSprite.contentSize.width;
        CGFloat sy = screen.height / _backdropSprite.contentSize.height;
        CGFloat s = MAX(sx, sy);
        _backdropSprite.scaleX = s;
        _backdropSprite.scaleY = s;
        _backdropSprite.position = CGPointMake(
            (screen.width - _backdropSprite.contentSize.width * s) * 0.5f,
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
