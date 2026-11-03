//
//  TBG1GameLayer.m
//

#import "TBG1GameLayer.h"
#import "TBCompat.h"
#import "TBResolution.h"
#import "TBMovieClip.h"
#import "TBMovieClip+Data.h"
#import "TBAudio.h"

// ---- 原版常量（从 initWithSheet / tick 反汇编还原）----
static const CGFloat kColX[3]     = {40.0f, 160.0f, 280.0f};  // 车道中心 x
static const CGFloat kColWidth    = 120.0f;
static const CGFloat kColHeight   = 200.0f;   // 石头生成间隔（累积距离）
static const CGFloat kSpaceHeight = 340.0f;
static const CGFloat kBaseSpeed   = 3.0f;     // 0x40400000 = 3.0
static const CGFloat kMaxSpeed    = 8.0f;     // 0x41000000
static const CGFloat kBearY       = 140.0f;   // 0x430c0000
static const CGFloat kBearStartX  = 160.0f;   // 0x43200000
static const NSInteger kStonePoolSize = 50;   // 原版 0x31+1

// 石头类型（原版 G1_CustomSprite.type）
typedef NS_ENUM(NSInteger, TBStoneType) {
    TBStoneTypeRock = 1,
    TBStoneTypeStar = 8,   // 8 = 星星（checkHit 里特判加分）
};

@interface TBG1Stone : CCSprite
@property (nonatomic, assign) NSInteger lane;
@property (nonatomic, assign) TBStoneType kind;
@end

@implementation TBG1Stone
@end

@implementation TBG1GameLayer {
    CCSpriteBatchNode *_sheet;

    TBMovieClip *_bear;
    TBMovieClip *_background;
    TBMovieClip *_planet;
    TBMovieClip *_loadBar;
    TBMovieClip *_fire;
    TBMovieClip *_effect;

    NSMutableArray<TBG1Stone *> *_stones;
    NSInteger _nextStone;

    // 状态（对应原版 ivar）
    CGFloat _speed;
    CGFloat _score;
    NSInteger _topScore;
    CGFloat _generateCount;
    NSInteger _lastRanNum;
    NSInteger _currentCol;
    NSInteger _targetCol;
    NSInteger _bearAction;      // 0 静止 / 1 左移 / 2 右移
    BOOL _isGameOver;
    BOOL _isMouseDown;
    CGFloat _mouseX;

    CCLabelTTF *_scoreLabel;
    CCLabelTTF *_hintLabel;
    CCLabelTTF *_gameOverLabel;

    NSInteger _touchStartCol;
    CGPoint _touchStart;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.contentSize = [TBResolution designSize];
        self.anchorPoint = CGPointZero;
        self.userInteractionEnabled = YES;

        _stones = [NSMutableArray array];
        _speed = kBaseSpeed;
        _score = 0;
        _topScore = [[NSUserDefaults standardUserDefaults] integerForKey:@"game1_topScore"];
        _currentCol = 1;
        _targetCol = 1;
        _bearAction = 0;
        _lastRanNum = -1;
    }
    return self;
}

- (void)onEnter
{
    [super onEnter];
    [self buildScene];
    [self schedule:@selector(tick:) interval:1.0 / 60.0];
}

- (void)onExit
{
    [self unschedule:@selector(tick:)];
    [super onExit];
}

#pragma mark - 场景

- (void)buildScene
{
    CGSize d = self.contentSize;

    // 1. 图集
    [[CCSpriteFrameCache sharedSpriteFrameCache] addSpriteFramesWithFile:@"g1_game.plist"];
    _sheet = [CCSpriteBatchNode batchNodeWithFile:@"g1_game.png"];
    if (_sheet) [self addChild:_sheet z:0];

    // 2. 背景（1 clip / 3501 帧的长条滚动图，352x1002）
    //    原版把它放在 (0,0) 锚点左下，靠帧表里的 dy 做滚动。
    _background = [[TBMovieClip alloc] initWithSheet:_sheet zOrder:0];
    if ([_background loadTableNamed:@"G1_Background"]) {
        [_background buildSpritesWithZOrder:0];
        _background.baseX = 0;
        _background.baseY = 0;
        [self addChild:_background z:0];
        [_background gotoAndPlayFrame:1];
    }

    // 3. 星球装饰（2 clip）
    _planet = [[TBMovieClip alloc] initWithSheet:_sheet zOrder:1];
    if ([_planet loadTableNamed:@"G1_Planet"]) {
        [_planet buildSpritesWithZOrder:1];
        _planet.baseX = 0;
        _planet.baseY = 0;
        [self addChild:_planet z:1];
        [_planet gotoAndPlayFrame:1];
    }

    // 4. 小熊（30 clip / 182 帧，分部件拼装）
    //    原版 anchorX=47 / anchorY=72 是整体锚点（96x128 立绘的中心偏下），
    //    clipAnchorX/Y 全为 0/1 -> 每个部件锚点 (1,0) 即左下角，
    //    所以 baseX/baseY 就是「小熊脚底中心」的挂点。
    _bear = [[TBMovieClip alloc] initWithSheet:_sheet zOrder:5];
    if ([_bear loadTableNamed:@"G1_Bear"]) {
        [_bear buildSpritesWithZOrder:5];
        _bear.baseX = kBearStartX;
        _bear.baseY = kBearY;
        [self addChild:_bear z:5];
        [_bear gotoAndStopName:@"start"];
    }

    // 5. 尾焰（跟着小熊）
    _fire = [[TBMovieClip alloc] initWithSheet:_sheet zOrder:4];
    if ([_fire loadTableNamed:@"G1_Fire"]) {
        [_fire buildSpritesWithZOrder:4];
        _fire.baseVisible = NO;
        [self addChild:_fire z:4];
        [_fire gotoAndPlayFrame:1];
    }

    // 6. 撞击特效
    _effect = [[TBMovieClip alloc] initWithSheet:_sheet zOrder:6];
    if ([_effect loadTableNamed:@"G1_Effect"]) {
        [_effect buildSpritesWithZOrder:6];
        _effect.baseVisible = NO;
        [self addChild:_effect z:6];
    }

    // 7. 石头池：预创建精灵，用切换可见性复用
    //    注意必须用 alloc/init，工厂方法返回的是 CCSprite 而不是子类
    CCSpriteFrame *rockFrame = [[CCSpriteFrameCache sharedSpriteFrameCache]
                                spriteFrameByName:@"rock1.png"];
    for (NSInteger i = 0; i < kStonePoolSize; i++) {
        TBG1Stone *s = [[TBG1Stone alloc] initWithSpriteFrame:rockFrame];
        if (!s) continue;
        s.visible = NO;
        s.anchorPoint = CGPointMake(0.5f, 0.5f);
        [self addChild:s z:3];
        [_stones addObject:s];
    }

    // 8. 分数
    _scoreLabel = [CCLabelTTF labelWithString:@"000" fontName:@"Helvetica-Bold" fontSize:20];
    _scoreLabel.position = CGPointMake(d.width * 0.5f, d.height - 24);
    _scoreLabel.color = [CCColor colorWithRed:1 green:0.95f blue:0.4f alpha:1];
    [self addChild:_scoreLabel z:20];

    _hintLabel = [CCLabelTTF labelWithString:@"左右滑动换道 · 吃星星 +10 · 躲石头"
                                    fontName:@"Helvetica" fontSize:9];
    _hintLabel.position = CGPointMake(d.width * 0.5f, 22);
    _hintLabel.color = [CCColor colorWithRed:1 green:1 blue:1 alpha:0.7f];
    [self addChild:_hintLabel z:20];

    _gameOverLabel = [CCLabelTTF labelWithString:@"" fontName:@"Helvetica-Bold" fontSize:18];
    _gameOverLabel.position = CGPointMake(d.width * 0.5f, d.height * 0.55f);
    _gameOverLabel.color = [CCColor colorWithRed:1 green:0.3f blue:0.3f alpha:1];
    [self addChild:_gameOverLabel z:30];

    [[TBAudio sharedAudio] playBackgroundMusic:@"bgm.mp3" loop:YES];
}

#pragma mark - 主循环

- (void)tick:(CCTime)dt
{
    [_loadBar tick];
    [_background tick];
    [_planet tick];
    [_bear tick];

    // 尾焰跟随
    _fire.baseX = _bear.baseX;
    _fire.baseY = _bear.baseY - 82.0f;
    BOOL flying = !([_bear.currentLabel isEqualToString:@"start"] ||
                    [_bear.currentLabel isEqualToString:@"die"]);
    _fire.baseVisible = flying;
    [_fire tick];
    [_effect tick];

    if (_isGameOver) return;

    // 速度与分数随时间增长（原版：每帧 +0.003 / +0.1）
    _speed = MIN(_speed + 0.003f, kMaxSpeed);
    _score = MIN(_score + 0.1f, 999.0f);
    _scoreLabel.string = [NSString stringWithFormat:@"%03d", (int)_score];

    [self handleInput];
    [self updateBear];
    [self updateStones];
    [self checkHit];
}

#pragma mark - 输入

- (void)handleInput
{
    if (!_isMouseDown || _bearAction != 0) return;

    // 原版：把 x 按 gWidth/3 分档
    NSInteger col = (NSInteger)(_mouseX / (self.contentSize.width / 3.0f));
    col = MAX(0, MIN(2, col));

    if (col != _currentCol && _bearAction == 0) {
        _targetCol = col;
        _bearAction = (col > _currentCol) ? 2 : 1;
        [_bear gotoAndPlayName:(_bearAction == 2 ? @"right" : @"left")];
    }
}

- (void)updateBear
{
    if (_bearAction == 0) return;

    CGFloat targetX = kColX[_targetCol];
    CGFloat step = kColWidth * 0.5f * (_speed / kBaseSpeed) * 0.35f;

    if (_bearAction == 2) {
        _bear.baseX += step;
        if (_bear.baseX >= targetX) {
            _bear.baseX = targetX;
            _bearAction = 0;
            _currentCol = _targetCol;
            [_bear gotoAndPlayName:@"stay"];
        }
    } else {
        _bear.baseX -= step;
        if (_bear.baseX <= targetX) {
            _bear.baseX = targetX;
            _bearAction = 0;
            _currentCol = _targetCol;
            [_bear gotoAndPlayName:@"stay"];
        }
    }
}

#pragma mark - 石头

- (TBG1Stone *)dequeueStone
{
    for (NSInteger i = 0; i < (NSInteger)_stones.count; i++) {
        NSInteger idx = (_nextStone + i) % _stones.count;
        if (!_stones[idx].visible) {
            _nextStone = (idx + 1) % _stones.count;
            return _stones[idx];
        }
    }
    return nil;
}

- (void)spawnStones
{
    // 三条车道里随机留一条空道
    NSInteger freeLane;
    do {
        freeLane = arc4random_uniform(3);
    } while (freeLane == _lastRanNum);
    _lastRanNum = freeLane;

    for (NSInteger lane = 0; lane < 3; lane++) {
        if (lane == freeLane) continue;

        TBG1Stone *s = [self dequeueStone];
        if (!s) break;

        // 45% 星星，55% 石头
        BOOL isStar = (arc4random_uniform(100) < 45);
        NSString *frame = isStar ? @"donut_star.png" : @"rock1.png";

        // 切换精灵帧（3.5 的纹理是只读的，用 setSpriteFrame: 换）
        CCSpriteFrame *sf = [[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:frame];
        if (sf) {
            s.spriteFrame = sf;
        }
        s.kind = isStar ? TBStoneTypeStar : TBStoneTypeRock;
        s.lane = lane;
        s.anchorPoint = CGPointMake(0.5f, 0.5f);
        s.position = CGPointMake(kColX[lane], self.contentSize.height + 60.0f);
        // rock1 原始 124x126，缩到约 40pt；星星 34x32，缩到约 26pt
        s.scale = isStar ? 0.75f : 0.34f;
        s.visible = YES;
    }
}

- (void)updateStones
{
    _generateCount += _speed;
    if (_generateCount >= kColHeight) {
        _generateCount = 0;
        [self spawnStones];
    }

    CGFloat dy = _speed * 1.6f;
    for (TBG1Stone *s in _stones) {
        if (!s.visible) continue;
        s.position = CGPointMake(s.position.x, s.position.y - dy);
        if (s.position.y < -50) {
            s.visible = NO;
        }
    }
}

#pragma mark - 碰撞

- (void)checkHit
{
    // 小熊立绘 96x128，锚点 (47,72)。碰撞盒只取身体核心（不含耳朵/尾巴），
    // 原版判定比较宽松，这里再收窄一点，避免"擦边就死"。
    CGRect bearBox = CGRectMake(_bear.baseX - 20, kBearY - 26, 40, 52);

    for (TBG1Stone *s in _stones) {
        if (!s.visible) continue;

        // 石头按实际显示尺寸算，再收 30%（宽容判定）
        CGFloat w = MAX(s.contentSize.width * s.scaleX * 0.7f, 16);
        CGFloat h = MAX(s.contentSize.height * s.scaleY * 0.7f, 16);
        CGRect sb = CGRectMake(s.position.x - w * 0.5f,
                               s.position.y - h * 0.5f, w, h);
        if (!CGRectIntersectsRect(bearBox, sb)) continue;

        if (s.kind == TBStoneTypeStar) {
            s.visible = NO;
            _score = MIN(_score + 10.0f, 999.0f);
            _scoreLabel.string = [NSString stringWithFormat:@"%03d", (int)_score];
            [[TBAudio sharedAudio] playEffect:@"coin.wav"];
        } else {
            [self doGameOver];
            return;
        }
    }
}

- (void)doGameOver
{
    if (_isGameOver) return;
    _isGameOver = YES;

    [[TBAudio sharedAudio] playEffect:@"gameover.wav"];
    [_bear gotoAndPlayName:@"die"];

    _gameOverLabel.string = [NSString stringWithFormat:@"GAME OVER   %d", (int)_score];

    NSInteger sc = (NSInteger)_score;
    if (sc > _topScore) {
        _topScore = sc;
        [[NSUserDefaults standardUserDefaults] setInteger:sc forKey:@"game1_topScore"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }

    // 2 秒后返回选关
    __weak typeof(self) weakSelf = self;
    [self runAction:[CCActionSequence actions:
                     [CCActionDelay actionWithDuration:2.0],
                     [CCActionCallBlock actionWithBlock:^{
        __strong typeof(weakSelf) self2 = weakSelf;
        if (self2 && self2.onExit) self2.onExit();
    }],
                     nil]];
}

#pragma mark - 触摸

- (void)touchBegan:(CCTouch *)touch withEvent:(CCTouchEvent *)event
{
    if (_isGameOver) return;
    CGPoint p = [touch locationInNode:self];
    _isMouseDown = YES;
    _mouseX = p.x;
    _touchStart = p;
    _touchStartCol = _currentCol;

    // 起手就按车道判断一次
    NSInteger col = (NSInteger)(p.x / (self.contentSize.width / 3.0f));
    col = MAX(0, MIN(2, col));
    if (col != _currentCol && _bearAction == 0) {
        _targetCol = col;
        _bearAction = (col > _currentCol) ? 2 : 1;
        [_bear gotoAndPlayName:(_bearAction == 2 ? @"right" : @"left")];
    }
}

- (void)touchMoved:(CCTouch *)touch withEvent:(CCTouchEvent *)event
{
    if (_isGameOver) return;
    CGPoint p = [touch locationInNode:self];
    _mouseX = p.x;
}

- (void)touchEnded:(CCTouch *)touch withEvent:(CCTouchEvent *)event
{
    _isMouseDown = NO;
}

- (void)touchCancelled:(CCTouch *)touch withEvent:(CCTouchEvent *)event
{
    _isMouseDown = NO;
}

@end
