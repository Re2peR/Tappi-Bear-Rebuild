//
//  TBRootLayer.m
//

#import "TBRootLayer.h"

@implementation TBRootLayer

- (instancetype)initWithDesignSize:(CGSize)designSize
{
    self = [super init];
    if (self) {
        _designSize = designSize;
        [super setContentSize:designSize];
        self.anchorPoint = CGPointMake(0, 0);
        [self relayout];
    }
    return self;
}

- (instancetype)init
{
    return [self initWithDesignSize:CGSizeMake(320.0, 480.0)];
}

- (void)setDesignSize:(CGSize)designSize
{
    _designSize = designSize;
    [super setContentSize:designSize];
    [self relayout];
}

- (void)onEnter
{
    [super onEnter];
    [self relayout];
}

- (void)relayout
{
    UIView *view = nil;
    id directorView = [CCDirector sharedDirector].view;
    if ([directorView isKindOfClass:[UIView class]]) {
        view = (UIView *)directorView;
    }

    CGSize viewSize = view ? view.bounds.size : [UIScreen mainScreen].bounds.size;
    TBLayout L = [TBResolution layoutForViewSize:viewSize
                                      safeInsets:[TBResolution safeInsetsForView:view]
                                      designSize:_designSize];
    _layout = L;

    // 只缩放 + 平移，不改子节点坐标。
    self.scaleX = L.scale;
    self.scaleY = L.scale;
    self.position = L.offset;
}

- (CGPoint)screenPointFromDesignPoint:(CGPoint)p
{
    return CGPointMake(p.x * _layout.scale + _layout.offset.x,
                       p.y * _layout.scale + _layout.offset.y);
}

- (CGPoint)designPointFromScreenPoint:(CGPoint)p
{
    if (_layout.scale <= 0) return p;
    return CGPointMake((p.x - _layout.offset.x) / _layout.scale,
                       (p.y - _layout.offset.y) / _layout.scale);
}

@end
