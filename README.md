# NixOS · koru

`wallyhao@koru` 的 NixOS 与 Home Manager 配置。桌面使用 Niri，依赖版本由
`flake.lock` 固定。系统模块、用户软件和硬件身份分别管理，共享主题位于
[`system/theme.nix`](system/theme.nix)。

## 日常操作

以下命令在 NixOS 上、仓库根目录执行：

```sh
cd ~/.config/nixos

# 先求值，再构建；build 不激活系统
nix eval --raw .#nixosConfigurations.koru.config.system.build.toplevel.drvPath
sudo nixos-rebuild build --flake .#koru

# 构建成功后应用系统及内嵌的 Home Manager 配置
sudo nixos-rebuild switch --flake .#koru

# 只应用用户配置；不会安装系统侧的 Niri、输入法或驱动
home-manager switch --flake .#koru
```

本仓库没有 `justfile`；`home/just.nix` 仅安装 just 工具。
Git flake 只包含已登记的文件。新增或重命名文件后，先检查 `git status`，
使用 `git add --intent-to-add <新文件>` 使新路径参与本地求值，再审阅并提交。
不要用 `git add .` 覆盖尚未审阅的暂存选择。

## 目录与职责

| 位置 | 职责 |
| --- | --- |
| `flake.nix` | 输入、包集合、系统与用户配置输出、检查任务 |
| `flake.lock` | 锁定依赖版本；重构不应顺带更新 |
| `hosts/inventory.nix` | 主机名和 CPU 架构清单 |
| `hosts/koru/default.nix` | 主机模块入口、主机名与 stateVersion |
| `hosts/koru/hardware-configuration.nix` | 自动生成的设备、UUID、文件系统与硬件探测结果 |
| `hosts/koru/boot.nix` | 引导、initrd、内核参数及设备驱动屏蔽 |
| `hosts/koru/btrfs-mounts.nix` | Btrfs 压缩、访问时间及 TRIM 挂载策略 |
| `hosts/koru/locale.nix` | 时区、语言和键盘布局 |
| `hosts/koru/user-account.nix` | 用户、登录 shell、密码来源和 TTY 自动登录 |
| `system/default.nix` | **显式**系统模块清单 |
| `system/theme.nix` | 颜色、字体、光标、字号的共享数据；不是 NixOS 模块 |
| `home/default.nix` | Home Manager 基础配置、模块发现与开关校验 |
| `home/module-selection.nix` | 用户模块安装开关，一文件对应一个布尔值 |
| `home/<软件名>.nix` | 对应软件的安装和配置 |
| `home/niri/` | Niri 的启动器、空闲调光和快捷键 |
| `home/dotfiles/` | 由模块引用的非 Nix 文件 |
| `lib/module-discovery.nix` | 用户模块发现函数 |
| `lib/wmenu-style.nix` | 从共享主题生成 wmenu 参数 |
| `.github/workflows/check.yml` | 格式、静态检查和配置求值 CI |

`default.nix` 只用作目录入口，其职责由父目录限定；其他文件优先使用具体功能或软件名称。
系统模块可能在 `switch` 时立即影响服务，不等同于“只在开机生效”；用户模块也可能
包含长期运行的用户服务，不等同于“只在登录生效”。

## 系统模块索引

| 文件 | 管理内容 |
| --- | --- |
| `niri-session.nix` | Niri 的系统会话注册、portal 所需 FUSE 工具 |
| `display-power.nix` | 接电/电池下的屏幕亮度和刷新率，及 systemd 执行任务 |
| `console.nix` / `fonts.nix` | TTY 字体与调色板 / 字体安装和 fontconfig |
| `fcitx5-rime.nix` | Fcitx5、Rime 引擎和输入法环境变量 |
| `pipewire-audio.nix` | PipeWire、ALSA/Pulse 兼容和实时调度 |
| `intel-graphics.nix` | Intel 渲染、视频加速和 GuC 参数 |
| `gpu-screen-recorder.nix` | 录屏工具及其 KMS 权限包装器 |
| `bluetooth-disabled.nix` | 关闭蓝牙服务并阻断蓝牙射频 |
| `power-management.nix` | CPU 电源策略、thermald、UPower、Powertop 与 USB 例外 |
| `memory-zram.nix` | zram、内存回收参数和 systemd-oomd；禁止未经调整地添加磁盘 swap |
| `network-manager.nix` | NetworkManager、Wi-Fi 省电、DNS 和联网等待策略 |
| `mihomo.nix` | 按需启用的 TUN 全局代理和 `proxyctl` 命令 |
| `tcp-tuning.nix` | TCP、队列调度与 IPv4 防护参数 |
| `time-servers.nix` | NTP 服务器列表 |
| `github-hosts.nix` | 锁定版本的 GitHub 静态 hosts 覆盖 |
| `firewall.nix` | 应用入口端口；当前允许 TCP 8080 |
| `openssh-server.nix` | SSH 认证、服务与 TCP 22 防火墙入口 |
| `nix-daemon.nix` | Nix 缓存、信任、构建并行度和低磁盘空间清理阈值 |
| `nix-garbage-collection.nix` | 定时 GC、电源条件与手动升级策略 |
| `journal-limits.nix` | systemd journal 占用上限 |
| `zsh-login-shell.nix` | 系统层 Zsh 支持；交互配置在 `home/zsh.nix` |

## 主题与桌面

修改主题只编辑 `system/theme.nix`。它保持为纯数据，通过 flake 的
`specialArgs` / `extraSpecialArgs` 传给系统和用户层，**不放进系统 imports**。
Alacritty、GTK、光标、TTY、编辑器和菜单读取同一套语义颜色。

Niri 的文件分工：

- `system/niri-session.nix`：安装并注册系统会话。
- `home/tty-login.nix`：从 tty1 的登录 shell 启动 `niri-session`。
- `home/niri.nix`：布局、输入设备、窗口规则和启动程序。
- `home/niri/keybindings.nix`：快捷键映射，作为数据导入。
- `home/niri/application-launcher.nix`：按使用频率和时间排序的 wmenu 启动器。
- `home/niri/idle-dimming.nix`：空闲调光与恢复。
- `system/display-power.nix`：电源事件通过 udev 提交给 systemd；不在 udev 中执行长时间 IPC。

保留原有操作：Alt 为修饰键，Alt+方向键移动焦点，Alt+Shift+方向键移动窗口/列，
Alt+Tab 打开概览。亮度策略仍为电池 60%、接电 100%，刷新率在可用的
1920×1080 模式中选择最接近 60/144 Hz 的值；不是通用多显示器配置。

## 模块开关与新增文件

`home/module-selection.nix` 的键必须与 `home/` 直接子目录内的模块文件名一致，
去掉 `.nix` 后缀；`default.nix` 和 `module-selection.nix` 除外。值必须为布尔值。
缺少键、未知键或非布尔值会在求值时失败。

例如 `c-cpp-toolchain`、`java-toolchain`、`clipboard-history`、`cursor-theme`、
`tty-login`、`zen-browser` 均与同名文件对应。删除模块时同时删除对应开关。
`home/niri/` 的辅助文件由 `home/niri.nix` 导入，不会被顶层开关扫描。
开关控制模块导入，不保证应用间完全独立：禁用终端或启动器时也要检查 Niri 的快捷键。

新增系统模块时，将文件明确登记到 `system/default.nix`。
不要把数据或工具函数混入 imports；共享工具放到 `lib/`，设备专用策略放到 `hosts/koru/`。

## 更新、检查与回滚

```sh
# 更新之前审阅工作区；更新后审阅锁文件
git status --short
nix flake update                  # 或只更新：nix flake update github-hosts
git diff -- flake.lock

# 格式化所有 Nix 源文件
find . -path ./.git -prune -o -name '*.nix' -type f -exec nix fmt -- {} +
nix flake check --no-update-lock-file --print-build-logs
nix eval --raw .#homeConfigurations.koru.activationPackage.drvPath
nix eval --raw .#homeConfigurations.all.activationPackage.drvPath

# 回到上一个系统代际
sudo nixos-rebuild switch --rollback
```

`nixosConfigurations.koru` 包含系统和内嵌 Home Manager；`homeConfigurations.koru`
是独立用户配置；`homeConfigurations.all` 强制所有用户模块参与求值，供检查使用。
`nix flake check` 不会自动检查任意命名的 `homeConfigurations` 输出，所以 CI 单独求值它们。
语法检查、求值通过、构建成功和真实桌面运行正常是不同验证阶段。

回滚系统不会撤销仓库文件修改；独立 Home Manager 代际也有自己的生命周期。
GC 每天 03:15 执行，仅接电时运行，按现有策略清理七天前的代际；可回滚范围受此限制。
`system.stateVersion` 和 `home.stateVersion` 是兼容性基线，不随依赖更新而改动。

## 保留的本机策略

这次目录重构保留现有用户账号、密码来源、自动登录、SSH 访问策略、网络参数和软件选择。
`hosts/koru/password` 仍由 `user-account.nix` 读取；它是明文文件且会进入 Nix 求值数据，
不应把本仓库当作可直接公开发布的无秘密模板。

SSH 仍允许密码登录、禁用 root 登录；防火墙开放 22 和 8080。网络仍使用静态 DNS、
GitHub hosts 覆盖和原有 TCP 参数。未迁入此前 nixos2 的 Qtile 配置；Mihomo 使用独立的按需模块。

## 按需全局代理（Mihomo）

系统模块 `system/mihomo.nix` 安装 Mihomo TUN 服务和 `proxyctl`，默认不开机启动。
把一条 Mihomo/Clash 兼容的订阅链接填入
`~/.config/mihomo/subscription-url`（每文件只填一条链接）；该文件权限为 `0600`，
不纳入 Git 或 Nix store。代理运行配置不入库，写在 `/etc/mihomo/config.yaml`。

切换到这份 NixOS 配置后，在 NixOS 内执行：

```sh
proxyctl refresh   # 拉取订阅，逐个探测能否访问 google.com，生成可用节点表
proxyctl start     # 上下键选节点（回车确认），开启全局 TUN 代理
proxyctl status    # 服务是否运行 + 当前节点
proxyctl shutdown  # 关闭服务与 TUN
```

`refresh` 只保留能连 Google 的节点，按延迟排序、美国优先，结果写入
`~/.config/mihomo/nodes.tsv`；规范化后的订阅写入 `~/.config/mihomo/provider.yaml`，
由 systemd credential 交给 Mihomo，避免它在代理尚未工作时自己下载。
`start` 只列出这些可用节点，选中者作为全局出口。修改订阅链接后重新
`proxyctl refresh` 即可；启动失败可用 `journalctl -u mihomo -b` 查看原因。
