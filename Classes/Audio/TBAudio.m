//
//  TBAudio.m
//

#import "TBAudio.h"

@interface TBAudio () <AVAudioPlayerDelegate>
@end

@implementation TBAudio {
    AVAudioPlayer *_music;
    NSString *_musicFile;
    BOOL _musicShouldLoop;

    // 音效池：同一个小文件可能被连续快速触发（吃金币、踩敌人），
    // 复用 AVAudioPlayer 会打断上一声，所以每次播放都用一个独立实例。
    NSMutableArray<AVAudioPlayer *> *_effectPlayers;
    NSMutableDictionary<NSString *, NSData *> *_effectDataCache;
    NSMutableSet<NSString *> *_preloaded;
}

+ (instancetype)sharedAudio
{
    static TBAudio *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        s = [[TBAudio alloc] init];
    });
    return s;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _effectsVolume = 1.0;
        _musicVolume = 1.0;
        _effectsEnabled = YES;
        _musicEnabled = YES;
        _effectPlayers = [NSMutableArray array];
        _effectDataCache = [NSMutableDictionary dictionary];
        _preloaded = [NSMutableSet set];

        // 允许与其它 App 音频混音（原版 CDAudioManager 的 kAMM_FxPlusMusicIfNoOtherAudio 近似行为）。
        NSError *err = nil;
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setCategory:AVAudioSessionCategoryAmbient error:&err];
        if (err) NSLog(@"[TB][audio] setCategory failed: %@", err.localizedDescription);
        [session setActive:YES error:&err];
        if (err) NSLog(@"[TB][audio] setActive failed: %@", err.localizedDescription);
    }
    return self;
}

#pragma mark - 资源定位

// 原版资源名不带 -hd 后缀，cocos2d 的 CCFileUtils 会自动补。
// 音频文件没有 -hd 版本，直接按原名查找。
- (NSString *)pathForFile:(NSString *)file
{
    if (!file.length) return nil;
    if ([file isAbsolutePath]) return file;

    NSString *dir = [file stringByDeletingLastPathComponent];
    NSString *name = [file lastPathComponent];
    NSString *base = [name stringByDeletingPathExtension];
    NSString *ext = [name pathExtension];

    NSString *p = [[NSBundle mainBundle] pathForResource:base ofType:ext inDirectory:(dir.length ? dir : nil)];
    if (p) return p;

    // 再试子目录
    return [[NSBundle mainBundle] pathForResource:base ofType:ext];
}

- (NSData *)dataForEffect:(NSString *)file
{
    NSString *key = file;
    NSData *cached = _effectDataCache[key];
    if (cached) return cached;

    NSString *path = [self pathForFile:file];
    if (!path) {
        NSLog(@"[TB][audio] effect not found: %@", file);
        return nil;
    }
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data) _effectDataCache[key] = data;
    return data;
}

#pragma mark - 背景音乐

- (void)playBackgroundMusic:(NSString *)file loop:(BOOL)loop
{
    if (!file.length) return;

    // 同一首正在播且要求循环 -> 不打断。
    if (_music && [_musicFile isEqualToString:file] && _music.isPlaying) {
        _musicShouldLoop = loop;
        _music.numberOfLoops = loop ? -1 : 0;
        return;
    }

    NSString *path = [self pathForFile:file];
    if (!path) {
        NSLog(@"[TB][audio] music not found: %@", file);
        return;
    }

    NSError *err = nil;
    AVAudioPlayer *p = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path]
                                                             error:&err];
    if (!p) {
        NSLog(@"[TB][audio] music load failed %@: %@", file, err.localizedDescription);
        return;
    }
    p.delegate = self;
    p.numberOfLoops = loop ? -1 : 0;
    p.volume = _musicEnabled ? _musicVolume : 0.0;
    p.enableRate = NO;
    [p prepareToPlay];

    [_music stop];
    _music = p;
    _musicFile = [file copy];
    _musicShouldLoop = loop;
    if (_musicEnabled) [p play];
}

- (void)stopBackgroundMusic
{
    [_music stop];
    _music = nil;
    _musicFile = nil;
}

- (void)pauseMusic
{
    [_music pause];
}

- (void)resumeMusic
{
    if (_music && _musicEnabled) [_music play];
}

- (void)rewindMusic
{
    _music.currentTime = 0;
}

- (BOOL)isBackgroundMusicPlaying
{
    return _music.isPlaying;
}

#pragma mark - 音效

- (void)playEffect:(NSString *)file
{
    [self playEffect:file volume:1.0];
}

- (void)playEffect:(NSString *)file volume:(float)volume
{
    if (!_effectsEnabled || _effectsVolume <= 0.0f) return;

    NSData *data = [self dataForEffect:file];
    if (!data) return;

    NSError *err = nil;
    AVAudioPlayer *p = [[AVAudioPlayer alloc] initWithData:data error:&err];
    if (!p) {
        NSLog(@"[TB][audio] effect decode failed %@: %@", file, err.localizedDescription);
        return;
    }
    p.volume = _effectsVolume * volume;
    [p prepareToPlay];
    [p play];

    [_effectPlayers addObject:p];

    // 清理已播完的实例，避免数组无限增长。
    NSMutableArray *finished = [NSMutableArray array];
    for (AVAudioPlayer *ep in _effectPlayers) {
        if (!ep.isPlaying) [finished addObject:ep];
    }
    // 保留最近 8 个，避免刚结束的还没发声就被回收。
    if (finished.count > 8) {
        [finished removeObjectsInRange:NSMakeRange(0, finished.count - 8)];
        [_effectPlayers removeObjectsInArray:finished];
    }
}

- (void)stopAllEffects
{
    for (AVAudioPlayer *p in _effectPlayers) [p stop];
    [_effectPlayers removeAllObjects];
}

- (void)preloadEffect:(NSString *)file
{
    if (!file.length || [_preloaded containsObject:file]) return;
    if ([self dataForEffect:file]) [_preloaded addObject:file];
}

#pragma mark - 开关

- (void)setMusicEnabled:(BOOL)enabled
{
    _musicEnabled = enabled;
    _music.volume = enabled ? _musicVolume : 0.0;
    if (enabled) {
        if (_music && !_music.isPlaying) [_music play];
    } else {
        [_music pause];
    }
}

- (void)setEffectsEnabled:(BOOL)enabled
{
    _effectsEnabled = enabled;
    if (!enabled) [self stopAllEffects];
}

- (void)setMusicVolume:(float)v
{
    _musicVolume = MAX(0.0f, MIN(1.0f, v));
    if (_music) _music.volume = _musicEnabled ? _musicVolume : 0.0;
}

- (void)setEffectsVolume:(float)v
{
    _effectsVolume = MAX(0.0f, MIN(1.0f, v));
}

- (void)stopAll
{
    [self stopBackgroundMusic];
    [self stopAllEffects];
}

#pragma mark - AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    if (player == _music) {
        if (_musicShouldLoop) {
            [_music play];
        }
    }
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error
{
    NSLog(@"[TB][audio] decode error: %@", error.localizedDescription);
}

@end
