# SignalBinder

> **[English](README.md)** — Read in English

可视化信号绑定编辑器。在编辑器中通过面板和下拉菜单配置，将 Godot 信号绑定到任意目标的方法上，无需手写连接代码。

## 安装

1. 将 `addons/SignalBinder` 复制到项目的 `addons/` 目录
2. **项目设置 → 插件** → 启用 `SignalBinder`
3. 启用后在编辑器主屏幕会添加 **IO 绑定表** 面板

## 快速开始

1. 添加一个 `IoBinder` 节点
2. `signal_owner` — 指定发出信号的节点（为空则默认为父节点）
3. 在 `iosets` 中添加绑定条目，选择绑定类型
4. 设置 `signal_name`（监听哪个信号）和 `method_name`（触发后调用哪个方法）
5. 运行场景即可

> Inspector 中 `signal_name` 和 `method_name` 会以下拉菜单展示，
> 自动读取信号源上的信号列表和目标对象的方法列表，无需手动输入。

## 信号源（IoSignalSource）

每个 IO 绑定默认使用 `IoBinder.signal_owner` 作为信号来源。
如果需要让某个绑定监听不同节点的信号，设置独立的 `signal_source`：

| 类型 | 说明 |
|------|------|
| `PARENT` | 使用 IoBinder 的 signal_owner（默认） |
| `NODE_PATH` | 指定一个节点路径作为信号源 |
| `AUTOLOAD` | 使用自动加载脚本（Singleton）作为信号源 |

设置后，Inspector 中的信号名下拉菜单会自动读取对应信号源上的信号列表。

## 绑定类型

| 类型 | 类名 | 说明 |
|------|------|------|
| **路径** | `IoBindPath` | 通过 `NodePath` 定位目标节点并调用方法 |
| **组** | `IoBindGroup` | 调用场景树中某个组内所有节点的指定方法 |
| **单例脚本** | `IoBindSingleton` | 调用脚本文件上的**静态**方法 |
| **全局自动加载** | `IoBindGlobal` | 调用自动加载脚本（Singleton）的**实例**方法 |
| **自身** | `IoBindSelf` | 调用信号所有者（`signal_owner`）自身的方法 |

> `IoBindGlobal` 通过 `Engine.get_singleton()` 获取自动加载实例，调用其实例方法；
> `IoBindSingleton` 调用的是脚本的静态方法 —— 两者适用场景不同。

## 通用属性（IoBindBase）

所有绑定类型共享以下配置：

| 属性 | 类型 | 说明 |
|------|------|------|
| `signal_source` | IoSignalSource | 可选，独立信号源定义（空 = 使用 IoBinder 的 signal_owner） |
| `signal_name` | String | 监听的信号名（Inspector 下拉选择） |
| `method_name` | String | 目标方法名（Inspector 下拉选择） |
| `parameters` | Array | 静态参数，在编辑器中配置的固定参数值 |
| `param_mode` | Enum | 参数组合模式（见下方） |
| `delay` | float | 延迟执行（秒），0 = 立即 |
| `fire_once` | bool | 仅触发一次后自动断开连接 |
| `condition_method` | String | 条件方法名：触发前先调用此方法，返回 false 时跳过执行 |
| `debug` | bool | 触发时在控制台打印 `[IoBind]` 调用日志 |

### ParamMode 参数模式

```
STATIC_ONLY     → 只传递静态参数（parameters）
SIGNAL_ONLY     → 只传递信号参数
APPEND_SIGNAL   → 静态参数 + 信号参数（信号参数拼在后面）
PREPEND_SIGNAL  → 信号参数 + 静态参数（信号参数拼在前面）
```

## IoBindMulti 多路绑定

`IoBindMulti` 是一个 Node 节点，用于在运行时动态管理多个独立绑定组。
每个绑定组由 `IoBindMultiConfig` 资源定义，指定各自的信号源路径和 IO 配置列表。

适合 UI 列表、动态生成的节点等场景。

## 编辑器面板（IO 绑定表）

主屏幕上的 **IO 绑定表** 面板提供以下功能：

- **列表展示** — 显示当前场景中所有 `IoBinder` 和 `IoBindMulti` 节点
- **展开/折叠** — 一键展开或折叠所有绑定条目
- **节点导航** — 点击条目中的节点名可跳转并在场景树中选中对应节点
- **资源编辑** — 点击条目中的编辑按钮可直接打开对应的 IoBindBase 资源
- **刷新** — 手动刷新列表
- **递归开关** — 项目设置 `SignalBinder/params/recursion` 控制是否递归搜索子场景

面板中每条绑定会显示信号源节点名、信号名、绑定类型及目标。

## 校验

`IoBinder` 节点上有一个 **"检测连接"** 按钮（编辑器下点击触发），逐一检查：
- `signal_owner` 是否有效
- 信号名在信号源上是否存在
- 方法名在目标上是否存在
- 节点路径是否可解析
- 组内是否有节点具备目标方法

## Inspector 下拉菜单

`IoBindBase` 和 `IoSignalSource` 在 Inspector 中会自动增强：

- **signal_name** — 自动读取信号源的信号列表，以下拉菜单展示（含参数预览）
- **method_name** — 自动读取目标对象的方法列表（去除非公开、去重、排序）
- **target_autoload / autoload_name** — 自动列出项目所有自动加载脚本
- 当前值为空时自动选中第一项
- 切换 `signal_source` 后信号列表自动刷新

## 项目设置

| 设置 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `SignalBinder/params/show_full_params` | bool | false | 下拉菜单中是否完整显示参数名 |
| `SignalBinder/params/recursion` | bool | false | 面板是否递归搜索子场景中的 IoBinder |

## 文件结构

```
addons/SignalBinder/
├── plugin.cfg                 # 插件配置
├── plugin.gd                  # EditorPlugin 入口
├── README.md                  # 英文文档
├── README_ZH.md               # 中文文档
├── data/
│   ├── io_bind_base.gd        # IoBindBase 抽象基类
│   ├── io_bind_path.gd        # IoBindPath（节点路径）
│   ├── io_bind_group.gd       # IoBindGroup（组）
│   ├── io_bind_singleton.gd   # IoBindSingleton（脚本静态方法）
│   ├── io_bind_global.gd      # IoBindGlobal（自动加载实例方法）
│   ├── io_bind_self.gd        # IoBindSelf（自身方法）
│   ├── io_signal_source.gd    # IoSignalSource（独立信号源定义）
│   ├── io_binder.gd           # IoBinder（主节点）
│   ├── io_bind_multi.gd       # IoBindMulti（多路绑定节点）
│   ├── io_bind_multi_config.gd# IoBindMultiConfig（多路绑定配置资源）
│   └── io_bind_executor.gd    # IoBindExecutor（运行时连接管理）
└── inspector/
	├── io_bind_inspector.gd   # EditorInspectorPlugin（下拉菜单增强）
	├── io_bind_dock.gd        # 主屏幕面板逻辑
	├── io_bind_dock.tscn      # 主屏幕面板场景
	├── io_connection.gd       # 单条绑定条目控件
	├── io_connection.tscn     # 单条绑定条目场景
	├── io_show.gd             # IoBinder/IoBindMulti 展示控件
	└── io_show.tscn           # 展示控件场景
```

## 许可证

MIT
