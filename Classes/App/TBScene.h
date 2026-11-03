//
//  TBScene.h
//  Tappi Bear — 根场景
//
//  TBScene 负责：
//    1. 建立 TBRootLayer（设计画布 320x480 的等比缩放容器）；
//    2. 在画布外填充背景延伸，避免黑边；
//    3. 接收屏幕尺寸/安全区变化并重新布局；
//    4. 承载真正的游戏场景（原版的 SelectGameLayer / Gx_GameLayer）。
//

#import "cocos2d.h"

@class TBRootLayer;

@interface TBScene : CCScene

/// 设计画布容器。所有游戏内容都应加到这个节点上（坐标系 320x480 / 480x320）。
@property (nonatomic, readonly, strong) TBRootLayer *rootLayer;

/// 画布外的背景延伸层（z 最小）。
@property (nonatomic, readonly, strong) CCNode *backdrop;

/// 把一个新的节点挂到画布上（替换已有内容）。
- (void)presentContent:(CCNode *)content;

/// 竖屏 / 横屏设计画布切换。
- (void)applyDesignSize:(CGSize)designSize;

@end
