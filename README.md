# No Zombie Reinforcements · 禁用僵尸增援

**关闭生物受伤后生成新同类的僵尸增援机制。** Minecraft Java Edition 26 系列，提供 **Fabric、Forge、NeoForge 三种独立文件**。服务端安装即可生效，玩家客户端无需安装。

**1.1.0 新增直接拦截**：伤害正常结算后，立即结束僵尸的增援处理。即使其他模组将增援概率读取值改回非零，也不会继续执行这段增援流程。同时保留增援属性最终计算值固定为 **0** 的保护。

## 覆盖生物

僵尸、尸壳、溺尸、僵尸村民、僵尸猪灵。覆盖成年、幼年、已有和新生成的变种，以及沿用原版 `Zombie.hurtServer` 增援流程的第三方生物。其他模组完全独立的召唤技能不在保证范围内。

## 下载与安装

从 [1.1.0 发布页](https://github.com/QXF19/no-zombie-reinforcements/releases/tag/v1.1.0) 选择游戏版本和加载器都匹配的文件。**三个加载器文件只选一个；升级前移出旧版 JAR。**

文件名：`no-zombie-reinforcements-1.1.0-<加载器>+mc<游戏版本>.jar`。

26.2 示例：

| 加载器 | 文件 |
| --- | --- |
| Fabric | `no-zombie-reinforcements-1.1.0-fabric+mc26.2.jar` |
| Forge | `no-zombie-reinforcements-1.1.0-forge+mc26.2.jar` |
| NeoForge | `no-zombie-reinforcements-1.1.0-neoforge+mc26.2.jar` |

需要 **Java 25 或以上**，无需 Fabric API、Kotlin 或其他额外前置。下表列出本次构建验证使用的加载器版本，也是发布文件声明的最低版本：

| Minecraft 正式版 | Fabric Loader | Forge | NeoForge |
| --- | --- | --- | --- |
| 26.1 | 0.19.5 | 62.0.9 | 26.1.0.19-beta |
| 26.1.1 | 0.19.5 | 63.0.2 | 26.1.1.15-beta |
| 26.1.2 | 0.19.5 | 64.1.3 | 26.1.2.116 |
| 26.2 | 0.19.5 | 65.1.3 | 26.2.0.90 |
| 26.3 | 0.19.5 | 66.0.10 | 26.3.0.70-beta |

部分 NeoForge 加载器为官方 beta 版本，文件名和最低依赖约束保留这一信息。

1. 关闭服务端，将旧版本移出 `mods`。
2. 将匹配的一个 JAR 放入服务端的 `mods` 文件夹。
3. 重启，无需配置或命令。

单人游戏可装入对应加载器实例的 `mods` 文件夹。不是 Paper/Spigot 插件。三个加载器的包分别带有各自的模组声明，不能互换。

## 具体影响

- 阻止受伤触发的增援，不关闭自然刷怪、刷怪笼、传送门生成或猪被雷击后的转化。
- 保留正常伤害结算、生命值、移动速度和附近已有生物的群体仇恨行为。
- 保留原有增援属性基值和修饰符。移除模组并重启后，原有属性值恢复作用。
- `/attribute ... base get` 仍可能显示非零基值；使用 `/attribute ... get` 查看最终计算值。
- Forge/NeoForge 版本在进入召唤增援事件前结束这段流程，避免事件监听器重新允许增援。

僵尸猪灵成群追击不等于新生成增援。针对用户报告的 Fabric 26.2 少量新增猪灵，目前未确认其真实生成来源；见 [排查说明](DIAGNOSTICS.md)。

## 实现与验证

共享代码包含三个必要 Mixin：两个针对增援属性的最终读取值，另一个在 `Zombie.hurtServer` 的父类伤害处理成功之后、增援逻辑开始之前返回成功。伤害被拒绝的分支仍返回失败。所有注入均要求准确匹配，接口变化时不会静默失效。

使用五个版本的 Mojang 官方服务端类编译，分别通过实际 Fabric、Forge、NeoForge 加载器运行对照组和安装组。Forge/NeoForge 测试还执行真实模组加载与注册。每次验证包含：

- 属性默认值、实体读取、直接属性读取、保存恢复、基值与修饰符保留。
- 五种生物各 1000 次受伤路径调用，再各 1000 次强制最终概率为 1 的调用。
- 未安装组每轮进入创建 1000 次；安装组每轮进入创建 0 次。
- 检查成功伤害与被拒绝伤害的返回结果，以及生命值属性计算。

测试运行真实 `Zombie.hurtServer` 和实际 Mixin 转换；测试辅助代码提供伤害是否成功、攻击目标、困难难度和允许刷怪的环境，并在创建入口计数后返回空实体。**测试不创建世界、不验证完整战斗或全部第三方模组组合。** 辅助代码不会进入发布 JAR。

结果：[Fabric](TEST-RESULTS.txt)、[Forge / NeoForge](TEST-PLATFORMS.txt)。共 15 个版本与加载器组合，30 次对照/安装运行，150,000 次正常属性调用和 150,000 次强制概率调用。

## 从源码构建

需要 PowerShell 7、JDK 25 或以上和访问 Mojang、Fabric、Forge、NeoForge 官方下载源的网络。依赖缓存位于 `tools/`，发布 JAR 不包含 Minecraft 或其他依赖。

```powershell
pwsh ./build.ps1 -JavaHome 'C:\path\to\jdk-25'
pwsh ./test.ps1 -JavaHome 'C:\path\to\jdk-25'
pwsh ./install-test-servers.ps1 -JavaHome 'C:\path\to\jdk-25'
pwsh ./test-platforms.ps1 -JavaHome 'C:\path\to\jdk-25'
```

四个脚本都可加 `-MinecraftVersions '26.2'`。构建脚本还可加 `-Loaders 'fabric'`。产物位于 `dist/`。模组类以 Java 21 字节码编译以兼容 Forge 的 Mixin，但游戏及构建所需 Java 仍为 25。

旧版 1.0.0 的 Fabric 文件保留在原发布页和 `dist/`，1.1.0 发布使用新的文件名和校验清单。

## 许可

[MIT License](LICENSE)。非 Mojang/Microsoft 官方项目。
