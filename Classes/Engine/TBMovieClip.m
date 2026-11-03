//
//  TBMovieClip.m
//

#import "TBMovieClip.h"
#import "TBAnimData.h"
#import "TBCompat.h"

@implementation TBMovieClip {
    NSMutableArray<CCSprite *> *_sprites;
    NSInteger _zOrder;
}

- (instancetype)initWithSheet:(CCSpriteBatchNode *)sheet zOrder:(NSInteger)z
{
    self = [super init];
    if (self) {
        _sheet = sheet;
        _zOrder = z;
        _sprites = [NSMutableArray array];
        _currentFrame = 1;
        _baseScaleX = 1.0f;
        _baseScaleY = 1.0f;
        _baseAlpha = 1.0f;
        _baseVisible = YES;
        _isPlay = NO;
        _clipNameList = @[];
        _clipAnchorX = @[];
        _clipAnchorY = @[];
        _labelNameList = @[];
        _labelFrameList = @[];
        self.contentSize = CGSizeZero;
        self.anchorPoint = CGPointMake(0, 0);
    }
    return self;
}

#pragma mark - 建精灵

- (void)buildSpritesWithZOrder:(NSInteger)zOrder
{
    _zOrder = zOrder;
    [_sprites removeAllObjects];

    NSUInteger n = _clipNameList.count;
    for (NSUInteger i = 0; i < n; i++) {
        NSString *frameName = _clipNameList[i];
        CCSprite *sp = nil;
        if (frameName.length) {
            sp = [CCSprite spriteWithSpriteFrameName:frameName];
        }
        if (!sp) {
            // 帧名缺失时补一个空精灵，保证索引与 clipNameList 对齐。
            sp = [CCSprite spriteWithImageNamed:@"white_blank.png"];
        }
        sp.visible = NO;
        sp.anchorPoint = [self anchorForClipIndex:(NSInteger)i];
        if (_sheet) {
            [_sheet addChild:sp z:zOrder];
        } else {
            [self addChild:sp z:zOrder];
        }
        [_sprites addObject:sp];
    }

    self.contentSize = CGSizeMake(_width, _height);
}

- (CGPoint)anchorForClipIndex:(NSInteger)i
{
    float ax = 0.5f, ay = 0.5f;
    if (i >= 0 && i < (NSInteger)_clipAnchorX.count) ax = _clipAnchorX[i].floatValue;
    if (i >= 0 && i < (NSInteger)_clipAnchorY.count) ay = _clipAnchorY[i].floatValue;
    // 原版是 setAnchorPoint:(1 - clipAnchorX, 1 - clipAnchorY)
    return CGPointMake(1.0f - ax, 1.0f - ay);
}

#pragma mark - 帧控制

- (void)gotoAndPlayFrame:(NSInteger)frame
{
    [self applyFrame:frame];
    _isPlay = YES;
}

- (void)gotoAndStopFrame:(NSInteger)frame
{
    [self applyFrame:frame];
    _isPlay = NO;
}

- (void)gotoAndPlayName:(NSString *)name
{
    [self gotoAndPlayFrame:[self frameForLabel:name]];
}

- (void)gotoAndStopName:(NSString *)name
{
    [self gotoAndStopFrame:[self frameForLabel:name]];
}

- (NSInteger)frameForLabel:(NSString *)name
{
    if (!name.length) return _currentFrame;
    NSUInteger n = MIN(_labelNameList.count, _labelFrameList.count);
    for (NSUInteger i = 0; i < n; i++) {
        if ([_labelNameList[i] isEqualToString:name]) {
            _currentLabel = name;
            return _labelFrameList[i].integerValue;
        }
    }
    return _currentFrame;
}

- (void)stop { _isPlay = NO; }
- (void)play { _isPlay = YES; }

- (void)applyFrame:(NSInteger)frame
{
    if (frame < 0) frame = 0;
    _currentFrame = frame;

    const TBFrameXform *row = NULL;
    if (_frameTable && _frameClipCount > 0 && frame < _totalFrames) {
        row = (const TBFrameXform *)_frameTable + (size_t)frame * (size_t)_frameClipCount;
    }

    for (NSUInteger i = 0; i < _sprites.count; i++) {
        CCSprite *sp = _sprites[i];
        if (!_baseVisible) {
            sp.visible = NO;
            continue;
        }
        sp.visible = YES;

        // 没有帧表时用 base 值（静态精灵）；有帧表时严格按表。
        float dx = 0, dy = 0, sx = 1, sy = 1, rot = 0, alpha = 0;
        if (row && (NSInteger)i < _frameClipCount) {
            const TBFrameXform *x = &row[i];
            dx = x->dx;
            dy = x->dy;
            sx = x->scaleX;
            sy = x->scaleY;
            rot = x->rotation;
            alpha = x->alpha;
        }

        sp.position = CGPointMake(_baseX + dx, _baseY + dy);
        sp.scaleX = _baseScaleX * sx;
        sp.scaleY = _baseScaleY * sy;
        sp.rotation = _baseRotation + rot;
        // 原版：setOpacity:(frameAlpha + baseAlpha)，取值 0~255。
        float a = (alpha + _baseAlpha) / 255.0f;
        sp.opacity = MAX(0.0f, MIN(1.0f, a));
    }

    [self didEnterFrame:frame];
}

#pragma mark - 每帧推进

- (void)tick
{
    if (!_isPlay) return;

    NSInteger next = _currentFrame + 1;

    // 跳过标签帧（原版行为：标签帧只是跳转目标，不作为动画帧播放）。
    BOOL skipped = YES;
    NSInteger guard = 0;
    while (skipped && guard++ < 64) {
        skipped = NO;
        for (NSUInteger i = 0; i < _labelFrameList.count; i++) {
            if (_labelFrameList[i].integerValue == next) {
                next += 1;
                skipped = YES;
                break;
            }
        }
    }

    if (next >= _totalFrames) {
        _isPlay = NO;
        [self onLastFrame];
        return;
    }
    [self applyFrame:next];
}

#pragma mark - 默认实现

- (void)didEnterFrame:(NSInteger)frame { /* 子类覆盖 */ }
- (void)onLastFrame { /* 子类覆盖 */ }

#pragma mark - 查询

- (CCSprite *)spriteAtIndex:(NSInteger)index
{
    if (index < 0 || index >= (NSInteger)_sprites.count) return nil;
    return _sprites[index];
}

- (NSInteger)spriteCount { return (NSInteger)_sprites.count; }

@end
