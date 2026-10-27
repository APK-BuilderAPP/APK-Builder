# APK Builder

一款基于 **Smali** 的安卓 APK 打包工具（命令行版）。把一份 `/template` 形式的 Smali 工程，通过 `aapt` 编译资源、`smali.jar` 生成 dex、`apksigner` 签名，最终产出可安装的 APK。

> 灵感来自手机端同名工具：内置完整的打包工具链与模板，可在命令行/脚本中无 IDE 完成构建，适合 Smali 逆向修改、APK 定制、学习安卓打包原理。

## 特性

- ✅ 纯命令行构建，无需 Android Studio / Gradle
- ✅ 内置工具链：`smali.jar`、`aapt`、`apksigner.jar`、`android.jar`
- ✅ 内置 AOSP 标准签名 key（testkey / platform / shared / media / editorkey）
- ✅ 占位符模板：`{{PACKAGE}}` 包名、`{{APP_NAME}}` 应用名，一键替换
- ✅ 一次生成可安装 APK，自带校验命令

## 目录结构

```
APK-Builder/
├── build.sh               # 一键构建脚本（核心）
├── template/              # Smali 工程模板（可复制做新项目）
│   ├── AndroidManifest.xml
│   ├── res/
│   │   ├── layout/activity_main.xml
│   │   └── values/strings.xml
│   └── smali/com/apkbuilder/MainActivity.smali
├── bin/                   # 打包工具链
│   ├── smali.jar  aapt  aapt2  apksigner.jar  android.jar  zip
├── keys/                  # 签名密钥（AOSP 标准 key）
│   ├── testkey / platform / shared / media / editorkey
├── samples/               # 示例项目（占位）
└── docs/BUILD_GUIDE.md    # 详细构建说明
```

## 环境要求

> ⚠️ **工具链定位**：仓库 `bin/` 内置的是**安卓端运行时版**工具链（ARM 版 aapt + DEX 格式 smali/apksigner），来自手机端 APK Builder，适合安卓环境集成。若要在 PC 端用 `build.sh` 构建，请先按 [docs/BUILD_GUIDE.md](./docs/BUILD_GUIDE.md) 第 6 节替换为桌面版工具。

| 依赖 | 版本 | 用途 |
| ---- | ---- | ---- |
| Java (JDK/JRE) | 8 及以上 | 驱动 jar 类工具 |
| Linux / macOS（ARM） | 本仓库内置 arm 版 aapt | 安卓端资源编译 |
| PC 构建 | 需替换 x86 版 aapt、JVM 版 smali/apksigner | PC 端自动化构建 |

## 快速开始

```bash
# 1. 给脚本执行权限
chmod +x build.sh

# 2. 用默认模板直接构建
./build.sh

# 3. 指定包名和应用名
./build.sh -p com.example.demo -n "我的应用"

# 4. 指定输入工程、输出路径
./build.sh -i template -o dist/app-release.apk -p com.example.demo -n Demo
```

构建完成后：
```bash
# 校验 APK 签名
java -jar bin/apksigner.jar verify --verbose dist/app-release.apk

# 安装到设备（若已连接 adb）
adb install -r dist/app-release.apk
```

## 签名说明

默认使用 `keys/testkey`（AOSP 标准测试密钥，`test-only`，仅适合调试/学习）。

- `testkey`   —— 默认调试密钥
- `platform`  —— 系统级签名（platform 权限）
- `shared`    —— 共享 UID 签名
- `media`     —— media 进程签名
- `editorkey` —— 工具默认编辑密钥

> ⚠️ **重要**：以上均为 AOSP 公开的标准测试密钥。**正式发布请生成自己的密钥**，切勿使用 testkey 发布到应用商店。

### 生成自己的发布密钥
```bash
openssl genrsa -out release.pk8 2048
openssl req -new -x509 -key release.pk8 -out release.x509.pem -days 10950
# 构建时：./build.sh -k release
```

## 自定义工程

复制一份 `template/` 即可开始新项目：

```bash
cp -r template myapp
# 编辑 myapp/smali/... 的 Smali 代码
# 编辑 myapp/res/ 资源与布局
# 编辑 myapp/AndroidManifest.xml（或用 -p / -n 参数）
./build.sh -i myapp -p com.example.myapp -n "MyApp"
```

## 开源组件致谢

本项目工具链复用以下开源组件：

- **smali / baksmali** —— Google 维护的 Smali 汇编器（Apache 2.0）
- **apksigner** —— AOSP 官方签名工具（Apache 2.0）
- **android.jar** —— Android SDK 平台 android.jar（Apache 2.0）
- **aapt / aapt2** —— Android Asset Packaging Tool（Apache 2.0）

各组件版权归原作者所有，本项目仅作打包整合。

## 许可证

[MIT License](./LICENSE) © 2026

---

**免责声明**：本工具用于合法的 APK 定制、逆向学习与个人开发。请勿用于侵犯他人知识产权或商业软件反编译发布。
