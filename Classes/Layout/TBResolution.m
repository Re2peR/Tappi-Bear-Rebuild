//
//  TBResolution.m
//  Tappi Bear — 分辨率 / 安全区适配
//

#import "TBResolution.h"

static BOOL sLandscapeDesign = NO;

@implementation TBResolution

+ (CGSize)designSize
{
    return [self designSizeForOrientation:(sLandscapeDesign
                                           ? UIInterfaceOrientationLandscapeLeft
                                           : UIInterfaceOrientationPortrait)];
}

+ (CGSize)designSizeForOrientation:(UIInterfaceOrientation)orientation
{
    BOOL landscape = UIInterfaceOrientationIsLandscape(orientation);
    return landscape ? CGSizeMake(480.0, 320.0) : CGSizeMake(320.0, 480.0);
}

+ (BOOL)isLandscapeDesign { return sLandscapeDesign; }

+ (void)setLandscapeDesign:(BOOL)landscape
{
    if (sLandscapeDesign != landscape) {
        sLandscapeDesign = landscape;
        NSLog(@"[TB] design canvas -> %@", landscape ? @"480x320 (landscape)" : @"320x480 (portrait)");
    }
}

#pragma mark - 安全区

+ (TBSafeInsets)safeInsetsForView:(UIView *)view
{
    TBSafeInsets z = {0, 0, 0, 0};
    if (!view) return z;

    if (@available(iOS 11.0, *)) {
        UIEdgeInsets i = view.safeAreaInsets;
        // 无 window 时 safeAreaInsets 为 0，此时退化为 UIWindow 的取值。
        if (i.top == 0 && i.bottom == 0 && i.left == 0 && i.right == 0) {
            UIWindow *w = view.window ?: UIApplication.sharedApplication.keyWindow;
            if (w) i = w.safeAreaInsets;
        }
        z.top = i.top;
        z.bottom = i.bottom;
        z.left = i.left;
        z.right = i.right;
    }
    return z;
}

#pragma mark - 布局

+ (TBLayout)layoutForViewSize:(CGSize)viewSize
                   safeInsets:(TBSafeInsets)insets
                   designSize:(CGSize)designSize
{
    TBLayout L;
    L.design = designSize;

    CGFloat availW = viewSize.width - insets.left - insets.right;
    CGFloat availH = viewSize.height - insets.top - insets.bottom;
    if (availW <= 0) availW = viewSize.width;
    if (availH <= 0) availH = viewSize.height;
    if (availW <= 0 || availH <= 0 || designSize.width <= 0 || designSize.height <= 0) {
        L.scale = 1.0;
        L.offset = CGPointZero;
        L.canvas = designSize;
        return L;
    }

    // 等比缩放，短边贴满 —— 保证整个设计画布一定完整可见。
    CGFloat sx = availW / designSize.width;
    CGFloat sy = availH / designSize.height;
    CGFloat s  = MIN(sx, sy);

    L.scale  = s;
    L.canvas = CGSizeMake(designSize.width * s, designSize.height * s);

    // 在安全区内居中；安全区之外（刘海侧）也算进居中范围，避免视觉偏心。
    CGFloat cx = insets.left + (availW - L.canvas.width) * 0.5;
    CGFloat cy = insets.bottom + (availH - L.canvas.height) * 0.5;
    L.offset = CGPointMake(cx, cy);

    return L;
}

+ (TBLayout)layoutForView:(UIView *)view
{
    CGSize vs = view ? view.bounds.size : [UIScreen mainScreen].bounds.size;
    TBSafeInsets insets = [self safeInsetsForView:view];
    return [self layoutForViewSize:vs safeInsets:insets designSize:[self designSize]];
}

+ (CGPoint)designPointFromViewPoint:(CGPoint)p layout:(TBLayout)layout
{
    if (layout.scale <= 0) return p;
    return CGPointMake((p.x - layout.offset.x) / layout.scale,
                       (p.y - layout.offset.y) / layout.scale);
}

#pragma mark - 调试

+ (NSString *)debugDescriptionForView:(UIView *)view
{
    CGSize vs = view ? view.bounds.size : [UIScreen mainScreen].bounds.size;
    TBSafeInsets in = [self safeInsetsForView:view];
    TBLayout L = [self layoutForView:view];
    return [NSString stringWithFormat:
            @"view=%.0fx%.0f scale=%.2f design=%.0fx%.0f canvas=%.0fx%.0f offset=(%.0f,%.0f) "
            @"safe=(t%.0f b%.0f l%.0f r%.0f) scale=%.0f",
            vs.width, vs.height, L.scale,
            L.design.width, L.design.height, L.canvas.width, L.canvas.height,
            L.offset.x, L.offset.y,
            in.top, in.bottom, in.left, in.right,
            [UIScreen mainScreen].scale];
}

@end
