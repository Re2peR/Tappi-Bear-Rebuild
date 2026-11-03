//
//  TBAppDelegate.h
//  Tappi Bear — arm64 兼容移植
//
//  继承 cocos2d-objc 3.5 的 CCAppDelegate（它已经实现了窗口/GLView/旋转/生命周期），
//  只覆盖两件事：
//    1. 屏幕模式 —— 用 Fixed 模式 + 自定义 designSize，这样 320x480 的设计画布在
//       任何比例的设备上都不会被拉伸；
//    2. 自定义投影 —— 见 TBAppDelegate.m 的 updateProjection，实现
//       「fit-width（竖屏）/ fit-height（横屏） + 居中 + 安全区偏移」。
//

#import "CCAppDelegate.h"

@interface TBAppDelegate : CCAppDelegate
@end
