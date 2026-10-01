<p align="center">
  <img src="assets/fastfetch/koru-logo.png" alt="Koru Logo" width="180" />
</p>

<h1 align="center">Koru · NixOS Configuration</h1>

<p align="center">
  续航优先 · 舒适阅读 · 清楚可控 · 分层维护
</p>

<p align="center">
  <a href="#简介">简介</a> ·
  <a href="#我为什么留下了-nixos-和-niri">系统与桌面</a> ·
  <a href="#续航优先">续航</a> ·
  <a href="#看得清比看得多重要">可读性</a> ·
  <a href="#干净可控说得清来由">整洁</a> ·
  <a href="#配置架构">架构</a> ·
  <a href="#硬件与系统策略">硬件策略</a>
</p>

## 简介

欢迎来看这份配置。这个仓库是我主力笔记本上在用的 NixOS + Home Manager 配置，跑在 `x86_64-linux` 上，桌面用 Niri。

我把日常使用的思路、仓库结构和维护方式都写在下面，希望给同样在折腾 NixOS 桌面的你一点参考。

这份配置参考了不少开源项目，特别感谢 `nyx`、`Misterio77`、`ryan4yin` 等项目的作者；具体来源都留在对应文件头部的 `Refs:` 注释里。

## 我为什么留下了 NixOS 和 Niri

Ubuntu、Debian、Kali、Arch、NixOS 我都用过。最早碰 NixOS，是因为在 Debian 上装桌面环境的时候被依赖冲突搞烦了；后来想换 Niri，搜资料的时候老刷到 NixOS，就想着干脆试试。

结果现在 NixOS 成了我最喜欢的发行版。我喜欢把系统设置直接写进配置里，也喜欢这种能查、能回滚的维护方式。

当然它也不是没缺点：装软件、用软件经常要多折腾一层，现成的包也未必能直接用。NixOS 的软件布局跟传统的 FHS（Filesystem Hierarchy Standard，文件系统层次结构标准）不一样，给 Debian 或者 Red Hat 系准备的安装包和预编译程序，基本都得适配一下才行，没法照搬。相关背景可以看 [NixOS 官方 Wiki 的说明](https://wiki.nixos.org/wiki/FAQ)。这些取舍到底值不值，得看每个人的工作习惯——至少对我来说，现在这收益是划算的。

桌面这边，i3、Awesome、Sway、GNOME、KDE Plasma、Hyprland、Niri 我都试过，最后停在 Niri。它那种滚动平铺特别适合我这块笔记本屏：开的窗口一多，已开的窗口不用为了全塞进一屏而拼命缩小，我可以直接移动视野去看想看的那个。

对我这种屏幕小、又习惯大字的人来说，这点尤其舒服，窗口操作也很符合直觉。桌面的资源占用我也在乎。就我自己的体验来说，Niri 在功能和占用之间平衡得挺好，不用怎么额外设置就够日常用了。

## 续航优先

### 这台机器

| 项目 | 配置 |
| --- | --- |
| 型号 | Lenovo Legion Y7000 IRX9（`83JJ`） |
| 处理器 | 13th Gen Intel Core i7-13650HX（6P + 8E，HWP / EPP 可用） |
| 内存 | 24 GB |
| 显示 | 1920×1080 面板，支持 60Hz 与 144Hz |
| 存储 | Btrfs（`/`、`/home`、`/nix` 子卷），无 swap 分区 |

我这台主力机是偏性能的游戏本，续航本来就不是它的强项。所以电池模式下，我愿意牺牲一点性能和刷新率，换更长的使用时间。

### 我的续航体验

下面这些数字，是我上课的时候用同一台机器、同一块电池随手记的。主要就是看文档、写点东西、浏览器查查资料，偶尔跑一两个 AI Agent，不编译；屏幕亮度一般 60% 左右。

| 系统 | 状态 | 大致续航 |
| --- | --- | --- |
| Windows | 开启省电模式 | 约 2.5 小时 |
| Ubuntu | 默认配置 | 约 1.5 小时 |
| NixOS（本配置） | 正常使用 | 约 4 小时 |

这些数字都是日常看的，没有严格统一的测试流程，当个个人体验参考就行。我真正在意的是：针对这台机器把电源策略调过之后，不带电源出门心里踏实多了。

### 我如何调整电源策略

有了 NixOS，这些调整我都能明确写进配置里，之后要查、要改、要重新部署都有据可依。我参考了 `nyx`、`Misterio77`、`ryan4yin` 这些项目里的做法，再按自己的硬件取舍，参考来源都留在对应文件头部的 `Refs:` 注释里。

目前主要是这几条策略：

- **CPU 调频**：`auto-cpufreq` 在电池下用 `powersave` + EPP `power`，频率上限设 3GHz 并关掉 turbo；接电用 `performance`，turbo 交给自动策略处理。我没额外设最低频率，留着空闲时降频的空间。
- **屏幕**：电池下亮度降到 60%、刷新率切到 60Hz；接电回到 100% 和 144Hz。切换是 udev 监听电源事件触发的。
- **热管理与音频**：启用 `thermald` 管热，音频编解码器从模块加载时就开省电。
- **设备电源管理**：开机跑 `powertop --auto-tune`，配好 USB 自动挂起、PCIe 运行时电源管理这些。
- **外设**：关掉我用不上的蓝牙无线电；罗技 2.4G 接收器留个例外，免得唤醒时第一次动鼠标卡一下。
- **其他系统设置**：Wi-Fi 节能、zram、Btrfs 压缩这些，见 [硬件与系统策略](#硬件与系统策略)。

我把这些策略集中在少数几个模块里，这样哪天觉得不合适，也好定位、好改。它们只适合我这台机器，换到别的硬件上还是得重新验证。

## 看得清比看得多重要

字号一小、界面一密，我看久了就累。对我来说，笔记本屏幕上最金贵的空间，应该留给正在看的内容。

### 干练、清楚的界面

我不喜欢花里胡哨的动画，比如鼠标或光标拖尾，也不喜欢毛玻璃。这些东西对我来说会干扰辨认命令和文字，看久了还容易审美疲劳。我就想要桌面干练、清楚，长时间盯着也舒服。

所以就着舒适阅读，我做了几个选择：

- **不要常驻状态栏**。我以前用 Waybar，但在这块屏幕上，做大了占地方，做小了又看不清。后来试着藏起来，发现还是需要的时候按一下 Btop 看一眼更合我习惯，于是当前版本干脆把状态栏彻底去掉了。
- **字放大**。终端和输入法用 Maple Mono NF CN，字号由 [system/theme.nix](system/theme.nix) 里的共享值 `16` 控制；Neovim 在终端里就直接跟着终端字体走。
- **用全屏模式多留点地方**。浏览器我主要用 Zen Beta，看中的就是它的全屏模式，进去之后界面元素收起来，能显示的区域更大。
- **柔和的深色主题**。用的是一套叫「Koru Fern」的绿灰配色，暗色背景配蕨绿和柔黄做强调，长时间看我比较习惯。
- **中英文都能兼顾的字体**。Maple Mono NF CN 在终端里也用来排中英文，代码和文字看着更协调。

这些取舍目标就一个：**让我看得更轻松**。字号、配色、界面密度这些也都随自己习惯调就行。

## 干净、可控、说得清来由

我说自己有电子洁癖，其实就一句话：不喜欢稀里糊涂的系统。一个软件为什么被装进来、一个设置从哪来、哪天不要它了该动哪个文件，我都想说得清。NixOS 的声明式配置正好合这个胃口，也让我一点点把日常维护理成了一套清楚的流程。

玩过 NixOS 之后我才发现，之前用过的那些发行版其实差别没那么大，也都没真正解决我的痛点。我最受不了的就是"没删干净"：以前要是配系统配炸了，我的解决办法就是删掉重装。

Ubuntu 这类发行版配置起来还特别散，有的要敲命令，有的要写配置文件，而敲命令配的东西又没什么记录，复现起来极其麻烦，有时候连我自己都忘了到底配没配。

换成 NixOS 之后，配置全集中了，我只要专心写配置：改了什么查一下就清楚；要删软件，把配置文件里的启用部分拿掉、重构一下就行；配炸了还能优雅回滚。这真的是我见过最优雅的系统。

具体到这份配置：

- **共用的东西集中定义**。颜色、字体、字号都由共享主题提供；用户模块开不开，统一在一张开关表里定。
- **托管范围说清楚**。系统包和托管的配置由仓库声明，把对应声明删掉再应用一遍，相应的安装或配置也就跟着变了；程序自己运行时产生的数据，还是归各自程序或者我自己管。
- **配置问题尽量早发现**。用户模块和开关是双向校验的，缺了、多了、依赖没满足，求值的时候就会报出来；`nix flake check` 还会跑一遍格式、静态分析和无用代码检查。
- **留好回退的路**。系统、用户配置和开发工具各自留代际，出问题能退回仍然保留的已知状态；定时 GC 会清掉超过保留期限的旧代际和没被引用的构建产物。
- **边界清楚**。哪些东西归 Nix 管、哪些是你自己的运行时数据，我在[版本管理边界](#版本管理边界)里逐条写明了，免得误以为回滚什么都能恢复。

这么理下来，维护的时候就安心多了：出问题我知道从哪儿查，也知道改一下会牵动哪些地方。

## 配置架构

为了让这份配置能跟着日常需求继续长，我把主机、系统、用户配置和开发工具分开维护。判断一个设置该放哪儿，我先看它管什么，再看它从哪个入口生效。

### 目录结构

```text
.
├── flake.nix                  # 输入、系统与用户输出、检查任务
├── flake.lock                 # 系统与用户配置依赖锁
├── hosts/
│   ├── inventory.nix          # 主机名称与架构
│   └── koru/                  # 本机专属：硬件、启动、电源、账户
├── system/                    # 显式导入的系统模块、共享主题
├── home/
│   ├── default.nix            # Home Manager 入口与模块校验
│   ├── modules-enables.nix    # 用户软件开关（唯一清单）
│   ├── <software>.nix         # 单软件模块
│   ├── niri/                  # 桌面辅助模块与快捷键数据
│   └── dotfiles/              # 模块引用的非 Nix 文件
├── profile/                   # 独立锁定的开发工具链
├── lib/                       # 模块发现、依赖规则与打包函数
├── scripts/                   # 构建、维护、模块编辑与代理逻辑
├── completions/               # 命令行补全
├── assets/                    # Logo 等静态资源
├── tests/                     # CLI、模块、代理与工具链验证
└── .github/workflows/         # 持续集成
```

### 分层职责

`hosts/` 放具体这台机器的设置，`system/` 管系统服务，这俩由 `nixos-rebuild` 一起应用。`home/` 管用户配置，既跟着系统一起应用，也能单独用 Home Manager 切换。开发工具放在 `profile/`，走独立的 Nix profile 更新。

桌面相关的东西也按这个边界拆：比如 Niri 的系统会话支持在 `system/`，窗口布局、快捷键和用户侧辅助服务在 `home/`。

| 层 | 管理内容 | 主要入口 |
| --- | --- | --- |
| 主机层 | UUID、文件系统、启动参数、设备、电源与账户 | [hosts/koru/default.nix](hosts/koru/default.nix) |
| 系统层 | 桌面会话、网络、音频、输入法后端、Nix 与系统服务 | [system/default.nix](system/default.nix) |
| 用户层 | 软件安装、桌面设置、Shell、应用配置与用户服务 | [home/default.nix](home/default.nix) |
| 开发工具层 | 编译器、运行时和开发命令的独立安装集合 | [profile/default.nix](profile/default.nix) |

[home/modules-enables.nix](home/modules-enables.nix) 是用户层的模块开关清单：一个模块对一个布尔开关，`true` 就启用，`false` 保留源码但不加载。它跟 `home/` 下直接包含的模块文件是双向校验的，哪边对不上，求值就会失败。嵌套目录里的辅助模块，由所属模块自己导入。

### Flake 输出

| 输出 | 用途 |
| --- | --- |
| `nixosConfigurations.koru` | 完整 NixOS 系统，包含嵌入式 Home Manager |
| `homeConfigurations.koru` | 可独立切换的用户配置 |
| `homeConfigurations.all` | 强制启用全部用户模块，用于检查 |
| `devShells.x86_64-linux.default` | Nix 格式化与静态检查工具 |
| `checks.x86_64-linux.*` | 格式、静态分析、无用代码与代理 VM 检查 |
| `profile/` 中的 `packages.x86_64-linux.dev-tools` | 独立开发工具集合 |

### 版本管理边界

| 内容 | 管理方式 |
| --- | --- |
| 系统包、Home Manager、Zen Browser、OpenCode 等 Flake 输入 | 根目录 `flake.lock` |
| 开发工具与 ROS overlay | `profile/flake.lock` |
| Codex CLI | Home Manager 激活时从 npm 的 `latest` 安装 / 更新到私有 prefix |
| Neovim 的其余插件与用户配置 | 用户自行维护 |
| 代理订阅、缓存、工具认证、项目依赖 | 各自的本地文件或项目配置 |

这个边界我盯得比较紧：Nix generation 回滚主要恢复的是对应那层的构建产物和托管配置；npm 装的软件、用户运行时数据还有 Git 工作区，都得单独管。这样回滚之前，我就知道到底哪些东西会被恢复。

## 统一主题

共用的颜色、字体、字号和光标设置我都集中在 [system/theme.nix](system/theme.nix)，作为纯数据通过 `specialArgs` / `extraSpecialArgs` 传给系统和用户两层。Kitty、GTK、光标、TTY、Neovim 主题、菜单这些各自去读自己需要的，调共享主题时就有这么一个明确的入口。

「Koru Fern」用偏暗的绿灰背景，拿蕨绿和柔黄去突出焦点和少量强调元素。

| 语义 | 当前颜色 |
| --- | --- |
| 主背景 `bg` | `#171E1A` |
| 次级背景 `bg-alt` | `#222D26` |
| 正文 `fg` | `#D2DCD0` |
| 主强调 `accent` | `#8FBF88` |
| 黄色强调 `accent-yellow` | `#E6D87A` |
| 选择背景 `accent-bg` | `#334936` |
| 非活动边框 `border` | `#425347` |

字号也在这儿集中定义：终端和输入法用 `16`，GTK 控件 `11`，菜单这类小界面 `12`。各组件有自己的字号单位，我就用共享设置把整体观感稳住，再按实际看着的效果微调。

顶部 logo 直接引用 [assets/fastfetch/koru-logo.png](assets/fastfetch/koru-logo.png)，跟 Fastfetch 用的是同一张透明 PNG，来源说明见 [assets/fastfetch/README.md](assets/fastfetch/README.md)。

## 硬件与系统策略

主要硬件和系统策略我整理在下面，方便对着源码看。这些都是在我的笔记本上做的选择，你要是借鉴，记得结合自己的硬件和使用习惯调。

| 范围 | 当前策略 | 配置入口 |
| --- | --- | --- |
| 显示 | 电池亮度 60%，交流电 100%；在可用 1920×1080 模式中选择最接近 60 / 144 Hz 的刷新率 | [hosts/koru/display-power.nix](hosts/koru/display-power.nix) |
| 空闲显示 | 5 分钟调暗至不高于 10%，10 分钟关闭显示器；活动恢复之前保存的亮度，不自动休眠 | [home/niri/idle-dimming.nix](home/niri/idle-dimming.nix) |
| 电源 | CPU、电热管理、UPower、Powertop 与 USB 例外 | [hosts/koru/power-management.nix](hosts/koru/power-management.nix) |
| 图形 | Intel 渲染、视频加速与 GuC 参数 | [hosts/koru/intel-graphics.nix](hosts/koru/intel-graphics.nix) |
| 蓝牙 | 关闭蓝牙服务并阻止无线电 | [hosts/koru/bluetooth.nix](hosts/koru/bluetooth.nix) |
| 文件系统 | Btrfs 压缩、访问时间与 TRIM 策略 | [hosts/koru/btrfs-mounts.nix](hosts/koru/btrfs-mounts.nix) |
| 内存 | zram、内存回收参数与 systemd-oomd | [system/memory-zram.nix](system/memory-zram.nix) |
| 网络 | NetworkManager、静态 DNS、Wi-Fi 节能与固定版本的 GitHub hosts | [system/network-manager.nix](system/network-manager.nix)、[system/github-hosts.nix](system/github-hosts.nix) |
| 录屏 | GPU Screen Recorder 与 KMS 权限包装 | [system/gpu-screen-recorder.nix](system/gpu-screen-recorder.nix) |
| Nix | 国内镜像与官方缓存回退，构建并行度和低磁盘空间回收阈值 | [system/nix-daemon.nix](system/nix-daemon.nix) |
| 日志与清理 | Journal 容量限制、每日 GC、手动依赖升级 | [system/journal-limits.nix](system/journal-limits.nix)、[system/nix-garbage-collection.nix](system/nix-garbage-collection.nix) |

显示那套是专门给内置面板设计的，不是通用的多显示器配置。空闲调暗会保留本来更低的亮度；开机和插拔电源的时候，会重新套用对应的电源策略。

## 日常工作流

这台电脑基本就是我的课程学习、日常开发和 ROBOCON 的活儿。我主要用 Python 和 Rust，平时就泡在终端、浏览器和编辑器里，别的工具按需打开。

| 场景 | 说明 |
| --- | --- |
| 终端和项目导航 | Kitty + Zsh，配上 Fzf / Fd / Ripgrep / Zoxide 做模糊选择、找文件、搜内容、跳目录；Bat / Eza 负责把文件预览和目录展示得好看点。 |
| 编辑器和 AI | Neovim 走 Nix 装，设好 `EDITOR` / `VISUAL`，再生成一个跟共享主题衔接的 `nvim/lua/p10k.lua`；剩下 Neovim 的配置和插件我自己维护。Codex CLI 和 OpenCode 各管各的，主题跟 Koru Fern 对上，认证和会话数据都交给工具自己管。 |
| 文档和图片 | 网页用 Zen Browser，PDF 用 Zathura，办公文档交给 LibreOffice，画图用 Draw.io，看图用 imv。启用 LibreOffice 的时候还会给个 `topdf`，转换时用临时 profile，免得跟已经开着的办公软件打架。 |
| 中文输入 | Fcitx5 + Rime，配雾凇拼音。轻按左右 Shift 会提交原始拉丁编码并切到 ASCII，在中文和代码之间切比较顺手；框架层的输入法切换另说。 |
| 开发工具 | Rust、C/C++、Java、Node.js、Python 工具、MPI、ROS 2、Typst、Just 都放在独立 profile 里，更新的时候不用重建系统。完整清单和更新方式见 [profile/README.md](profile/README.md)。 |

## 维护与回滚

日常维护主要靠仓库给的 `koru` CLI。改东西的时候用共享锁避免并发冲突，操作日志写到 `${XDG_STATE_HOME:-$HOME/.local/state}/koru/operation.*.log`，出问题从日志接着查。

| 范围 | 检查 | 应用 | 历史 |
| --- | --- | --- | --- |
| 系统与嵌入式用户配置 | `koru system check` | `koru system build` | `koru system list` |
| 独立用户配置 | `koru home check` | `koru home build` | `koru home list` |
| 开发工具 | `koru profile check` | `koru profile build` | `koru profile list` |

我一般先跑一下对应的 `check`，确认能构建成功，再用 `build` 应用。这里的 `check` 是真会构建，但不激活、也不建 `result` 链接；它跟跑全套 Flake 检查的 `nix flake check` 不是一回事。

要回滚的话，先用对应的 `list` 看看还留着哪些代际，再指定 ID。比如：

```sh
koru system rollback --generation <ID>
koru home rollback --generation <ID>
koru profile rollback --generation <ID>
```

把 `<ID>` 换成列表里实际的代际编号。系统回滚会顺带更新默认启动代际。定时 GC 每天 `03:15` 清超过七天的旧代际，所以想长期留着的东西，最好另外给它留个明确的 GC root。

用户模块也能用 CLI 看和调：

```sh
koru home modules
koru home enable <模块名>
koru home disable <模块名>
koru home validate
```

开关改完，还是得跑 `koru home build` 或 `koru system build` 才生效。代理管理、存储清理这些命令看 `koru --help`。

加新用户模块的时候，要同时加 `home/<software>.nix` 和 `modules-enables.nix` 里的同名开关，需要的话再登记模块依赖，不然求值会失败。加系统模块就在 `system/default.nix` 里显式导入。

## 部署与迁移

这套配置是围着我的主力机一点点整理出来的，仓库里没有通用的磁盘分区，也没有从零装机的流程。你要是想借鉴，我建议从自己需要的模块下手：省电策略、主题、用户模块管理、独立的开发工具 profile，各自都有入口。

要是想整套迁移，下面这些地方得按目标机器核对：

| 内容 | 位置与说明 |
| --- | --- |
| 用户名、输出构造 | [flake.nix](flake.nix) 中的 `username` 等定义 |
| 主机名与架构 | [hosts/inventory.nix](hosts/inventory.nix) 及对应 `hosts/<name>/` 目录 |
| 硬件识别与文件系统 | 使用目标机器生成的 `hardware-configuration.nix`，核对 UUID 与挂载点 |
| 启动与设备策略 | `hosts/koru/boot.nix`、`intel-graphics.nix`、`btrfs-mounts.nix` |
| 显示与电源 | `display-power.nix`、`power-management.nix`，按目标硬件调整 |
| 用户与登录 | `user-account.nix` 当前使用本地密码文件、不可变用户和 tty1 自动登录 |
| 网络与 SSH | 当前允许 SSH 密码登录、禁止 root 登录，开放 TCP 22 与 8080 |
| 仓库路径与管理命令 | 默认 `~/.config/nixos`；`koru` 操作当前针对 `koru` 输出 |
| 软件选择 | [home/modules-enables.nix](home/modules-enables.nix) |

账户配置现在是从本地 `hosts/koru/password` 读明文密码的，这是我给这台单用户机器留的个人选择，迁移的时候按你自己的账户需求改。代理订阅和工具认证用的是独立的本地文件，仓库里不提供。

系统依赖由根目录 `flake.lock` 固定，开发工具由 `profile/flake.lock` 单独固定，正常构建不会自动更新锁文件。

## 检查与持续集成

为了让这份配置长期维护时能早点发现问题，我在 [CI 工作流](.github/workflows/check.yml) 里安排了这些检查：

| 检查 | 覆盖内容 |
| --- | --- |
| Nix 静态检查 | Nixfmt、Statix、Deadnix |
| 配置求值 | 系统输出、独立用户输出与全部用户模块 |
| Shell 与 CLI | ShellCheck、命令契约、模块编辑、代理与 profile 测试 |
| 代理 VM | 真实 sudo 授权、systemd credential、TUN 启停、成功刷新及失败恢复，使用本地 HTTP fixture |
| 开发工具 | 编译、链接与运行样例，涵盖 Rust、C/C++、Java、Node、Python 工具、MPI、ROS、Typst、Just |
| 完整构建 | NixOS 系统 closure 与独立 Home Manager 激活包 |

这些检查能帮我发现源码、求值和构建上的问题。真正的桌面体验还得在本机确认，比如物理显示器切换、输入法按键、真实网络订阅这些；CI 不会去激活笔记本的配置。

## 常见问题

### 禁用了用户模块，软件为什么还在？

这软件可能是系统层或别的模块依赖装进来的。用户模块开关只管对应的 Home Manager 模块，不会删用户数据，也撤不掉其他层的安装。

### 为什么改完只跑 `koru home build` 还不生效？

先看这改动属于哪层。系统服务、硬件配置、组权限、桌面后端这些得系统切换；用户应用设置归 Home Manager 管。正在跑的程序可能还得重载、重启或者重新登录。

### 回滚后，源码和某些软件版本为什么没变？

回滚恢复的是保留下来的 profile generation，不动 Git 工作区；npm 装的和用户自己管的数据也不会跟着 generation 自动回滚。见[版本管理边界](#版本管理边界)。

### 为什么找不到之前的代际了？

旧代际可能被定时 GC 清掉了。先看对应 `list` 的输出再挑实际存在的 ID；想长期留着的开发环境应该设个明确的 GC root。

### 想借鉴这套配置，从哪儿下手？

从你最关心的部分开始就行：省电看[硬件与系统策略](#硬件与系统策略) 和 `hosts/koru/`，阅读体验看[统一主题](#统一主题)，模块组织看[配置架构](#配置架构)。我把选择理由尽量留在文档和源码注释里了，希望你能更容易判断哪些适合自己，再做自己的取舍。
