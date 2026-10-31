# Ti60 FPGA / ESP32 工程与烧录固件

版本保持 **V8.1.1 / F9-V8-1031-SPI**。本包只包含 ESP32 源码、FPGA 工程源码及配套烧录固件。测试、日志、验证报告、GitHub 辅助文档和重复源码包不在包内。

## 目录及入口

| 目录或文件 | 用途 |
| --- | --- |
| `esp32/esp32_fpga_spi_bridge/esp32_fpga_spi_bridge.ino` | ESP32 Arduino 主程序入口 |
| `esp32/esp32_fpga_spi_bridge/*.h` | SPI/HTTP、模型装载、人像、任务、结果缓存和网页资源等配套源码 |
| `esp32/esp32_fpga_spi_bridge/partitions.csv` | ESP32 Flash 分区表，需随 Arduino 工程保留 |
| `esp32/web_sources/` | 网页 JavaScript 原始源码及部分样式/页面构建输入；直接编译使用 Arduino 目录中已有的网页资源头文件 |
| `fpga/Ti60_Demo_frame_ddr.xml` | Efinity FPGA 工程入口，顶层为 `example_top` |
| `fpga/Ti60_Demo.peri.xml` | 外设、引脚配置 |
| `fpga/Ti60_Demo.pt.sdc` | 时序约束 |
| `fpga/src/` | 摄像头、DDR、显示、AXI 等板级 RTL |
| `fpga/rtl_custom/` | JPEG、图像处理、模型运算、通信及第三方 RTL |
| `fpga/ip/` | Efinity IP 源码、配置、模板和工具元数据 |
| `fpga/variants/frame_ddr_20261011/` | 当前顶层与整帧处理、人像、SPI 等集成模块 |
| `fpga/variants/full_student_20261018/firmware/` | FPGA 内 RISC-V 程序的 C/汇编、链接脚本和 RAM 初始化文件；不是 ESP32 固件 |
| `fpga/variants/full_student_20261018/runtime/` | 模型权重、各尺寸运行程序、Flash 模型区及元数据 |
| `fpga/variants/` 其余目录 | 现有工程使用的辅助模块、参数和初始化文件，保持目录关系 |
| `fpga/pc_tools/prepare_project_paths.py` | 换电脑或目录后更新 IP 配置中的本机基准路径 |
| `firmware/esp32/` | ESP32 应用、引导和分区烧录文件 |
| `firmware/fpga/` | 包含 FPGA 配置和模型数据的 Flash 镜像 |

## 编译

**FPGA：**工程记录环境为 Efinity 2025.2.288.3.8，器件 Ti60F225、C4。换目录后在包根目录执行：

```powershell
python fpga/pc_tools/prepare_project_paths.py
```

然后打开 `fpga/Ti60_Demo_frame_ddr.xml` 进行综合、布局布线和位流生成。工具链需自行安装。

**ESP32：**使用 Arduino ESP32 Core 3.1.1、ESP32 Dev Module（FQBN `esp32:esp32:esp32`），打开 `esp32/esp32_fpga_spi_bridge/esp32_fpga_spi_bridge.ino`，保留同目录全部头文件和分区表。Arduino CLI 示例：

```powershell
arduino-cli compile --fqbn esp32:esp32:esp32 --build-path ./build/esp32 ./esp32/esp32_fpga_spi_bridge
```

**FPGA 内 RISC-V 程序：**普通 FPGA 编译使用预置 `nonconv.mem`。仅修改板内 C/汇编时，才需在 Linux/WSL 安装支持 RV32IM/ILP32 的裸机 GCC，在该 `firmware` 源码目录执行：

```bash
RISCV_TOOLCHAIN=/path/to/riscv64-unknown-elf- bash build.sh
```

前缀按实际安装填写。BIN/MEM 应与源码一起更新，再重新构建 FPGA。

## 烧录

| 芯片 | 固件文件 | Flash 地址 |
| --- | --- | --- |
| ESP32 | `firmware/esp32/bootloader.bin` | `0x1000` |
| ESP32 | `firmware/esp32/partitions.bin` | `0x8000` |
| ESP32 | `firmware/esp32/application.bin` | `0x10000` |
| FPGA 配置 Flash | `firmware/fpga/fpga_configuration_and_model.bin` 或同名 `.hex` | `0x0`，按所用烧录工具支持的格式选择 |

已经使用相同引导与分区的 ESP32，优先只更新 `application.bin`，保留 NVS。FPGA 镜像为 8 MiB，包含 `0x140000` 起始的模型区，不要另行覆盖该区域。

设备热点：`Ti60-Capture`，密码：`ti60capture`；连接后浏览器访问 `http://192.168.4.1`。

## 配套关系与状态

ESP32 烧录应用与当前保留版本号的修复源码相配套，已编译通过；本次人像上传修复未修改 FPGA 镜像，尚未完成对应实板复测。此前用户反馈板卡运行正常；既有 FPGA 静态时序记录最差建立余量为 `-0.086 ns`，尚未完全收敛。本次目录整理未重新构建 FPGA。

工程中的 `.mem`、`.hex`、模型 `.bin`、DDR IP 数据及 IP 元数据属于构建/运行依赖，不能按测试产物删除。包内提供现有模型运行数据，不提供训练数据和训练/量化导出的全流程源码。

## 第三方声明

只有本文件作为项目 README。源码旁的第三方许可证、来源和版权声明仍予保留：JPEG 解码 Apache-2.0、JPEG 编码 GPL-3.0、PicoRV32 的 COPYING/PROVENANCE、GCC 运行库声明及 `fpga/SOURCE_NOTICES.txt`。本次整理未为整个工程添加统一许可证。
