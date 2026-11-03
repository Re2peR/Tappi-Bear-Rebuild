//
//  TBResolution.h
//  Tappi Bear — 分辨率 / 安全区适配
//
//  原版是 320x480（竖屏）/ 480x320（横屏）的固定设计画布。
//  作者当年用 X2board1-4.png 给 iPad 补边；这里把这套思路做成通用机制：
//
//    * 设计画布尺寸固定 —— 所有反编译出来的硬编码坐标继续有效；
//    * 画布按「短边贴满安全区」等比缩放（竖屏 fit-width / 横屏 fit-height）；
//    * 多余的空间用背景延伸填充，绝不裁掉可交互区域；
//    * 输出安全区 inset，供 HUD 锚定，避开刘海 / 灵动岛 / Home Indicator。
//
//  实现位置在 TBRootLayer：它把设计画布 (0,0)-(W,H) 映射到屏幕点坐标系。
//  CCDirector 的投影保持 cocos2d 默认（ortho(0, viewSize)），
//  这样 convertToGL / locationInNode: 的触摸换算才是正确的。
//

#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

/// 设计画布 -> 屏幕点 的仿射映射：point = design * scale + offset
typedef struct {
    CGSize  design;    // 设计画布尺寸，例如 320x480
    CGFloat scale;     // 等比缩放
    CGPoint offset;    // 画布左下角在屏幕点坐标系中的位置
    CGSize  canvas;    // 缩放后的画布在屏幕上的尺寸（= design * scale）
} TBLayout;

typedef struct {
    CGFloat top, bottom, left, right;   // 单位：屏幕点
} TBSafeInsets;

@interface TBResolution : NSObject

/// 竖屏设计画布 320x480；横屏 480x320。
+ (CGSize)designSize;
+ (CGSize)designSizeForOrientation:(UIInterfaceOrientation)orientation;

/// 当前是否为横屏设计（G3/G4）。
+ (BOOL)isLandscapeDesign;
+ (void)setLandscapeDesign:(BOOL)landscape;

/// 当前安全区（屏幕点）。无 window 时返回 0。
+ (TBSafeInsets)safeInsetsForView:(UIView *)view;

/// 计算布局：在安全区内等比缩放并居中。
+ (TBLayout)layoutForViewSize:(CGSize)viewSize
                   safeInsets:(TBSafeInsets)insets
                   designSize:(CGSize)designSize;

/// 便捷入口：直接从 view 计算。
+ (TBLayout)layoutForView:(UIView *)view;

/// 屏幕点 -> 设计坐标（给 UIKit 层的按钮/弹窗用）。
+ (CGPoint)designPointFromViewPoint:(CGPoint)p layout:(TBLayout)layout;

/// 调试文字。
+ (NSString *)debugDescriptionForView:(UIView *)view;

@end

NS_ASSUME_NONNULL_END
