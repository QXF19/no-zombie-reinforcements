# No Zombie Reinforcements · 禁用僵尸增援

**关闭生物受伤后召唤新同类的原版僵尸增援机制。** 适用于 Minecraft Java Edition 26 系列正式版，使用 Fabric 加载。服务端安装即可生效，玩家客户端不需要安装。

困难模式下，僵尸类生物受到有效伤害时，原版会根据 `minecraft:spawn_reinforcements` 的计算值尝试生成增援。本模组将此属性的最终读取值固定为 **0**，从概率判断阶段阻止增援尝试。

## 覆盖哪些生物？

- 僵尸（Zombie）
- 尸壳（Husk）
- 溺尸（Drowned）
- 僵尸村民（Zombie Villager）
- 僵尸猪灵（Zombified Piglin）

覆盖成年与幼年变种、已有与新生成的生物。领头僵尸的正向修饰符，以及命令或数据修改造成的非零增援基值，也不能重新启用原版增援。

模组作用于属性读取，而非按实体 ID 逐个排除；其他模组的生物若沿用原版增援属性读取路径，也会受到影响。其他模组完全自行实现的召唤技能不在保证范围内。

## 下载与安装

从 [Releases](https://github.com/QXF19/no-zombie-reinforcements/releases) 下载与游戏版本完全一致的 JAR。**只安装一个版本的文件。**

| Minecraft 正式版 | 文件 |
| --- | --- |
| 26.1 | `no-zombie-reinforcements-1.0.0+mc26.1.jar` |
| 26.1.1 | `no-zombie-reinforcements-1.0.0+mc26.1.1.jar` |
| 26.1.2 | `no-zombie-reinforcements-1.0.0+mc26.1.2.jar` |
| 26.2 | `no-zombie-reinforcements-1.0.0+mc26.2.jar` |
| 26.3 | `no-zombie-reinforcements-1.0.0+mc26.3.jar` |

要求：**Java 25 或以上、Fabric Loader 0.19.5 或以上**。不需要 Fabric API、Kotlin 或其他额外前置。

1. 关闭服务端。
2. 将对应 JAR 放入服务端根目录的 `mods` 文件夹。
3. 重启服务端，无需命令或配置。

单人游戏也可将 JAR 放入对应 Fabric 实例的 `mods` 文件夹。它不是 Paper/Spigot 插件，也不适用于 Forge/NeoForge。

## 具体影响

- 关闭的是受伤后**新生成同类**的增援，不会关闭自然刷怪或刷怪笼。
- 不改变生命值、伤害、移动速度等其他属性。
- 不改变附近已有生物的群体仇恨、呼叫同伴或目标共享行为。
- 不清除已经存在的生物，不修改世界生成或难度。
- 不改写保存的属性基值和修饰符。移除模组并重启后，原有值继续生效。
- `/attribute ... base get` 读取的是保存的基值，因此可能仍非零；实际计算值被模组固定为 0。

僵尸猪灵通常具有为 0 的增援基值，但若被修改为非零，本模组仍会阻止其原版增援。不要把附近僵尸猪灵一起愤怒误认为新生成增援。

## 实现与验证

在 `AttributeInstance.getValue()` 和 `AttributeMap.getValue(Holder)` 注入，仅处理原版增援属性；第二个注入同时覆盖尚未实例化的属性默认值。所有注入都要求准确匹配，不会在版本接口变化时静默失效。26 系列使用官方可读类名，无需重映射。

使用各版本的 Mojang 官方服务端 JAR 分别编译，通过真实 Fabric Loader 执行自动验证。每个版本都包含未安装模组的对照测试和安装模组后的测试：

- 五种生物的属性基值设为 1，并叠加正向修饰符；安装后最终读取值均为 0，对照组为 1。
- 验证实体读取、直接属性实例读取和属性默认值路径。
- 验证保存并重新加载属性后依然生效，原基值和修饰符保留。
- 以生命值属性作为对照，确认其他属性和修饰符正常计算。

测试使用游戏真实属性类和 Fabric 的实际 Mixin 转换，但不创建世界、不模拟完整战斗，也不代表所有第三方模组组合都已验证。完整结果见 [TEST-RESULTS.txt](TEST-RESULTS.txt)。

## 从源码构建

需要 PowerShell 7、JDK 25 或以上，以及访问 Mojang/Fabric 官方下载源的网络连接。构建脚本将依赖下载到项目的 `tools` 目录，不修改系统 Java；不会把 Minecraft 或第三方依赖打包进发布 JAR。

```powershell
pwsh ./build.ps1 -JavaHome 'C:\path\to\jdk-25'
pwsh ./test.ps1 -JavaHome 'C:\path\to\jdk-25'
```

只构建、测试 26.2：

```powershell
pwsh ./build.ps1 -MinecraftVersions '26.2' -JavaHome 'C:\path\to\jdk-25'
pwsh ./test.ps1 -MinecraftVersions '26.2' -JavaHome 'C:\path\to\jdk-25'
```

构建产物在 `dist/`。测试辅助模组不会进入发布 JAR。各 JAR 内的版本约束固定到对应游戏正式版，未来的 26 系列版本需要重新构建与验证。

## 参考与许可

机制说明：[中文 Minecraft Wiki：僵尸增援属性](https://zh.minecraft.wiki/w/属性/僵尸增援)。当前版本实现另以各正式版官方服务端字节码核对。

本项目采用 [MIT License](LICENSE)。非 Mojang/Microsoft 官方项目。
