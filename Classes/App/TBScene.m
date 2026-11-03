//
//  TBScene.m
//

#import "TBScene.h"
#import "TBRootLayer.h"
#import "TBResolution.h"

@implementation TBScene {
    CCNode *_content;
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

        // 1. 背景延伸层：铺满整个屏幕，避免画布外的黑边。
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
