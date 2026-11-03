//
//  TBSelectGameLayer.h
//  Tappi Bear — 选关界面（原版 SelectGameLayer）
//
//  原版布局（320x480 竖屏，反汇编还原）：
//    - 背景图集 selectgame.png，含 8 张封面 cover_p1..p8、金币、logo、promo
//    - 封面 3 列 x 3 行，热区：
//        G1 [0,106]  x [269,375]
//        G2 [106,213] x [269,375]
//        G3 [213,320] x [269,375]
//        G4 [0,106]  x [155,262]
//        G5 [106,213] x [155,262]
//        G6 [213,320] x [155,262]
//        G7 [0,106]  x [46,154]
//        G8 [106,213] x [46,154]
//        (213,320) x [46,154] -> 切换第二页（Pack2）
//    - 金币 HUD：右上角，数字 6 位，间距 18
//    - logo / cover 在 y=480（屏幕上方外）
//    - promo 在 (248, 21)
//

#import "cocos2d.h"

@interface TBSelectGameLayer : CCNode

+ (instancetype)scene;

/// 用户点了某个小游戏（1..8）。默认实现只打日志。
@property (nonatomic, copy) void (^onSelectGame)(NSInteger gameIndex);

@end
