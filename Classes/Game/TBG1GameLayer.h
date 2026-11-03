//
//  TBG1GameLayer.h
//  Tappi Bear — 第 1 关（原版 G1_GameLayer）
//
//  玩法（从反汇编还原）：
//    - 三车道跑酷，车道中心 x = {40, 160, 280}（colWidth = 120）
//    - 小熊固定在下部（y ≈ 140），左右滑动换道
//    - 石头从顶部下落，每 colHeight=200 的累积距离生成一批
//    - 每批 3 条车道里随机留 1 条空道（可通行）
//    - 吃到星星 +10 分，撞到石头 -> game over
//    - 速度随时间线性增长：4.0 -> 8.0，每帧 +0.003
//    - 分数随时间 +0.1/帧，上限 999
//

#import "cocos2d.h"

@interface TBG1GameLayer : CCNode

@property (nonatomic, copy) void (^onExit)(void);

@end
