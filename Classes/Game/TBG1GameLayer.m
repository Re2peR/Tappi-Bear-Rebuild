//
//  TBG1GameLayer.m
//

#import "TBG1GameLayer.h"
#import "TBCompat.h"
#import "TBResolution.h"
#import "TBAudio.h"

// ---- 原版常量（从 initWithSheet / tick 反汇编还原）----
static const CGFloat kColX[3]     = {40.0f, 160.0f, 280.0f};  // 车道中心 x
static const CGFloat kBearY       = 140.0f;   // 0x430c0000
static const CGFloat kBearStartX  = 160.0f;   // 0x43200000
static const CGFloat kBaseSpeed   = 3.0f;     // 0x40400000 = 3.0
static const CGFloat kMaxSpeed    = 8.0f;     // 0x41000000
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

    CCSprite *_bgA;
    CCSprite *_bgB;
    CGFloat _bgScrollHeight;
    CCSprite *_bearSprite;

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

    // 2. 背景：bg.png 是 352x1002 的长条，两张上下拼接做无缝滚动
    [self buildBackground];

    // 3. 小熊：先用完整立绘 bear2.png（76x128），保证比例和朝向正确。
    //    30-clip 的部件拼装动画留到后续版本再启用。
    [self buildBear];

    // 4. 石头池
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

    // 5. 分数
    _scoreLabel = [CCLabelTTF labelWithString:@"000" fontName:@"Helvetica-Bold" fontSize:20];
    _scoreLabel.position = CGPointMake(d.width * 0.5f, d.height - 24);
    _scoreLabel.color = [CCColor colorWithRed:1 green:0.95f blue:0.4f alpha:1];
    [self addChild:_scoreLabel z:20];

    _hintLabel = [CCLabelTTF labelWithString:@"左右滑动换道 · 吃星星 +10 · 躲石头"
                                    fontName:@"Helvetica" fontSize:9];
    _hintLabel.position = CGPointMake(d.width * 0.5f, 22);
    _hintLabel.color = [CCColor colorWithRed:1 green:1 blue:1 alpha:0.7f];
    [self addChild:_hintLabel z:20];

    // GAME OVER 放分数正下方，避免和飞行中的星星/石头重叠
    _gameOverLabel = [CCLabelTTF labelWithString:@"" fontName:@"Helvetica-Bold" fontSize:16];
    _gameOverLabel.position = CGPointMake(d.width * 0.5f, d.height - 52);
    _gameOverLabel.color = [CCColor colorWithRed:1 green:0.35f blue:0.35f alpha:1];
    [self addChild:_gameOverLabel z:30];

    [[TBAudio sharedAudio] playBackgroundMusic:@"bgm.mp3" loop:YES];
}

#pragma mark - 背景（无缝滚动）

- (void)buildBackground
{
    CCSpriteFrame *bgFrame = [[CCSpriteFrameCache sharedSpriteFrameCache]
                              spriteFrameByName:@"bg.png"];
    if (!bgFrame) return;

    _bgA = [[CCSprite alloc] initWithSpriteFrame:bgFrame];
    _bgB = [[CCSprite alloc] initWithSpriteFrame:bgFrame];
    if (!_bgA || !_bgB) return;

    CGSize canvas = self.contentSize;
    if (canvas.width < 1 || canvas.height < 1) {
        canvas = [TBResolution designSize];
        self.contentSize = canvas;
    }
    CGFloat imgW = _bgA.contentSize.width;    // 352
    CGFloat imgH = _bgA.contentSize.height;   // 1002

    // 按画布宽度缩放
    CGFloat sx = canvas.width / imgW;         // 320/352 ≈ 0.909
    CGFloat scaledH = imgH * sx;              // ≈ 911

    // 用 (0,0) 锚点 + 左下角定位，坐标系最直观
    _bgA.anchorPoint = CGPointZero;
    _bgB.anchorPoint = CGPointZero;
    _bgA.scaleX = _bgA.scaleY = sx;
    _bgB.scaleX = _bgB.scaleY = sx;

    // A 从画布顶部往下铺，B 接在 A 下方
    _bgA.position = CGPointMake(0, canvas.height);
    _bgB.position = CGPointMake(0, canvas.height - scaledH);

    _bgScrollHeight = scaledH;

    [self addChild:_bgA z:-10];
    [self addChild:_bgB z:-10];
}

- (void)updateBackground
{
    if (!_bgA || !_bgB) return;

    CGFloat dy = _speed * 1.2f;
    CGFloat yA = _bgA.position.y - dy;
    CGFloat yB = _bgB.position.y - dy;

    // 画布顶部 = canvas.height。某张图的顶部越过画布底部（y < -scaledH）就重置到最上方。
    // 用「相对另一张」的方式重置，避免误差累积出接缝。
    CGFloat canvasH = self.contentSize.height;
    CGFloat limit = -_bgScrollHeight;

    if (yA < limit) {
        yA = yB + _bgScrollHeight;
    } else if (yB < limit) {
        yB = yA + _bgScrollHeight;
    }
    // 保险：两张都掉下去（极端帧率）时重新铺
    if (yA < limit && yB < limit) {
        yA = canvasH;
        yB = canvasH - _bgScrollHeight;
    }

    _bgA.position = CGPointMake(0, yA);
    _bgB.position = CGPointMake(0, yB);
}

#pragma mark - 小熊

- (void)buildBear
{
    CCSpriteFrame *f = [[CCSpriteFrameCache sharedSpriteFrameCache]
                        spriteFrameByName:@"bear2.png"];
    _bearSprite = [[CCSprite alloc] initWithSpriteFrame:f];
    if (!_bearSprite) return;

    // bear2 原始 76x128，缩到 57x96（设计画布 320x480 的合理角色尺寸）
    _bearSprite.scale = 0.75f;
    _bearSprite.anchorPoint = CGPointMake(0.5f, 0.0f);   // 脚底中心
    _bearSprite.position = CGPointMake(kBearStartX, kBearY);
    // 图集里 bear2 是上下颠倒存储的（cocos2d 1.x 的 textureRect 原点差异），
    // 用 flipY 翻回来
    _bearSprite.flipY = YES;
    [self addChild:_bearSprite z:5];
}

#pragma mark - 主循环

- (void)tick:(CCTime)dt
{
    [self updateBackground];

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

    // 把 x 按 gWidth/3 分档
    NSInteger col = (NSInteger)(_mouseX / (self.contentSize.width / 3.0f));
    col = MAX(0, MIN(2, col));

    if (col != _currentCol && _bearAction == 0) {
        _targetCol = col;
        _bearAction = (col > _currentCol) ? 2 : 1;
    }
}

- (void)updateBear
{
    if (_bearAction == 0) {
        _bearSprite.position = CGPointMake(kColX[_currentCol], kBearY);
        return;
    }

    CGFloat targetX = kColX[_targetCol];
    CGFloat step = 4.5f;

    if (_bearAction == 2) {
        _bearSprite.position = CGPointMake(_bearSprite.position.x + step, kBearY);
        if (_bearSprite.position.x >= targetX) {
            _bearSprite.position = CGPointMake(targetX, kBearY);
            _bearAction = 0;
            _currentCol = _targetCol;
        }
    } else {
        _bearSprite.position = CGPointMake(_bearSprite.position.x - step, kBearY);
        if (_bearSprite.position.x <= targetX) {
            _bearSprite.position = CGPointMake(targetX, kBearY);
            _bearAction = 0;
            _currentCol = _targetCol;
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
    // 生成间隔：原版 colHeight=200，但那是「累积距离」且每批 3 车道留 1 空。
    // 这里放宽到 320，让玩家有反应时间。
    _generateCount += _speed;
    if (_generateCount >= 320.0f) {
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
    // 小熊立绘 76x128 缩放 0.75 -> 57x96，锚点脚底中心
    CGRect bearBox = CGRectMake(_bearSprite.position.x - 20, kBearY + 10, 40, 56);

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
