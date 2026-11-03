//
//  TBAudio.h
//  Tappi Bear — 音频薄封装
//
//  原版用 CocosDenshion 的 SimpleAudioEngine（OpenAL 后端）+ CDAudioManager。
//  cocos2d-objc 3.5 不再带 CocosDenshion（ObjectAL 是另一套 API，
//  且 OpenAL 在新系统上行为不稳定）。
//
//  这里用 AVAudioPlayer 实现原版用到的全部能力，接口与 SimpleAudioEngine 对齐，
//  移植时可以直接把 [SimpleAudioEngine sharedEngine] 换成 [TBAudio sharedAudio]。
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface TBAudio : NSObject

+ (instancetype)sharedAudio;

/// 0.0 ~ 1.0，影响所有音效。
@property (nonatomic, assign) float effectsVolume;
/// 0.0 ~ 1.0，影响背景音乐。
@property (nonatomic, assign) float musicVolume;

/// 是否启用音效/音乐（对应原版的 isSound / isMusic 开关）。
@property (nonatomic, assign) BOOL effectsEnabled;
@property (nonatomic, assign) BOOL musicEnabled;

#pragma mark - 背景音乐

- (void)playBackgroundMusic:(NSString *)file loop:(BOOL)loop;
- (void)stopBackgroundMusic;
- (void)pauseMusic;
- (void)resumeMusic;
- (void)rewindMusic;
- (BOOL)isBackgroundMusicPlaying;

#pragma mark - 音效

- (void)playEffect:(NSString *)file;
- (void)playEffect:(NSString *)file volume:(float)volume;
- (void)stopAllEffects;

/// 预加载（提前解码，减少首次播放延迟）。
- (void)preloadEffect:(NSString *)file;

/// 进入后台/来电时停掉一切。
- (void)stopAll;

@end
