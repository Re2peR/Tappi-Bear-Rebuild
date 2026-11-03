//
//  TBAppDelegate.m
//  Tappi Bear — arm64 兼容移植
//

#import "TBAppDelegate.h"
#import "TBResolution.h"
#import "TBScene.h"
#import "TBBootContent.h"
#import "TBAudio.h"

@implementation TBAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // ---------------------------------------------------------------
    // 1. 资源查找：所有图集/plist/音频都在 bundle 根目录，
    //    沿用原版的 -hd 后缀规则（原版 CCFileUtils getDoubleResolutionImage: 的行为）。
    // ---------------------------------------------------------------
    CCFileUtils *fileUtils = [CCFileUtils sharedFileUtils];
    fileUtils.enableiPhoneResourcesOniPad = YES;
    fileUtils.searchMode = CCFileUtilsSearchModeSuffix;
    [fileUtils buildSearchResolutionsOrder];

    // ---------------------------------------------------------------
    // 2. 启动 cocos2d。
    //    用 Flexible 模式：投影始终是 ortho(0, viewSize)，
    //    这样 convertToGL / locationInNode: 的触摸换算与 3.5 原生行为一致。
    //    设计画布的缩放由 TBScene 里的 TBRootLayer 负责。
    // ---------------------------------------------------------------
    [self setupCocos2dWithOptions:@{
        CCSetupDepthFormat: @GL_DEPTH24_STENCIL8,
        CCSetupScreenMode: CCScreenModeFlexible,
        CCSetupScreenOrientation: CCScreenOrientationPortrait,
        CCSetupPixelFormat: kEAGLColorFormatRGBA8,
        CCSetupAnimationInterval: @(1.0 / 60.0),
        CCSetupTabletScale2X: @NO,
        CCSetupShowDebugStats: @(getenv("TB_DEBUG_STATS") != nil),
    }];

    CCDirector *director = [CCDirector sharedDirector];
    // 3x 设备走原生 3 倍帧缓冲，避免系统级放大导致的模糊。
    director.contentScaleFactor = [UIScreen mainScreen].scale;

    // 音频：原版用 CocosDenshion 的 SimpleAudioEngine + CDAudioManager，
    // 3.5 里已经没有这套（ObjectAL 是另一套 API）。用 AVAudioPlayer 薄封装替代。
    [TBAudio sharedAudio].effectsVolume = 1.0;
    [TBAudio sharedAudio].musicVolume   = 1.0;

    // P0：先挂自检画面；P3 之后换成 SelectGameLayer。
    TBScene *scene = [TBScene scene];
    [scene presentContent:[[TBBootContent alloc] init]];
    [director runWithScene:scene];

    return YES;
}

#pragma mark - 生命周期

- (void)applicationWillResignActive:(UIApplication *)application
{
    [[TBAudio sharedAudio] pauseMusic];
    [super applicationWillResignActive:application];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    [super applicationDidBecomeActive:application];
    [[TBAudio sharedAudio] resumeMusic];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    [[TBAudio sharedAudio] stopAll];
    [super applicationDidEnterBackground:application];
}

@end
