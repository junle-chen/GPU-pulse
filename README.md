# GPU Monitor
- 支持查看多个主机的服务器GPU信息，类似于nvidia-smi，不过让界面美观一些
- 可以看看哪个服务器的gpu空闲
- 可以查看GPU核心谁在跑实验


# extra
## 优化SSH服务器连接
```bash
open ~/.ssh/config
```
把
```
Host 跳板机
  ControlMaster auto
  ControlPath ~/.ssh/cm-%r@%h:%p
  ControlPersist 10m

# 2. 针对内网目标机器的优化：全部应用复用
Host 你的内网机器
  ControlMaster auto
  ControlPath ~/.ssh/cm-%r@%h:%p
  ControlPersist 10m
```

作用： 登录一次服务器后，接下来的 10 分钟内，如果再次连接同一台服务器（或者通过它跳转），不需要再输入密码或进行密钥验证，连接会“秒连”，我在测试的是否，如果不优化连接，频繁连接的话，会被检测，然后被拒绝连接。

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

- 找一张你喜欢的 .png 图片（显卡图）。

- 双击图片用“预览”打开，按 Cmd + C 复制图片。

- 右键点击桌面刚做好的 GPU Monitor，选择 "显示简介" (Get Info)。

- 点击左上角那个小的机器人图标（选中后它会发蓝光）。

- 按 Cmd + V 粘贴。
