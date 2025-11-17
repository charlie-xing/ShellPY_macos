# ShellPY macOS

[English](#english) | [中文](#中文)

---

## English

### Overview

ShellPY is an AI-powered Chinese input method for macOS, based on modifications to the [Squirrel](https://github.com/rime/squirrel) project. This project integrates on-device large language model (LLM) inference capabilities to provide intelligent Chinese input assistance.

### Features

- 🤖 **On-Device LLM Inference**: Run large language models locally for enhanced Chinese input prediction
- 🔒 **Privacy-First**: All model inference happens on your device - no data leaves your Mac
- ⚡ **Real-time Processing**: Optimized for low-latency input experience
- 🎯 **Smart Predictions**: Leverages trained language models for context-aware suggestions
- 🍎 **Native macOS Integration**: Built on the robust Squirrel/Rime framework

### Architecture

This project consists of two main components:

1. **Frontend (This Repository)**: Modified Squirrel interface with LLM integration
2. **Backend librime**: Enhanced Rime engine with LLM support (optimization in progress, source code release pending)

### Our Contributions

- Trained custom large language models optimized for Chinese input
- Modified the open-source librime engine to support LLM inference
- Extended Squirrel's UI and functionality to integrate with the LLM backend
- Implemented efficient on-device model execution pipeline

### Technical Stack

- **Base Framework**: [Squirrel](https://github.com/rime/squirrel) (Rime input method for macOS)
- **Input Engine**: Modified [librime](https://github.com/rime/librime)
- **LLM Integration**: Custom trained models with llama.cpp backend
- **Language**: Swift (frontend), C++ (backend)

### Build Requirements

- macOS 13.5 or later
- Xcode 15.0 or later
- librime (included in this repository)

### Installation

```bash
# Clone the repository
git clone https://github.com/charlie-xing/ShellPY_macos.git
cd ShellPY_macos

# Open the Xcode project
open ShellPY.xcodeproj

# Build and run from Xcode
```

### Status

⚠️ **Note**: The enhanced librime backend is currently under optimization. Source code for the backend will be released once optimization is complete.

### License

This project is licensed under the **GNU General Public License v3.0 (GPL-3.0)**.

See [LICENSE](LICENSE) for more details.

### Credits

This project is built upon the excellent work of:
- [Squirrel](https://github.com/rime/squirrel) - Rime Input Method Engine for macOS
- [librime](https://github.com/rime/librime) - Rime Input Method Engine
- [llama.cpp](https://github.com/ggerganov/llama.cpp) - LLM inference in C++

### Disclaimer

This is a research project exploring the integration of large language models with traditional input methods. The librime backend modifications are currently being optimized for performance and will be open-sourced in the future.

---

## 中文

### 项目简介

ShellPY 是一个基于 [Squirrel（鼠须管）](https://github.com/rime/squirrel) 项目修改的 macOS 智能中文输入法，集成了本地运行的大语言模型推理能力，为中文输入提供智能辅助。

### 功能特性

- 🤖 **本地大模型推理**：在本地运行大语言模型，提供智能中文输入预测
- 🔒 **隐私优先**：所有模型推理均在本地完成，数据不离开您的 Mac
- ⚡ **实时处理**：针对低延迟输入体验进行优化
- 🎯 **智能预测**：利用训练好的语言模型提供上下文感知的建议
- 🍎 **原生 macOS 集成**：基于稳定的 Squirrel/Rime 框架构建

### 架构说明

本项目由两个主要组件构成：

1. **前端（本仓库）**：集成了 LLM 的修改版 Squirrel 界面
2. **后端 librime**：增强的 Rime 引擎，支持 LLM（正在优化中，源代码将稍后发布）

### 我们的工作

- 训练了针对中文输入优化的自定义大语言模型
- 修改开源 librime 引擎以支持 LLM 推理
- 扩展 Squirrel 的用户界面和功能以集成 LLM 后端
- 实现了高效的本地模型执行管道

### 技术栈

- **基础框架**：[Squirrel（鼠须管）](https://github.com/rime/squirrel)（macOS 的 Rime 输入法）
- **输入引擎**：修改版 [librime](https://github.com/rime/librime)
- **LLM 集成**：基于 llama.cpp 的自训练模型
- **编程语言**：Swift（前端）、C++（后端）

### 构建要求

- macOS 13.5 或更高版本
- Xcode 15.0 或更高版本
- librime（已包含在本仓库中）

### 安装说明

```bash
# 克隆仓库
git clone https://github.com/charlie-xing/ShellPY_macos.git
cd ShellPY_macos

# 打开 Xcode 项目
open ShellPY.xcodeproj

# 在 Xcode 中构建并运行
```

### 项目状态

⚠️ **注意**：增强版 librime 后端目前正在优化中。优化完成后将发布后端源代码。

### 开源协议

本项目采用 **GNU 通用公共许可证 v3.0 (GPL-3.0)** 进行授权。

详情请参阅 [LICENSE](LICENSE) 文件。

### 致谢

本项目基于以下优秀开源项目构建：
- [Squirrel（鼠须管）](https://github.com/rime/squirrel) - macOS 的 Rime 输入法引擎
- [librime](https://github.com/rime/librime) - Rime 输入法引擎
- [llama.cpp](https://github.com/ggerganov/llama.cpp) - C++ 实现的 LLM 推理

### 免责声明

这是一个探索大语言模型与传统输入法集成的研究项目。librime 后端的修改目前正在进行性能优化，未来将会开源。

---

## Contributing

We welcome contributions! Please feel free to submit issues and pull requests.

## 贡献

欢迎贡献！请随时提交 Issue 和 Pull Request。

---

**© 2024 ShellPY Team. Licensed under GPL-3.0.**
