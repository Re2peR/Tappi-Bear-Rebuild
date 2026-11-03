//
//  TBCompat.h
//  Tappi Bear — cocos2d 1.x -> 3.5 兼容垫片
//
//  原版是 cocos2d-iphone 1.x。反编译出来的 4041 处引擎调用里，
//  约 3500 处选择子在 3.5 里同名同义，可以直接复用；
//  剩下 514 处需要迁移。这个文件用 Category 把 1.x 的调用形式
//  重新暴露出来，让移植时绝大多数代码可以原样保留。
//
//  用法：在需要兼容旧写法的 .m 里 #import "TBCompat.h"。
//

#import "cocos2d.h"

#pragma mark - CCDirector（1.x 别名）

@interface CCDirector (TBCompat1x)

/// 1.x: winSize —— 3.5 叫 viewSize。
- (CGSize)winSize;
/// 1.x: winSizeInPixels —— 3.5 叫 viewSizeInPixels。
- (CGSize)winSizeInPixels;
/// 1.x: openGLView —— 3.5 叫 view。
- (id)openGLView;
/// 1.x: setOpenGLView: —— 3.5 叫 setView:。
- (void)setOpenGLView:(id)view;
/// 1.x: enableRetinaDisplay: —— 3.5 由 contentScaleFactor 自动处理。
- (BOOL)enableRetinaDisplay:(BOOL)enabled;
/// 1.x: setDeviceOrientation: —— 3.5 没有设备朝向概念，空实现。
- (void)setDeviceOrientation:(NSInteger)orientation;
/// 1.x: setDirectorType: —— 3.5 只有 CCDirectorDisplayLink。
- (void)setDirectorType:(NSInteger)type;

@end

#pragma mark - CCNode（1.x 别名）

@interface CCNode (TBCompat1x)

/// 1.x: setIsTouchEnabled: —— 3.5 叫 userInteractionEnabled。
- (void)setIsTouchEnabled:(BOOL)enabled;
- (BOOL)isTouchEnabled;
/// 1.x: setIsAccelerometerEnabled: —— 3.5 需自己接 CMMotionManager。
- (void)setIsAccelerometerEnabled:(BOOL)enabled;

@end

#pragma mark - CCSprite（1.x 别名）

@interface CCSprite (TBCompat1x)

/// 1.x: spriteWithFile: —— 3.5 叫 spriteWithImageNamed:。
+ (instancetype)spriteWithFile:(NSString *)file;
/// 1.x: initWithFile:
- (instancetype)initWithFile:(NSString *)file;
/// 1.x: setTextureRect: 接受「像素」矩形；3.5 同名方法已存在，这里只补一个便捷重载。
- (void)setTextureRectInPixels:(CGRect)rect;

@end

#pragma mark - CCSpriteBatchNode（1.x 别名）

@interface CCSpriteBatchNode (TBCompat1x)

/// 1.x: batchNodeWithFile:capacity: —— 3.5 只有 batchNodeWithFile:。
+ (instancetype)batchNodeWithFile:(NSString *)file capacity:(NSUInteger)capacity;

@end

#pragma mark - CCFileUtils（1.x 高清后缀）

@interface CCFileUtils (TBCompat1x)

/// 1.x 的「-hd」规则：retina 设备自动把 foo.png 换成 foo-hd.png。
/// 3.5 通过 searchResolutionsOrder 实现同样效果，这里提供一个直接查询的入口，
/// 用于那些绕过 CCFileUtils 自己拼路径的旧代码。
- (NSString *)tb_doubleResolutionPathForPath:(NSString *)path;

@end
