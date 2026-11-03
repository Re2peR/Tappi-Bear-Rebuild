//
//  TBCompat.m
//

#import "TBCompat.h"
#import "TBResolution.h"
#import <CoreMotion/CoreMotion.h>

#pragma mark - CCDirector

@implementation CCDirector (TBCompat1x)

- (CGSize)winSize { return self.viewSize; }
- (CGSize)winSizeInPixels { return self.viewSizeInPixels; }
- (id)openGLView { return self.view; }
- (void)setOpenGLView:(id)view { self.view = view; }

- (BOOL)enableRetinaDisplay:(BOOL)enabled
{
    // 3.5 的 contentScaleFactor 已经等于 UIScreen.scale（在 TBAppDelegate 里设置），
    // 这里只需要报告「高清是否生效」。
    return self.contentScaleFactor > 1.0;
}

- (void)setDeviceOrientation:(NSInteger)orientation
{
    // 3.5 用 CCAppDelegate 的 screenOrientation 管理方向；
    // 原版的 deviceOrientation 只是 convertToGL 的一个开关，这里空实现。
    (void)orientation;
}

- (void)setDirectorType:(NSInteger)type
{
    // 1.x 的 CCDirectorType 有 5 种；3.5 统一为 CCDirectorDisplayLink。
    (void)type;
}

@end

#pragma mark - CCNode

@implementation CCNode (TBCompat1x)

- (void)setIsTouchEnabled:(BOOL)enabled { self.userInteractionEnabled = enabled; }
- (BOOL)isTouchEnabled { return self.userInteractionEnabled; }

- (void)setIsAccelerometerEnabled:(BOOL)enabled
{
    // 原版只有 G8（接雪花）用到加速度计。3.5 没有内建加速度计分发，
    // 具体接法见 TBAccelerometer（P4 阶段接入 G8）。
    (void)enabled;
}

@end

#pragma mark - CCSprite

@implementation CCSprite (TBCompat1x)

+ (instancetype)spriteWithFile:(NSString *)file
{
    return [self spriteWithImageNamed:file];
}

- (instancetype)initWithFile:(NSString *)file
{
    return [self initWithImageNamed:file];
}

- (void)setTextureRectInPixels:(CGRect)rect
{
    // 1.x 的 setTextureRect: 传的是像素；3.5 的 setTextureRect: 传点。
    // 帧名路径（spriteWithSpriteFrameName:）不需要这个，只有 replaceSprite 用到。
    [self setTextureRect:rect];
}

@end

#pragma mark - CCSpriteBatchNode

@implementation CCSpriteBatchNode (TBCompat1x)

+ (instancetype)batchNodeWithFile:(NSString *)file capacity:(NSUInteger)capacity
{
    (void)capacity;  // 3.5 内部自动扩容
    return [self batchNodeWithFile:file];
}

@end

#pragma mark - CCFileUtils

@implementation CCFileUtils (TBCompat1x)

- (NSString *)tb_doubleResolutionPathForPath:(NSString *)path
{
    if (!path.length) return path;
    if ([UIScreen mainScreen].scale < 2.0) return path;

    NSString *noExt = [path stringByDeletingPathExtension];
    NSString *ext = [path pathExtension];
    if ([noExt hasSuffix:@"-hd"]) return path;

    NSString *hd = [[noExt stringByAppendingString:@"-hd"] stringByAppendingPathExtension:ext];
    if ([[NSFileManager defaultManager] fileExistsAtPath:hd]) return hd;

    // 3.5 的 searchPath 版本
    NSString *resolved = [self fullPathForFilename:path];
    return resolved.length ? resolved : path;
}

@end
