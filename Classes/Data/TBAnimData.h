// 自动生成，请勿手改。由 tools/gen_animdata.py 从反汇编数据生成。
// 源：animations.json（帧名/锚点/标签）+ frames.json（每帧 6 个变换量）

#import <Foundation/Foundation.h>

typedef struct {
    float dx, dy;          // 相对 baseX/baseY 的偏移
    float scaleX, scaleY;  // 相对 baseScale 的倍数
    float rotation;        // 相对 baseRotation 的角度增量
    float alpha;           // 绝对 alpha（0~255）
} TBFrameXform;

typedef struct {
    const char *name;                 // 类名，如 "G1_Bear"
    int clipCount;                    // numOfClip
    int totalFrames;                  // totalFrames
    int width, height;                // 设计尺寸
    int anchorX, anchorY;             // 整体锚点（像素）
    const char * const *clipNames;    // clipCount 个帧名
    const float *anchorXs;            // clipCount 个锚点 X（0~1）
    const float *anchorYs;            // clipCount 个锚点 Y（0~1）
    const char * const *labelNames;   // labelCount 个标签名
    const int *labelFrames;           // labelCount 个标签帧号
    int labelCount;
    const TBFrameXform *xforms;       // totalFrames * clipCount，行优先 [frame][clip]
} TBAnimTable;

/// 按类名查表；找不到返回 NULL。
const TBAnimTable *TBAnimTableForClass(const char *className);

/// 全部表（NULL 结尾）。
const TBAnimTable *TBAnimTables(void);

/// 表数量。
int TBAnimTableCount(void);
