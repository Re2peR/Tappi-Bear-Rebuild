//
//  TBMovieClip.h
//  Tappi Bear — 动画剪辑基类
//
//  原版每个游戏都有一份 Gx_MovieClip（54~102 个方法），8 个游戏共 94 个方法逐字节相同。
//  这里把它们合并成一个基类，各游戏的 Gx_MovieClip 只保留数据表（帧序列/锚点/尺寸）。
//
//  数据结构（从反汇编还原）：
//    clipNameList  : NSArray<NSString*>  每个 clip 的贴图帧名
//    clipAnchorX/Y : float[]             每个 clip 的锚点（0~1）
//    labelNameList : NSArray<NSString*>  标签名
//    labelFrameList: int[]               标签对应的起始帧
//    totalFrames   : int                 该动画的总帧数
//    width/height  : int                 设计尺寸
//    anchorX/anchorY: int                整体锚点（像素）
//
//  帧驱动：
//    tick 每帧 +1，遇到 labelFrameList 里的帧就跳过（标签帧不是可见帧），
//    到 totalFrames-1 停止并回调 onLastFrame。
//
//  每帧的变换（6 个 float）来自 gotoAndPlayFrame: 里的静态表：
//    dx, dy, scaleX, scaleY, rotation, alpha
//

#import "cocos2d.h"

@class CCSpriteBatchNode;

@interface TBMovieClip : CCNode

#pragma mark - 数据（子类在 initWithSheet: 里填）

@property (nonatomic, strong) CCSpriteBatchNode *sheet;
@property (nonatomic, copy)   NSArray<NSString *> *clipNameList;
@property (nonatomic, strong) NSArray<NSNumber *> *clipAnchorX;
@property (nonatomic, strong) NSArray<NSNumber *> *clipAnchorY;
@property (nonatomic, copy)   NSArray<NSString *> *labelNameList;
@property (nonatomic, strong) NSArray<NSNumber *> *labelFrameList;

@property (nonatomic, assign) NSInteger totalFrames;
@property (nonatomic, assign) NSInteger width;
@property (nonatomic, assign) NSInteger height;
@property (nonatomic, assign) NSInteger anchorX;
@property (nonatomic, assign) NSInteger anchorY;

#pragma mark - 状态

/// 帧变换表（totalFrames × frameClipCount，行优先）。由 TBMovieClip+Data 填充。
@property (nonatomic, assign) const void *frameTable;
@property (nonatomic, assign) NSInteger frameClipCount;

@property (nonatomic, assign) NSInteger currentFrame;
@property (nonatomic, assign) BOOL isPlay;
@property (nonatomic, strong) NSString *currentLabel;

@property (nonatomic, assign) float baseX, baseY;
@property (nonatomic, assign) float baseScaleX, baseScaleY;
@property (nonatomic, assign) float baseRotation;
@property (nonatomic, assign) float baseAlpha;
@property (nonatomic, assign) BOOL baseVisible;

@property (nonatomic, assign) NSInteger mcID;
@property (nonatomic, assign) NSInteger tempID;
@property (nonatomic, assign) NSInteger depth;

#pragma mark - 生命周期

/// 子类覆盖：设置数据表，然后调用 [self buildSpritesWithZOrder:]。
- (instancetype)initWithSheet:(CCSpriteBatchNode *)sheet zOrder:(NSInteger)z;

/// 由数据表创建所有子精灵（默认隐藏）。
- (void)buildSpritesWithZOrder:(NSInteger)zOrder;

#pragma mark - 帧控制

- (void)gotoAndPlayFrame:(NSInteger)frame;
- (void)gotoAndStopFrame:(NSInteger)frame;
- (void)gotoAndPlayName:(NSString *)name;
- (void)gotoAndStopName:(NSString *)name;
- (void)stop;
- (void)play;

#pragma mark - 子类可覆盖

/// 每帧应用变换后调用；用于音效等副作用。
- (void)didEnterFrame:(NSInteger)frame;

/// 播放到最后一帧时调用。
- (void)onLastFrame;

#pragma mark - 查询

- (CCSprite *)spriteAtIndex:(NSInteger)index;
- (NSInteger)spriteCount;

@end
