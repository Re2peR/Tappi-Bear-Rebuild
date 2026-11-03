# Tappi Bear — 最新 iOS / 新设备分辨率适配

把 2010 年的 32 位 cocos2d-iphone 1.x 游戏 `Tappi Bear All in 1 v1.8` 移植成
**arm64 + 最新 iOS 可安装**的版本，并重做分辨率适配。

## 为什么必须重写

| 事实 | 后果 |
|---|---|
| 原包只有 armv6 / armv7s 两个 32 位切片 | iOS 11 起系统拒绝加载 32 位进程，**打补丁无解** |
| 引擎是 cocos2d-iphone 1.x（`setDeviceOrientation:` / `enableRetinaDisplay:` / `setIsTouchEnabled:` / `-hd` 后缀） | 必须换引擎或重写 |
| 依赖 `UIDevice.uniqueIdentifier`、`GKLeaderboardViewController`、`AudioSessionInitialize`、OpenAL、`wantsFullScreenLayout` | 全部在 iOS 7~16 之间被移除 |
| 设计画布 320×480 / 480×320，素材只有 @1x + @2x | 3x 设备上会被系统放大，必须重做缩放策略 |

## 方案

* **引擎**：cocos2d-objc **3.5.0**（Objective-C，OpenGL ES 2 + GLKit），vendored 在 `vendor/`
* **兼容层**：`Classes/Compat/TBCompat.*` 用 Category 把 1.x 选择子映射到 3.5，把 514 处 API 差异压到几十处真实编辑
* **分辨率**：`Classes/Layout/TBResolution.*` + `TBRootLayer.*`
  * 设计画布固定（320×480 / 480×320），所有反编译出来的硬编码坐标继续有效
  * 在安全区内等比缩放并居中（**letterbox，不裁切**）
  * 输出安全区 inset，HUD 避开刘海 / 灵动岛 / Home Indicator
  * `contentScaleFactor = UIScreen.scale`，3x 设备走原生 3 倍帧缓冲
* **音频**：`Classes/Audio/TBAudio.*` 用 AVAudioPlayer 替代 CocosDenshion
* **动画**：`Classes/Engine/TBMovieClip.*` 把 8 个游戏里 **94 个逐字节相同的 MovieClip 方法**合并成一个基类；
  帧序列/锚点/标签/每帧变换全部来自 `Classes/Data/TBAnimData.*`（反汇编还原，**85 个类 / 12647 条帧记录**）
* **CI**：GitHub Actions `macos-14`，编译 arm64 未签名 IPA + 模拟器冒烟 + 截图

## 目录

```
project.yml                     XcodeGen 工程定义
Resources/                      图集 / plist / 音频（从原 IPA 复用，已补 metadata）
Classes/
  App/                          main.m / TBAppDelegate / TBScene / TBBootContent
  Audio/                        TBAudio
  Compat/                       TBCompat（1.x -> 3.5 垫片）
  Data/                         TBAnimData（自动生成，勿手改）
  Engine/                       TBMovieClip（+ Data 分类）
  Layout/                       TBResolution / TBRootLayer
tools/                          make_ipa.py / verify_ipa.py
vendor/cocos2d-objc/            引擎 + ObjectAL + SSZipArchive + Chipmunk
.github/workflows/build.yml     CI
extracted/                      反汇编还原的中间数据（animations.json / frames.json）
```

## 构建

CI 是唯一能编译 arm64 的地方（本机是 Windows，没有 iOS SDK）。

```bash
# 本地（需要 macOS）
brew install xcodegen
xcodegen generate
xcodebuild -project TappiBear.xcodeproj -scheme TappiBear -sdk iphoneos -arch arm64 \
           CODE_SIGNING_ALLOWED=NO build
python3 tools/make_ipa.py build TappiBear-arm64-unsigned.ipa
python3 tools/verify_ipa.py TappiBear-arm64-unsigned.ipa
```

产物 `TappiBear-arm64-unsigned.ipa` 用 Sideloadly / AltStore 自签安装。

## 进度

- [x] **P0** 骨架 + 兼容层 + 动画数据 + CI
- [ ] **P1** 引擎兼容层联调（三比例布局验证）
- [ ] **P2** 123 个类骨架 + 完整动画表
- [ ] **P3** 外壳：AppDelegate / RootViewController / SelectGameLayer / Cover / Logo / Promo
- [ ] **P4** G1 全逻辑（样板游戏）
- [ ] **P5** 验收与交付（G2-G8 按模板批量套）

## 数据还原说明

`extracted/animations.json` 与 `extracted/frames.json` 是从 armv7s 切片静态还原的：

* 每个 `Gx_*` 类在 `initWithSheet:` 里写入 `clipNameList` / `clipAnchorX/Y` / `labelNameList` /
  `labelFrameList` / `numOfClip` / `totalFrames` / `width` / `height` / `anchorX` / `anchorY`；
* 帧变换表在 `gotoAndPlayFrame:` 里按
  `base + clip*24 + frame*(numOfClip*24) - 0xc` 取 6 个 float：
  `dx, dy, scaleX, scaleY, rotation, alpha`；
* 被链接器合并成 `_merged` 的 `labelNameList`，按「紧邻 `labelFrameList` 之前」定位。

这些数据经 `tools/validate_data.py` 校验：85 张表、50 组标签、69679 条帧记录、括号/字面量全部合法。
