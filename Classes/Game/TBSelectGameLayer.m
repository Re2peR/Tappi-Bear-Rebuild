//
//  TBSelectGameLayer.m
//

#import "TBSelectGameLayer.h"
#import "TBCompat.h"
#import "TBResolution.h"
#import "TBAudio.h"

// 每个小游戏的封面图集（原版是 8 个独立 plist，不是一张大图）
static NSString *const kCoverSheets[8] = {
    @"g1_cover", @"g2_cover", @"g3_cover", @"g4_cover",
    @"g5_cover", @"g6_cover", @"g7_cover", @"g8_cover"
};

// 原版热区（320x480 设计坐标，左下原点）
static const CGFloat kHotX[8]  = {0, 106, 213, 0, 106, 213, 0, 106};
static const CGFloat kHotX2[8] = {106, 213, 320, 106, 213, 320, 106, 213};
static const CGFloat kHotY[8]  = {269, 269, 269, 155, 155, 155, 46, 46};
static const CGFloat kHotY2[8] = {375, 375, 375, 262, 262, 262, 154, 154};

// 第 9 格（213..320, 46..154）是「第二弹」入口
static const CGFloat kPage2X1 = 213, kPage2X2 = 320, kPage2Y1 = 46, kPage2Y2 = 154;

@implementation TBSelectGameLayer {
    CCSpriteBatchNode *_sheet;
    NSMutableArray<CCSprite *> *_covers;
    NSMutableArray<CCSprite *> *_coins;
    CCLabelTTF *_debugLabel;
    BOOL _didLoad;
}

+ (instancetype)scene
{
    return [[self alloc] init];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.contentSize = [TBResolution designSize];
        self.anchorPoint = CGPointZero;
        self.userInteractionEnabled = YES;

        _covers = [NSMutableArray array];
        _coins = [NSMutableArray array];
    }
    return self;
}

- (void)onEnter
{
    [super onEnter];
    if (!_didLoad) {
        _didLoad = YES;
        [self buildUI];
    }
}

#pragma mark - 构建界面

- (void)buildUI
{
    CGSize d = self.contentSize;

    // 1. 背景图集
    [[CCSpriteFrameCache sharedSpriteFrameCache] addSpriteFramesWithFile:@"selectgame.plist"];
    _sheet = [CCSpriteBatchNode batchNodeWithFile:@"selectgame.png"];
    if (_sheet) {
        [self addChild:_sheet z:0];
    }

    // 2. 背景
    CCSprite *bg = [CCSprite spriteWithSpriteFrameName:@"cover_bg.png"];
    if (bg) {
        bg.anchorPoint = CGPointMake(0, 0);
        bg.position = CGPointZero;
        [self addChild:bg z:0];
    }

    // 3. 8 张封面：每个游戏用自己的图集，放在 3x3 网格里
    //    原版封面尺寸 322x482，网格单元 106x107，所以封面需要缩放到 ~1/3
    for (NSInteger i = 0; i < 8; i++) {
        NSString *plist = [kCoverSheets[i] stringByAppendingString:@".plist"];
        NSString *tex = [kCoverSheets[i] stringByAppendingString:@".png"];
        [[CCSpriteFrameCache sharedSpriteFrameCache] addSpriteFramesWithFile:plist];

        // 用每个游戏封面图集里的 cover_tappi（角色立绘）作为缩略图
        CCSprite *thumb = [CCSprite spriteWithSpriteFrameName:@"cover_tappi.png"];
        if (!thumb) {
            thumb = [CCSprite spriteWithImageNamed:tex];
        }
        if (!thumb) continue;

        CGFloat cx = (kHotX[i] + kHotX2[i]) * 0.5f;
        CGFloat cy = (kHotY[i] + kHotY2[i]) * 0.5f;

        // 缩放到格子里（留 6pt 边距）
        CGFloat cellW = (kHotX2[i] - kHotX[i]) - 12;
        CGFloat cellH = (kHotY2[i] - kHotY[i]) - 12;
        CGFloat s = MIN(cellW / MAX(thumb.contentSize.width, 1),
                        cellH / MAX(thumb.contentSize.height, 1));
        thumb.scale = MIN(s, 1.0f);
        thumb.position = CGPointMake(cx, cy);
        [self addChild:thumb z:10];
        [_covers addObject:thumb];

        // 格子边框（调试用，能看清热区）
        [self addGridFrameX1:kHotX[i] y1:kHotY[i] x2:kHotX2[i] y2:kHotY2[i]];
    }

    // 4. 第 9 格：第二弹入口
    [self addGridFrameX1:kPage2X1 y1:kPage2Y1 x2:kPage2X2 y2:kPage2Y2];
    CCLabelTTF *p2 = [CCLabelTTF labelWithString:@"PACK 2"
                                        fontName:@"Helvetica-Bold" fontSize:14];
    p2.position = CGPointMake((kPage2X1 + kPage2X2) * 0.5f, (kPage2Y1 + kPage2Y2) * 0.5f);
    p2.color = [CCColor colorWithRed:1 green:0.85 blue:0.3 alpha:1];
    [self addChild:p2 z:11];

    // 5. 顶部标题
    CCSprite *logo = [CCSprite spriteWithSpriteFrameName:@"cover_logo.png"];
    if (logo) {
        logo.position = CGPointMake(d.width * 0.5f, d.height - 40);
        [self addChild:logo z:20];
    }

    // 6. 金币 HUD（右上角）
    [self buildCoinHUD];

    // 7. 调试信息
    _debugLabel = [CCLabelTTF labelWithString:@"" fontName:@"Menlo" fontSize:8];
    _debugLabel.anchorPoint = CGPointMake(0, 1);
    _debugLabel.position = CGPointMake(4, d.height - 4);
    _debugLabel.color = [CCColor colorWithRed:0.4 green:1 blue:0.4 alpha:1];
    [self addChild:_debugLabel z:100];
    [self updateDebugLabel];

    // 8. 背景音乐
    [[TBAudio sharedAudio] playBackgroundMusic:@"bgm.mp3" loop:YES];
}

- (void)addGridFrameX1:(CGFloat)x1 y1:(CGFloat)y1 x2:(CGFloat)x2 y2:(CGFloat)y2
{
    CCDrawNode *n = [CCDrawNode node];
    const CGPoint quad[4] = {
        CGPointMake(x1, y1), CGPointMake(x2, y1),
        CGPointMake(x2, y2), CGPointMake(x1, y2)
    };
    [n drawPolyWithVerts:quad count:4 fillColor:[CCColor clearColor]
             borderWidth:0.5
             borderColor:[CCColor colorWithRed:0.3 green:0.7 blue:1 alpha:0.5]];
    [self addChild:n z:5];
}

- (void)buildCoinHUD
{
    CGSize d = self.contentSize;
    NSInteger coin = [[NSUserDefaults standardUserDefaults] integerForKey:@"coin"];
    if (coin <= 0) {
        coin = 100;
        [[NSUserDefaults standardUserDefaults] setInteger:coin forKey:@"coin"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }

    // 金币图标
    CCSprite *icon = [CCSprite spriteWithSpriteFrameName:@"cover_coin.png"];
    if (icon) {
        icon.position = CGPointMake(d.width - 70, d.height - 22);
        [self addChild:icon z:30];
    }

    // 6 位数字，间距 18（原版）
    NSString *s = [NSString stringWithFormat:@"%06ld", (long)MIN(coin, 999999)];
    for (NSInteger i = 0; i < 6; i++) {
        unichar ch = [s characterAtIndex:i];
        NSString *name = [NSString stringWithFormat:@"num%c.png", (char)ch];
        CCSprite *n = [CCSprite spriteWithSpriteFrameName:name];
        if (!n) continue;
        n.scale = 0.5f;
        n.position = CGPointMake(d.width - 52 + i * 9, d.height - 22);
        [self addChild:n z:30];
        [_coins addObject:n];
    }
}

- (void)updateDebugLabel
{
    TBLayout L = [TBResolution layoutForView:nil];
    _debugLabel.string = [NSString stringWithFormat:
                          @"selectgame  8 covers  scale %.2f  screen %.0f",
                          L.scale, [UIScreen mainScreen].scale];
}

#pragma mark - 触摸

- (void)touchBegan:(CCTouch *)touch withEvent:(CCTouchEvent *)event
{
    CGPoint p = [touch locationInNode:self];
    NSLog(@"[TB] tap at (%.0f, %.0f)", p.x, p.y);

    for (NSInteger i = 0; i < 8; i++) {
        if (p.x >= kHotX[i] && p.x < kHotX2[i] &&
            p.y >= kHotY[i] && p.y < kHotY2[i]) {
            [[TBAudio sharedAudio] playEffect:@"select.wav"];
            [self selectGame:i + 1];
            return;
        }
    }

    if (p.x >= kPage2X1 && p.x < kPage2X2 && p.y >= kPage2Y1 && p.y < kPage2Y2) {
        [[TBAudio sharedAudio] playEffect:@"select.wav"];
        NSLog(@"[TB] PACK 2 tapped (not implemented yet)");
        _debugLabel.string = @"PACK 2 — 未移植";
        return;
    }
}

- (void)selectGame:(NSInteger)idx
{
    NSLog(@"[TB] select game %ld", (long)idx);
    _debugLabel.string = [NSString stringWithFormat:@"选择了游戏 %ld — 玩法待移植", (long)idx];

    // 给点击反馈：被点的封面弹一下
    CCSprite *s = _covers[idx - 1];
    [s runAction:[CCActionSequence actions:
                  [CCActionScaleTo actionWithDuration:0.08 scale:0.9f],
                  [CCActionScaleTo actionWithDuration:0.08 scale:1.0f],
                  nil]];

    if (self.onSelectGame) self.onSelectGame(idx);
}

@end
