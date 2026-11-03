//
//  TBMovieClip+Data.h
//  Tappi Bear — 从 TBAnimData 的静态表构造剪辑
//
//  每个游戏的 Gx_Bear / Gx_Cover / Gx_MovieClip 子类只需要一行：
//      [self loadTableNamed:@"G1_Bear"];
//  剩下的帧名、锚点、标签、帧变换全部来自反汇编还原的静态表。
//

#import "TBMovieClip.h"

@interface TBMovieClip (Data)

/// 从 TBAnimData 加载指定类的动画表；返回 NO 表示表不存在。
- (BOOL)loadTableNamed:(NSString *)className;

@end
