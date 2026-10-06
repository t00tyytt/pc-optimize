---
name: pc-optimize
description: Windows 10/11 电脑卡顿排查与磁盘清理的完整流程，自带 Geek 卸载器和右键菜单管理器，拿到任何电脑上都能直接用。只要用户提到电脑卡/卡顿/掉帧/开应用慢/开机慢，或C盘D盘满了/清理磁盘/删垃圾文件/释放空间，或要卸载软件/清残留/精简启动项/右键菜单/流氓软件/捆绑全家桶/弹窗/电脑优化提速，或只说"帮我看看这台电脑/做个电脑体检"——即使用户只说了其中一部分也要触发。涵盖：资源快照排除法、失控服务/电源模式/ASPM等常见元凶、软件卸载与注册表残留清理、流氓软件识别、扫描判断方法、删除纪律，体检时主动询问右键菜单去留和可疑软件卸载。
---

# 电脑优化排查

两条主线：**卡顿诊断**（性能问题）和**磁盘清理**（空间问题）。用户常混着说（"电脑卡"可能实指磁盘满了），先用数据判断再选路线。完整体检（用户没有具体主诉，只说"帮我看看这台电脑"）时，两条主线之外再加两个**主动扫描、主动询问**的动作：右键菜单精简和流氓软件排查（见路线B末两节）——只列清单问用户，不代答不代做。所有动作共用同一纪律：**先诊断 → 列清单 → 经用户确认 → 动手 → 复查汇报**。

## 铁律（先读这里）

1. **先诊断后动手**：拿数据说话（进程/磁盘/内存采样），排除法定位，不凭感觉优化。常见结局：电脑"很卡"查出来是软件层（失控服务 + 电源模式），硬件根本不弱——先采样再下结论。
2. **删除/停用前列清单经用户确认**：输出 ✅可删 / 🤔用户决定 / ❌别删 三类清单，用户点头才执行。用户说过"其余别动"就真的别动。
3. **先查本机历史再动手**：如果这台机器有过往的清理/排查记录（记忆文件、笔记），先读勿删清单和遗留待办，避免重复劳动或误删。

## 路线A：卡顿诊断

### 第一步：资源快照（并行跑一组 PowerShell）

- 硬件规格：CPU 型号/核数（Win32_Processor）、内存条数与频率（Win32_PhysicalMemory，单通道会拖累核显）、SSD 类型与健康（Get-PhysicalDisk）、显卡驱动日期（Win32_VideoController）、系统版本（Win32_OperatingSystem.Caption）
- 内存压力：FreeRAM、Win32_PerfFormattedData_PerfOS_Memory 的 PercentCommittedBytesInUse（>85% 才算内存瓶颈）
- 磁盘忙闲：Win32_PerfFormattedData_PerfDisk_PhysicalDisk 的 PercentIdleTime/队列长度（SSD 健康 + 空闲率高 → 磁盘无恙）
- 实时 TOP：Win32_PerfFormattedData_PerfProc_Process 按 PercentProcessorTime 排序（单进程 >100 = 占满多核）；Get-Process 按 WS 排序看内存大户
- 电源：`HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes` 的 ActivePowerScheme 和 ActiveOverlayAcPowerScheme、开机时长（LastBootUpTime）、台式还是笔记本、是否插电

判断顺序：内存瓶颈？磁盘瓶颈？都排除后 → 问题在软件层，进入第二步。

### 第二步：常见元凶（按实战命中率排序）

1. **失控后台服务**：某个服务/进程持续占满 1 个核（间隔几秒两次采样都满载 = 失控，不是正常工作）。实战案例：手机助手的同步服务（VivoSyncService 类）疯转。处理：确认用户是否还用该软件 → 正规卸载；残留僵尸服务（文件已删但服务还在）用管理员 `sc stop` + `sc delete` 注销。
2. **电源模式被设为"最佳能效"**：读 ActiveOverlayAcPowerScheme——`961cc777-2547-4f9d-8174-7d86181b8a7a`=最佳能效（压性能，"开应用慢+动画掉帧"的主因）、`00000000`=平衡、`ded574b5-45a0-4f42-8737-46345c09c238`=最佳性能。修法：设置→系统→电源和电池→电源模式，或 `powercfg /overlaysetactive <guid>`。
3. **厂商性能档位误区（各品牌通用）**：OEM 散热档（安静/均衡/性能）只改风扇和功耗墙策略，**改不了 Windows 电源模式滑块**——排查时两边都要看。用 `Win32_ComputerSystem.Manufacturer` 判品牌，常见切换方式：

   | 品牌 | 切换方式 |
   |---|---|
   | 联想 | Fn+Q 循环（安静/均衡/野兽），或联想电脑管家 |
   | 华硕 | Fn+F（AIPT 机型，官方）；Fn+F5（天选/ROG，奥创中心） |
   | 小米 | Fn+K 循环（静谧/均衡/极速） |
   | 华为/荣耀 | Fn+P 高能模式（电脑管家→电源管理里也有） |
   | 戴尔/外星人 | 外星人 AWCC 软件内切换；G 系列 G 模式键（G 键/Fn+F9） |
   | 微星 | MSI Center 四档（极致性能/平衡/安静/超级电池），常见热键 Fn+F7/Fn+F8（看键帽风扇图标） |
   | 惠普 | OMEN Gaming Hub 内切换（无统一热键） |
   | 宏碁 | NitroSense / PredatorSense 软件内切换 |

   档位效果依赖随机控制软件（电脑管家/奥创/OMEN Hub/MSI Center 等），控制软件卸了热键多半失灵。**无法程序化读到实际档位时**：按品牌让用户检查对应控制中心/快捷键当前是否停在安静/节能档；同时先确认 Windows 电源模式在平衡以上（能读 overlay 就读），两边对齐后再复测性能。
4. **电源计划细节**：最小处理器状态被调高（如 50%）→ 纯负收益（待机发热挤压睿频），改回 5%；PCIe 链接状态电源管理（ASPM）=最大电源节省 → NVMe 深度休眠唤醒延迟，"开应用卡一下"的经典来源。插电档改关闭：`powercfg /setacvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ASPM 0` + `powercfg /setactive SCHEME_CURRENT`。注意这些设置存在"活动计划"里，用户切换计划后旧值会复活，改完要复查。
5. **显卡驱动过旧**：DriverDate 超过 2 年建议更新（Intel/NVIDIA/AMD），对动画掉帧最有感。
6. **Windows 预览版/Insider**：系统名含 Insider Preview → 不稳定 + 右下角"评估副本"水印 + 更新易失败。水印无性能影响；去除 = 回正式版（ISO 原地升级 setup.exe 保留文件，或在预览体验计划里取消注册后等转正推送）。别用第三方去水印工具；删 WindowsSelfHost 注册表键的偏方会弄坏 Windows 更新。
7. **启动项臃肿**：Win32_StartupCommand 列项，`StartupApproved\Run` 判状态（值的首字节为奇数=已禁用）。禁用=写入 12 字节 `03 00 00 00 00 00 00 00 00 00 00 00`（保留 Run 值，任务管理器可恢复）；软件已卸载的孤儿记录直接删。云盘/预启动类属于可关项；厂商预装全家桶先问用户去留（有人当宝贝有人当垃圾）。
8. **SearchIndexer / MsMpEng（Defender）短暂高占用**：正在建索引或扫盘，属短暂现象，观察即可，别乱关服务。

### 第三步：修复与验证

每修一项就重新采样对比，向用户汇报前后差异。修复动作（改电源/停服务/删启动项）先说明再执行；需要管理员的一律走提权流程并提前告知会弹 UAC。

## 路线B：磁盘清理

### 快速检查（不做全盘扫描——太慢，用户等不起）

固定目标清单，逐项算大小（`Get-ChildItem -Recurse -Force | Measure-Object Length -Sum`）：

- `%TEMP%`、浏览器缓存、包管理器缓存（pip/npm 等）
- `C:\Windows\SoftwareDistribution\Download`：先停 wuauserv/bits/dosvc 服务 → 清空 → 重启服务（实测常可释放数 GB）
- 回收站、`C:\$WINDOWS.~BT`（功能更新完成后才能清）
- hiberfil.sys：不用休眠的话 `powercfg /h off` 可释放（笔记本常 4-8GB，需用户确认）
- **微信/QQ 聊天数据通常是大头（动辄几十 GB）**：引导用户在软件内把存储路径改到 D 盘，**不删聊天记录**
- 目录统计对不上账的空间：管理员 `vssadmin list shadowstorage` 查系统还原点/卷影副本（常藏十几 GB）
- WinSxS 偏大：`DISM /StartComponentCleanup` 瘦身；pagefile.sys 可移到 D 盘（管理员+重启）

### 软件卸载与残留

- **首选 Geek Uninstaller（`tools\geek.exe`，绿色免安装）**：有卸载器的软件都走它，自带残留扫描。让用户双击运行，或由你直接启动它并指导操作。
- **geek.exe 缺失时先补齐**：本 skill 不打包 geek.exe（闭源免费软件，不可再分发）。先查 skill 根目录下 `tools\geek.exe` 是否存在；没有就从官网直链 `https://geekuninstaller.com/geek.zip` 下载（约 3MB，zip 内是单个 geek.exe，`Invoke-WebRequest` + `Expand-Archive` 解到 skill 的 `tools\`）。下载失败/超时（可提示用户开系统代理重试一次）就退回"软件自带卸载器 + 手动残留清理"，不要卡死在这步。
- 无卸载器/卸载后清残留：查三处注册表 Uninstall 键（HKLM、HKLM\WOW6432Node、HKCU）+ Run 启动项 + 服务 + 计划任务 + 文件系统/AppData/Temp，按"文件在但卸载项没了"判断残留，列清单后管理员脚本批量清。
- **运行库类永远保留**：VC++ Redistributable、.NET、XNA 等——卸载省不了几 MB，却会让游戏/软件缺 DLL 报错；FLEXnet/SafeNet 等授权组件同理。

### 流氓/冗余软件扫描（完整体检时主动提醒，不用等用户问）

1. 拉安装清单（跳过 SystemComponent=1 的隐藏项和运行库）：
   `Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*","HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*","HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -EA SilentlyContinue | ? {$_.DisplayName -and -not $_.SystemComponent} | Sort DisplayName -Unique | Select DisplayName,Publisher,InstallDate,InstallLocation,UninstallString`
2. 按特征打标，命中即进提醒清单：
   - **弹窗资讯类**：Run 键/服务/计划任务里有"资讯/头条/热点/推送/Tuiguang/Push"字样的弹窗源；装完 A 软件多出来的游戏/购物快捷方式
   - **捆绑全家桶**：同一厂商 3 个以上互不相关的软件；2345/金山/360 系兄弟软件；常驻的"下载器/升级助手"
   - **假工具类**：驱动人生/驱动精灵弹窗版、XX 优化大师、带资讯流的压缩/看图/输入法
   - **浏览器劫持**：桌面/开始菜单 .lnk 的 TargetPath 后面挂网址参数；默认主页/搜索引擎被改
   - **静默新装**：InstallDate 是用户没印象的日子、装在 %AppData% 或随机目录名且无卸载器
   - **EOL 老软件**：官方停止支持多年（如 Acrobat DC 2017）
   - **重复功能**：同类多份（Apifox/Postman、钉钉/企业IM、Navicat 正版+Lite）——先查本机历史清理记录，常已有挂账结论
3. 输出 🤔 清单**主动问**："发现这些可疑/冗余软件，要不要卸载？"说明卸载走 Geek Uninstaller（含残留扫描），用户点名哪个卸哪个，没点名的不动。
4. 提之前先分清正版和山寨（同名查 Publisher/InstallLocation）；运行库和授权组件永远不进清单；拿不准的标"疑似"，不断言。

### 扫描与判断方法

- 盘符概览（Get-PSDrive）→ 一级目录大小排序 → 下钻 `Select -First 10~30` 看内容判断用途；大目录加 timeout 保护。
- 快捷方式定位真实在用的程序：WScript.Shell COM 读 .lnk 的 TargetPath（判断重复安装哪份在用）。
- 疑似废弃安装：对比 LastWriteTime + 近 60 天改动文件数，旧的判弃用，但仍要用户确认。
- **未知文件不猜**：读文件头 magic bytes、VersionInfo 的 ProductName/CompanyName、注册表交叉判断。名字像垃圾的必须下钻过目再定。

### 删除纪律

1. ✅可删 / 🤔用户决定 / ❌别删 清单，等确认。
2. 删前复查当前状态（用户可能已自行卸载/删除）。
3. 精确路径逐个 `Remove-Item -Recurse -Force`，删后 `Test-Path` 复查；有卸载程序的软件不直接删目录（会留注册表死条目）。
4. 前后 `(Get-PSDrive X).Free` 差值汇报释放量，删后重扫验证。
5. 宝贵数据进回收站而非直接删；当天刚下的安装包保留。
6. ACL 拒绝访问（SYSTEM 属主目录）：提权 `takeown /r /d y` + `icacls /grant *S-1-5-32-544:F /t` + `rd /s /q`。

### 右键菜单精简（完整体检时主动扫一遍并询问；右键慢/杂乱时重点做）

**完整体检即使用户没提右键也要扫一遍主动问**：`-List` 拉清单 → 按"第三方塞的项（用XX打开/上传XX/压缩）/Win11 新菜单（MSIX）/经典二级菜单/已卸载软件的死菜单"分组 → 明显冗余的编成编号清单主动问"要关哪些？只是写 HKCU Blocked 键屏蔽，随时可开回，不删任何文件" → 用户点名的才 `-Toggle`/`-Off`，没点名的不动 → 批量关完问一句要不要 `-RestartExplorer` 立即生效。第三方"用 XX 打开"类是右键变慢主因，优先砍。

用本 skill 自带的 **右键菜单管理器**（`tools\右键菜单管理器\`，免安装、免管理员、完全可逆）：

- 原理：扫描 Win11 新菜单（MSIX 稀疏包 IExplorerCommand）+ 经典二级菜单（shellex 处理器），按 CLSID 写 `HKCU\Software\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked` 屏蔽/删值恢复，不删任何文件。
- 用户手动：双击 `右键菜单管理器.cmd`，编号=切换、r=重扫、e=重启资源管理器、q=退出。
- 你代操作：`pwsh -File context-menu-manager.ps1 -List`（列出）、`-Toggle 名称或编号`（切换）、`-Off 3` / `-On "{GUID}"`（显式开/关）、`-RestartExplorer`。目标：砍掉第三方塞的"用 XX 打开"等项，加快右键弹出。

## 通用勿删判断原则（血泪经验通用化）

- **名字像垃圾的必须下钻过目**：Temp/缓存字样的目录里可能藏着论文、照片等个人文件。
- **软件目录可能"藏"着别的软件**：驱动目录、工具目录里常被塞进已安装的软件，整删会弄坏它们。
- **个人文件一律归🤔类**：论文/照片/视频素材/合同/聊天记录，先确认有备份再谈删。
- **平台游戏在客户端内卸载**（Steam/TapTap/Epic），别删目录。
- **分清正版和山寨**：同名软件可能两份，卸载项里查发行者/安装路径，别把正版当残留删。
- **用户在用的工具目录、正在跑的软件**：动之前问一句。
- 只删与已卸载软件对应的残留；拿不准的列入🤔，宁可少删。

## 提权标准流程

写 .ps1（UTF-8 BOM）→ 脚本内 `Start-Transcript` 开日志 → `Start-Process powershell -Verb RunAs -Wait` 弹 UAC（提前告知用户点"是"）→ 普通权限 shell 轮询日志文件确认进度 → 完成后核对结果 → 用完删临时脚本。
