//
//  TBRootLayer.h
//  Tappi Bear — 设计画布容器
//
//  TBRootLayer 把「设计坐标 (0,0)-(W,H)」映射到「屏幕点」：
//
//      screen = design * scale + offset
//
//  它的 contentSize 永远是设计画布尺寸，所以子节点用原版硬编码坐标即可。
//  scale/offset 由 TBResolution 根据屏幕尺寸与安全区算出。
//

#import "cocos2d.h"
#import "TBResolution.h"

@interface TBRootLayer : CCNode

@property (nonatomic, readonly, assign) TBLayout layout;
@property (nonatomic, readonly, assign) CGSize designSize;

- (instancetype)initWithDesignSize:(CGSize)designSize NS_DESIGNATED_INITIALIZER;

/// 改变设计画布尺寸（竖屏 <-> 横屏切换）。
- (void)setDesignSize:(CGSize)designSize;

/// 用当前屏幕重新计算布局。view 尺寸就绪后调用（onEnter）。
- (void)relayout;

/// 设计坐标 -> 屏幕点（cocos2d 点坐标系，原点左下）。
- (CGPoint)screenPointFromDesignPoint:(CGPoint)p;

/// 屏幕点 -> 设计坐标。
- (CGPoint)designPointFromScreenPoint:(CGPoint)p;

@end
