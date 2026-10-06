<#
.SYNOPSIS
  Win11 右键菜单"第三方扩展区"管理器
.DESCRIPTION
  一级(新)菜单的第三方项来自稀疏 MSIX 包(IExplorerCommand),二级(经典)菜单项来自 shellex 处理器;
  两类都能用同一个官方机制开关:HKCU\Software\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked
  按 CLSID 写值即屏蔽,删值即恢复。无需管理员,完全可逆。
  切换后若右键菜单未变化,重启一次资源管理器(e 选项)。
.EXAMPLE
  pwsh -File context-menu-manager.ps1 -List            # 仅列出
  pwsh -File context-menu-manager.ps1 -Toggle QQ       # 按名称/编号/GUID 切换
  pwsh -File context-menu-manager.ps1 -Off 3           # 关闭第 3 项
  pwsh -File context-menu-manager.ps1 -On "{CC19E147-7757-483C-B27F-3D81BCEB38F1}"
  pwsh -File context-menu-manager.ps1                  # 交互界面
#>
param(
    [switch]$List,
    [switch]$RestartExplorer,
    [string]$On = '',
    [string]$Off = '',
    [string]$Toggle = ''
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}

$BlockedKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked'
$GuidRx = '^\{?[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\}?$'
$Roots  = @('*', 'AllFilesystemObjects', 'Directory', 'Directory\Background', 'Folder', 'Drive')
$Hives  = @('Registry::HKEY_CLASSES_ROOT', 'Registry::HKEY_CURRENT_USER\Software\Classes')

# 已知项显示名(CLSID 无花括号大写形式;仅覆盖本机已确认的项,其余自动兜底)
$FriendlyById = @{
    'AC2512EE-996B-4B15-918E-D801FD7DB91B' = '卡巴斯基'
    '36D7AD11-6890-4ADB-B2DA-C74D182CDB7C' = '卡巴斯基(经典菜单项)'
    'CC19E147-7757-483C-B27F-3D81BCEB38F1' = '通过QQ发送到'
    '1C6DF0C0-192A-4451-BE36-6A59A86A692E' = '通过 Code 打开 (VS Code)'
    'CA6CC9F1-867A-481E-951E-A28C5E4F01EA' = '在记事本中编辑'
    '9F156763-7844-4DC4-B2B1-901F640F5155' = '在终端中打开'
    '2430F218-B743-4FD6-97BF-5C76541B4AE9' = '在画图中编辑'
    'BFE0E2A4-C70C-4AD7-AC3D-10D1ECEBB5B4' = '在照片中编辑'
    '43F38682-CBB4-47BC-888F-8FBEAA382B04' = '联想电脑管家(右键菜单管理)'
    'D28D30E7-17F3-41D9-93F0-9BAE6DC4884B' = '在 Codex/ChatGPT 中打开'
    '103CE0C1-0F7C-4B02-BEB5-2284CB3BEF7C' = 'WPS Office(目录背景)'
    'EAE7D0A0-4863-4DA0-852C-342B00F68490' = 'WPS Office(文件)'
    'EA5C4860-EA21-45D6-836D-C891EF5F7D8C' = 'WPS Office(目录)'
    'B5C96403-B820-4300-8A2F-CDFDBFCDFEF6' = 'WPS Office(磁盘)'
    'DBDED57A-CA8E-4C07-8691-3F66147DB794' = 'PDF 工具(PDF)'
    'E72AC5B2-9E7A-466D-99B0-ACD79476BBEE' = 'PDF 工具(图片转PDF)'
    '08472A98-0B84-45DE-9B4C-A38E3794F06C' = 'PDF 工具(Office转PDF)'
}

function Convert-Cover([string]$t) {
    switch ($t) {
        '*'                    { '全部文件' }
        'Directory'            { '目录' }
        'Directory\Background' { '目录背景' }
        'Folder'               { '文件夹' }
        'Drive'                { '磁盘' }
        default                { $t }
    }
}

function Add-CtxItem($map, [string]$clsidRaw, [string]$name, [string]$area, [string]$cover, [string]$source, [bool]$isSys) {
    if ($clsidRaw -notmatch $GuidRx) { return }
    $c = '{' + $clsidRaw.Trim('{}').ToUpper() + '}'
    if (-not $map.Contains($c)) {
        $map[$c] = [pscustomobject]@{
            Clsid   = $c
            Name    = ''
            Areas   = [System.Collections.Generic.List[string]]::new()
            Covers  = [System.Collections.Generic.List[string]]::new()
            Sources = [System.Collections.Generic.List[string]]::new()
            IsSys   = $isSys
        }
    }
    $it = $map[$c]
    if ($name -and -not $it.Name) { $it.Name = $name }
    if ($area   -and -not $it.Areas.Contains($area))   { $it.Areas.Add($area) }
    if ($cover  -and -not $it.Covers.Contains($cover)) { $it.Covers.Add($cover) }
    if ($source -and -not $it.Sources.Contains($source)) { $it.Sources.Add($source) }
}

function Get-CtxItems {
    Write-Host '正在扫描(Appx 包清单 + 注册表,约 1 分钟)…' -ForegroundColor DarkGray
    $map = [ordered]@{}

    # 1) 新菜单:稀疏 MSIX 包的 fileExplorerContextMenus 扩展
    foreach ($p in Get-AppxPackage) {
        $m = $null
        try { $m = Get-AppxPackageManifest -Package $p } catch { continue }
        if (-not $m) { continue }
        $nodes = $m.SelectNodes("//*[local-name()='Extension' and @Category='windows.fileExplorerContextMenus']")
        if ($nodes.Count -eq 0) { continue }
        $disp = "$($m.Package.Properties.DisplayName)"
        if ($disp -eq '' -or $disp -like 'ms-resource*') { $disp = $p.Name }
        # VS Code 是用户安装的软件,虽为 Microsoft 包名仍归入第三方
        $isSys = ($p.Name -like 'Microsoft.*') -and ($p.Name -ne 'Microsoft.VisualStudioCode')
        foreach ($n in $nodes) {
            foreach ($v in $n.SelectNodes(".//*[local-name()='Verb']")) {
                Add-CtxItem $map $v.GetAttribute('Clsid') $disp '新菜单' (Convert-Cover $v.ParentNode.GetAttribute('Type')) $p.Name $isSys
            }
        }
    }

    # 2) 新菜单:静态动词挂 ExplorerCommandHandler
    foreach ($h in $Hives) {
        foreach ($r in $Roots) {
            $sk = "$h\$r\shell"
            if (-not (Test-Path -LiteralPath $sk)) { continue }
            foreach ($v in (Get-ChildItem -LiteralPath $sk)) {
                $ech = "$($v.GetValue('ExplorerCommandHandler'))"
                if ($ech -match $GuidRx) {
                    $nm = "$($v.GetValue('MuiVerb'))"
                    if (-not $nm) { $nm = $v.PSChildName }
                    Add-CtxItem $map $ech $nm '新菜单' (Convert-Cover $r) "verb:$r\$($v.PSChildName)" $false
                }
            }
        }
    }

    # 3) 二级菜单:shellex ContextMenuHandlers(系统组件不列)
    foreach ($h in $Hives) {
        foreach ($r in $Roots) {
            $k = "$h\$r\shellex\ContextMenuHandlers"
            if (-not (Test-Path -LiteralPath $k)) { continue }
            foreach ($c in (Get-ChildItem -LiteralPath $k)) {
                $clsid = "$($c.GetValue(''))".Trim()
                if (-not $clsid) { $clsid = $c.PSChildName }
                $name = ''; $dll = ''
                $ck = "Registry::HKEY_CLASSES_ROOT\CLSID\$clsid"
                $hasClsid = Test-Path -LiteralPath $ck
                if ($hasClsid) {
                    $name = "$((Get-Item -LiteralPath $ck).GetValue(''))"
                    $ik = "$ck\InprocServer32"
                    if (Test-Path -LiteralPath $ik) { $dll = "$((Get-Item -LiteralPath $ik).GetValue(''))" }
                }
                $dll = [Environment]::ExpandEnvironmentVariables($dll)
                if ($dll -match '^[A-Za-z]:\\Windows\\') { continue }   # 系统 dll,不列
                if (-not $hasClsid -and -not $map.Contains('{' + $clsid.Trim('{}').ToUpper() + '}')) { continue }  # 死项或仅包内项
                Add-CtxItem $map $clsid $name '二级菜单' (Convert-Cover $r) "shellex:$($c.PSChildName)" $false
            }
        }
    }

    # 显示名兜底与排序:第三方在前,新菜单在前,再按名称
    $result = foreach ($it in $map.Values) {
        $bare = $it.Clsid.Trim('{}')
        if (-not $it.Name) { $it.Name = $bare }
        if ($FriendlyById.ContainsKey($bare)) { $it.Name = $FriendlyById[$bare] }
        $it
    }
    return @($result | Sort-Object -Property @{e={[int]$_.IsSys}}, @{e={[int](-not ($_.Areas -contains '新菜单'))}}, @{e={$_.Name}})
}

function Get-BlockedSet {
    $s = @{}
    if (Test-Path -LiteralPath $BlockedKey) {
        foreach ($n in (Get-Item -LiteralPath $BlockedKey).GetValueNames()) { $s[$n.Trim('{}').ToUpper()] = $true }
    }
    return $s
}

function Set-CtxItem([object]$it, [bool]$enable) {
    if (-not $it) { throw '没有可操作的对象' }
    if (-not (Test-Path -LiteralPath $BlockedKey)) { New-Item -Path $BlockedKey -Force | Out-Null }
    $bare = $it.Clsid.Trim('{}').ToUpper()
    if ($enable) {
        Remove-ItemProperty -LiteralPath $BlockedKey -Name $it.Clsid -ErrorAction SilentlyContinue
        Remove-ItemProperty -LiteralPath $BlockedKey -Name $bare -ErrorAction SilentlyContinue
    } else {
        New-ItemProperty -LiteralPath $BlockedKey -Name $it.Clsid -Value "ctxmenu-manager: $($it.Name)" -PropertyType String -Force | Out-Null
    }
}

function Show-Items($items) {
    $blocked = Get-BlockedSet
    $i = 0
    $prevSys = $null
    foreach ($it in $items) {
        $i++
        if ($prevSys -ne $it.IsSys) {
            $prevSys = $it.IsSys
            Write-Host ''
            if ($it.IsSys) { Write-Host '―――――――― 微软内置(同样可开关) ――――――――' -ForegroundColor DarkCyan }
            else           { Write-Host '―――――――― 第三方 ――――――――' -ForegroundColor Yellow }
        }
        $off = $blocked.ContainsKey($it.Clsid.Trim('{}').ToUpper())
        $state = if ($off) { '[关]' } else { '[开]' }
        $cover = ($it.Covers -join '/')
        if ($cover.Length -gt 52) { $cover = $cover.Substring(0, 52) + '…' }
        Write-Host ('{0,3} ' -f $i) -NoNewline
        Write-Host $state -ForegroundColor ($(if ($off) { 'Red' } else { 'Green' })) -NoNewline
        Write-Host ('  {0}   {1}   {2}' -f $it.Name, ($it.Areas -join '+'), $cover)
        $src = ($it.Sources -join ', ')
        if ($src.Length -gt 90) { $src = $src.Substring(0, 90) + '…' }
        Write-Host "      $src  $($it.Clsid)" -ForegroundColor DarkGray
    }
    Write-Host ''
    Write-Host '编号=切换开关   r=重新扫描   e=重启资源管理器(菜单没变化时用)   q=退出' -ForegroundColor Cyan
}

function Resolve-CtxItem([string]$sel, $items) {
    if (-not $sel) { return $null }
    if ($sel -match '^\d+$') {
        $i = [int]$sel
        if ($i -ge 1 -and $i -le $items.Count) { return $items[$i - 1] }
        return $null
    }
    $u = $sel.ToUpper()
    foreach ($it in $items) {
        if ($it.Clsid.ToUpper().Contains($u) -or $it.Name.ToUpper().Contains($u)) { return $it }
    }
    return $null
}

function Restart-ExplorerFn {
    Write-Host '正在重启资源管理器…'
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 900
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
    Write-Host '资源管理器已重启。'
}

function Invoke-Toggle([string]$sel, $items, [Nullable[bool]]$forceOn) {
    $it = Resolve-CtxItem $sel $items
    if (-not $it) { Write-Host "找不到项:$sel" -ForegroundColor Red; return $null }
    $currentlyOff = (Get-BlockedSet).ContainsKey($it.Clsid.Trim('{}').ToUpper())
    # 切换模式:当前开着就关、当前关着就开;forceOn/-Off 显式指定目标态
    $target = if ($null -ne $forceOn) { [bool]$forceOn } else { $currentlyOff }
    Set-CtxItem $it $target
    $nowState = if ((Get-BlockedSet).ContainsKey($it.Clsid.Trim('{}').ToUpper())) { '关(已屏蔽)' } else { '开(已恢复)' }
    Write-Host "已将『$($it.Name)』设为 $nowState  —— 右键菜单若未变化,重启资源管理器(e)。" -ForegroundColor Green
    return $it
}

# ---------- 主流程 ----------
if ($RestartExplorer) { Restart-ExplorerFn; return }

if ($On -or $Off -or $Toggle) {
    $sel    = if ($On) { $On } elseif ($Off) { $Off } else { $Toggle }
    $target = if ($On) { $true } elseif ($Off) { $false } else { $null }
    if ($sel -match $GuidRx) {
        # 纯 GUID 直接操作,免扫描
        $items = @([pscustomobject]@{ Clsid = ('{' + $sel.Trim('{}').ToUpper() + '}'); Name = $sel })
    } else {
        $items = Get-CtxItems
    }
    Invoke-Toggle $sel $items $target | Out-Null
    return
}

if ($List) { Show-Items (Get-CtxItems); return }

# 交互模式
$items = Get-CtxItems
Show-Items $items
while ($true) {
    $in = (Read-Host '>').Trim()
    if ($in -eq '') { Show-Items $items; continue }
    if ($in -eq 'q' -or $in -eq 'quit' -or $in -eq 'exit') { break }
    if ($in -eq 'r') { $items = Get-CtxItems; Show-Items $items; continue }
    if ($in -eq 'e') { Restart-ExplorerFn; continue }
    Invoke-Toggle $in $items $null | Out-Null
}
