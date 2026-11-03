//
//  TBBootContent.h
//  Tappi Bear — P0 阶段的自检画面
//
//  在 P0（骨架阶段）用这个节点替代真实游戏内容，用来验证：
//    1. arm64 二进制能启动、OpenGL 上下文正常；
//    2. 设计画布 320x480 的等比缩放与居中正确；
//    3. 安全区 inset 计算正确（刘海 / 灵动岛 / Home Indicator）；
//    4. 3 种屏幕比例（2:3 / 19.5:9 / 4:3）下都不裁切。
//
//  P3 之后由真实的 SelectGameLayer 替换。
//

#import "cocos2d.h"

@interface TBBootContent : CCNode

@end
