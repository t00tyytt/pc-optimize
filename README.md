# pc-optimize — Windows 10/11 电脑体检 Skill（跨 agent 工具通用）

一个**跨 agent 工具通用**的 Windows 10/11 电脑优化排查 skill：**卡顿诊断 + 磁盘清理 + 流氓软件扫描 + 右键菜单管理**，自带右键菜单管理器工具，拿到任何 Windows 电脑上都能直接用。任何支持 SKILL.md 规范的 agent 工具（ZCode、Claude Code、Codex、Cursor 等）都能加载；不支持 skill 机制的工具，也可以把 SKILL.md 当操作手册直接喂给 agent。

## 它做什么

只要用户提到"电脑卡/卡顿/掉帧/开应用慢/开机慢"、"C盘D盘满了/清理磁盘/删垃圾文件"、"卸载软件/清残留/精简启动项/右键菜单/流氓软件"，或者只说一句"帮我看看这台电脑"——skill 就会触发，并严格走这套纪律：

**先诊断 → 列清单 → 经用户确认 → 动手 → 复查汇报。永远不先斩后奏。**

### 路线A：卡顿诊断（先排除法，再下结论）

- 资源快照并行采样：CPU/内存条/SSD 健康/显卡驱动日期/电源模式/磁盘忙闲/进程 TOP
- 判断顺序：内存瓶颈？磁盘瓶颈？都排除 → 软件层
- 常见元凶按实战命中率排序：失控后台服务（两次采样定位）、电源模式"最佳能效"坑、各品牌 OEM 性能档位误区（含联想/华硕/小米/华为等切换方式表）、ASPM 深度休眠、显卡驱动过旧、Insider 预览版、启动项臃肿

### 路线B：磁盘清理（快速清单，不做全盘扫描）

- 固定目标：Temp/浏览器缓存/包管理器缓存/Windows 更新缓存/回收站/休眠文件
- 微信/QQ 聊天数据是大头 → 引导改存储路径，**不删聊天记录**
- 卷影副本、WinSxS、pagefile 迁移等进阶项
- 删除纪律：✅可删 / 🤔用户决定 / ❌别删 三色清单；宝贵数据进回收站；删后复查

### 流氓/冗余软件扫描（体检时主动提醒）

- 三处 Uninstall 注册表键拉安装清单，按七类特征打标：弹窗资讯类、捆绑全家桶、假工具类、浏览器劫持（.lnk 挂网址参数）、静默新装、EOL 老软件、重复功能
- 命中后列 🤔 清单主动问，用户点名才卸；分不清正版山寨不提；运行库永远不进清单

### 右键菜单管理（自带工具，`tools/右键菜单管理器/`）

- 扫描 Win11 新菜单（MSIX IExplorerCommand）+ 经典二级菜单（shellex），逐项开/关
- 原理：往 `HKCU\...\Shell Extensions\Blocked` 按 CLSID 写值屏蔽/删值恢复——**免管理员、不删任何文件、完全可逆**
- 支持 Win10/11（Win10 没有"新菜单"层，经典项照常管理）
- 交互界面：双击 `右键菜单管理器.cmd`；命令行：`-List` / `-Toggle 名称或编号` / `-Off 3` / `-On "{GUID}"` / `-RestartExplorer`

### 软件卸载

- 有卸载器的走 [Geek Uninstaller](https://geekuninstaller.com/)（自带残留扫描）——见下方"关于 geek.exe"
- 无卸载器/卸后残留：注册表三处 Uninstall 键 + Run + 服务 + 计划任务 + 文件系统交叉判断，列清单后批量清

## 安装

skill 本体只是 `SKILL.md + tools/`，没有任何平台专属依赖。把 `pc-optimize/` 整个文件夹复制到你所用工具的 skill 目录：

| 工具 | 用户级目录 |
|---|---|
| ZCode / Codex 等遵循 agents 标准的 | `%USERPROFILE%\.agents\skills\pc-optimize` |
| Claude Code | `%USERPROFILE%\.claude\skills\pc-optimize` |
| 任意仓库（项目级） | `<repo>\.agents\skills\pc-optimize`（按各工具约定） |

```powershell
Copy-Item -Recurse pc-optimize "$env:USERPROFILE\.agents\skills\pc-optimize"
```

不支持 skill 机制的 agent 工具，直接把 SKILL.md 内容作为手册放进系统提示同样可用。

## 关于 geek.exe（未随仓库分发，skill 会自动下载）

skill 的卸载流程首选 [Geek Uninstaller](https://geekuninstaller.com/)。它是**闭源免费软件，本项目不打包分发**。

skill 运行时会自己处理：检查 `pc-optimize/tools/geek.exe`，缺失就从官网直链 `https://geekuninstaller.com/geek.zip`（约 3MB）下载解压到 `tools/`；下载失败则退回软件自带卸载器 + 手动残留清理，不影响其余流程。想手动放置也行：下载后把 `geek.exe` 放进 `pc-optimize/tools/`。

## 免责声明

- 本 skill 所有删除/停用操作都会先列清单经用户确认；但你仍然应该对自己的系统负责
- 改电源计划、停服务、删启动项前建议先记下原值（skill 会做，你手动操作时也请如此）
- 右键菜单管理器只写 HKCU 一个注册表键，随时可逆；其余操作建议先建系统还原点

## License

[MIT](LICENSE)
