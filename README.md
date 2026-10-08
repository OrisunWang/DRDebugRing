# DRDebugRing

DRDebugRing 是用于 iOS Debug 构建的悬浮圆环。点击圆环可展示自定义调试页面，拖动圆环可吸附到屏幕边缘，点击面板外部可收起。

- 支持 iOS 13 及以上版本。
- 支持按 `UIWindowScene` 独立管理圆环。
- 支持 UIKit 页面、导航控制器和自定义调试操作。
- 支持触摸穿透、触感反馈、Reduce Motion 和 VoiceOver。
- 无第三方运行时依赖。

## 安装

在 Podfile 中仅为 Debug 配置引入：

```ruby
pod 'DRDebugRing', '~> 0.1.0', :configurations => ['Debug']
```

执行：

```sh
pod install --repo-update
```

在宿主 Target 的 **Debug** 构建配置中设置 `GCC_PREPROCESSOR_DEFINITIONS`：

```text
$(inherited) DEBUG_RING=1
```

Swift 项目的 Debug 配置同时使用 `DEBUG` 编译条件。Release 配置不定义 `DEBUG_RING`，也不导入或调用调试库。

使用自定义构建配置名时，需要配置 Podfile 的 Debug/Release 映射，并在对应 Pod target 中定义 `DEBUG_RING=1`。

## 接入

在宿主窗口显示后，传入自定义内容控制器和所属的 `UIWindowScene`。内容控制器必须尚未挂载到其他父控制器，所有接口都在主线程调用。

### Swift / UIKit

```swift
#if DEBUG
import DRDebugRing

// debugController 是应用提供的调试页面，可使用 UINavigationController 包装。
DRDebugRing.setupRing(
    withContentViewController: debugController,
    windowScene: windowScene
)

// 查询当前 Scene 的圆环并收起面板。
let ring = DRDebugRing.ringWindow(for: windowScene)?.debugRing
ring?.collapse(completion: nil)

// 不再需要圆环时卸载。
DRDebugRing.removeRing(for: windowScene)
#endif
```

### Objective-C

```objc
#ifdef DEBUG_RING
#import <DRDebugRing/DRDebugRing.h>

// debugController 是应用提供的调试页面。
[DRDebugRing setupRingWithContentViewController:debugController
                                  windowScene:windowScene];

// 查询当前 Scene 的圆环并收起面板。
DRDebugRing *ring = [DRDebugRing ringWindowForScene:windowScene].debugRing;
[ring collapseWithCompletion:nil];

// 不再需要圆环时卸载。
[DRDebugRing removeRingForScene:windowScene];
#endif
```

## 使用说明

- **展开与收起**：点击圆环展开，点击面板外部收起；也可调用 `expandWithCompletion:` 和 `collapseWithCompletion:`。
- **显示与隐藏**：调用 `showRing:` 或 `hideRing:`。隐藏时会先收起面板，恢复宿主窗口焦点并关闭覆盖窗口。
- **拖动与布局**：收起状态下可拖动圆环，松手后吸附到最近边缘。面板占安全区域的 80%，位置随窗口尺寸变化调整。
- **触摸穿透**：圆环收起时，圆环以外的触摸传递给宿主页面。
- **多窗口**：通过 `ringWindowForScene:` 查询指定 Scene。重复安装会替换该 Scene 的圆环；不带 Scene 的安装接口要求只有一个前台 Scene。
- **状态与通知**：`isCollapsed` 表示收起状态。展开或收起完成后发送 `DRDebugRingDidExpandNotification` 或 `DRDebugRingDidCollapseNotification`，通知的 `object` 为对应圆环。
- **动画与回调**：动画期间的新操作会被忽略，但仍调用 completion。需要判断实际状态变化时，使用状态属性或通知。
- **便捷查询**：`UIApplication.DR_debugRing` 返回唯一前台 Scene 的圆环；不存在或无法确定唯一 Scene 时返回 `nil`。

调试操作由应用自行实现，库只负责圆环及内容页面的展示。

## Example

仓库包含 Swift + UIKit 示例，最低支持 iOS 15。

```sh
git clone https://github.com/OrisunWang/DRDebugRing.git
cd DRDebugRing/Example
pod install
open DebugRingExample.xcworkspace
```

选择 `DebugRingExample` scheme，在 Debug 配置下运行：

1. 主页面按钮的计数初始为 0，每次点击加 1。
2. 点击圆环打开调试面板。
3. 点击“重置按钮计数”，主页面按钮的计数立即归零。
4. 关闭面板后可继续计数，也可拖动圆环调整位置。

每个 Scene 的计数独立。Release 构建只显示主页面计数按钮。

## License

MIT License，详见 [LICENSE](LICENSE)。
