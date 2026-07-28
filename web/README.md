# GPU Monitor — Previous Web Version

> [!NOTE]
> This Streamlit implementation is the previous version. The current native
> macOS menu-bar app is documented in the [repository README](../README.md).

- 支持查看多个主机的服务器GPU信息，类似于nvidia-smi，不过让界面美观一些
- 可以看看哪个服务器的gpu空闲
- 可以查看GPU核心谁在跑实验

``hosts.txt``,然后每行是一个主机名字，可以添加或者删除主机，主机的名字可以通过在~/.ssh/config文件寻找（Host后面的内容即是）。
**注意服务器为你配置了公钥登录，你可以通过本地ssh私钥登陆，即(ssh xxx)，不需要密码，直接进入server.**

## 优化SSH服务器连接 for macos（windows暂时先不配置）

```bash
open ~/.ssh/config
```

把

```
Host jump-host
  ControlMaster auto
  ControlPath ~/.ssh/cm-%r@%h:%p
  ControlPersist 10m

# 2. 针对内网目标机器的优化：全部应用复用
Host gpu-server-*
  ControlMaster auto
  ControlPath ~/.ssh/cm-%r@%h:%p
  ControlPersist 10m
```

复制到~/.ssh/config最后面

- `jump-host` 为跳板机占位别名，请仅在本机替换成真实配置。
- `gpu-server-*` 对应各服务器的通用占位 Host，例如：
```
Host gpu-server-1
  HostName xxx
  User your-username
  Port 22
  ProxyCommand ssh -q -W %h:%p jump-host
  IdentityFile ~/.ssh/your_key
```
这个 `gpu-server-*` 模式可以匹配多个本机 SSH 别名并复用连接。不要把真实内网域名、用户名或密钥路径提交到仓库。

作用： 登录一次服务器后，接下来的 10 分钟内，如果再次连接同一台服务器（或者通过它跳转），不需要再输入密码或进行密钥验证，连接会“秒连”，我在测试的是否，如果不优化连接，频繁连接的话，会被检测，然后被拒绝连接。

## 运行程序
```
pip install pandas streamlit
```

```
streamlit run monitor.py
```
即可运行。

# extra



## 配置APP在macos,方便查看服务器gpu信息

打开终端，输入：

```bash
which streamlit
```

复制输出的路径（通常长这样：/opt/homebrew/bin/streamlit 或 /opt/homebrew/Caskroom/miniconda/base/bin/streamlit）。我们后面要用。

### 制作“一键启动”App

1.在 Mac 上打开 Automator (你可以按 Cmd + 空格 搜索 "Automator" 或 "自动操作")。

2.点击 "新建文稿" (New Document)。

3.选择 "应用程序" (Application)，然后点击“选取”。

4.在左侧搜索栏输入 "shell"，找到 "运行 Shell 脚本" (Run Shell Script)，把它拖到右侧的空白区域。

5.在右侧的编辑框里，删除默认内容，粘贴以下代码（注意替换你的路径）：

```bash
cd /Users/xxx/Code/monitor

# 2. 运行 Streamlit
# 【注意】请把下面的 /path/to/streamlit 换成 'which streamlit' 查到的真实路径！
# 例如：/opt/homebrew/Caskroom/miniconda/base/bin/streamlit run monitor.py
/path/to/streamlit run monitor.py
```

6.按 Cmd + S 保存。保存为：GPU Monitor (或者你喜欢的名字) 位置：选择 “桌面”。文件格式：应用程序。

### 美化图标

现在桌面上已经有一个机器人图标的 App 了，双击它就会自动弹出网页。如果你想给它换个帅气的图标（比如显卡图标）：
- 右键点击桌面刚做好的 GPU Monitor，选择 "显示简介" (Get Info)。
- 找一张你喜欢的 .png 图片（显卡图），或者可以使用gemini banana 制作，按 Cmd + C 复制图片（optional:使用image2icon app可以制作)
- 点击左上角那个小的机器人图标（选中后它会发蓝光），然后把准备好的通用 GPU 图标粘贴到 Get Info 窗口。
- <img width="167" height="133" alt="image" src="https://github.com/user-attachments/assets/53eafb99-e0af-4cae-8b5f-5df8f27366d2" />

### 退出

关闭网页即可。

## windows

### 制作启动脚本
我们需要创建一个 .bat 文件来执行命令。

在你的代码目录（例如 D:\Code\monitor）或是桌面上，右键 -> 新建 -> 文稿/文本文件。

将文件重命名为 start_monitor.bat (注意后缀要是 .bat，不能是 .txt)。

右键点击这个文件，选择 编辑 (或者用记事本打开)，输入以下内容：

方案 A：如果你直接在系统环境里装了 streamlit

```
@echo off
:: 切换到你的代码目录 (/d 是为了确保能跨盘符切换，比如从 C 盘切到 D 盘)
cd /d "D:\Path\To\Your\Code\monitor"

:: 运行 Streamlit (如果 where streamlit 有输出路径，直接写 streamlit 即可)
streamlit run monitor.py
pause
```
方案 B：如果你使用 Conda 环境 (更推荐，更稳定)

```
@echo off
:: 切换到代码目录
cd /d "C:\Users\xxx\Code\monitor"

:: 激活 conda 环境 (将 'your_env_name' 换成你的环境名，如 base)
call conda activate your_env_name

:: 运行脚本
streamlit run monitor.py
```
保存并关闭。

测试一下： 双击这个 start_monitor.bat，看看能不能成功弹出一个黑框框并打开浏览器。如果可以，继续下一步

### 制作“APP”快捷方式

现在的 .bat 文件虽然能用，但是图标很丑（是个齿轮），而且不能直接换图标。我们需要做一个快捷方式。

右键点击刚才做好的 start_monitor.bat。

选择 “发送到” -> “桌面快捷方式”。

现在桌面上多了一个 start_monitor.bat - 快捷方式。

你可以把它重命名为 GPU Monitor。

### 美化图标 (Change Icon)
Windows 的图标机制和 Mac 不同，它需要 .ico 格式，不能直接粘贴 .png。

准备图标：

找一张你喜欢的显卡图片（PNG/JPG）。

打开一个在线转换网站（搜索 "png to ico"），把图片转成 .ico 文件并下载。

更换图标：

右键点击桌面上的 GPU Monitor 快捷方式。

选择 “属性” (Properties)。

点击 “更改图标...” (Change Icon) 按钮。

点击 “浏览...” (Browse)，找到你刚才下载的 .ico 文件。

一路点击 “确定”。
