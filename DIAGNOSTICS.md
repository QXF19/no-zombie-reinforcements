# Fabric 26.2 僵尸猪灵排查

用户报告受伤后偶尔看到新增僵尸猪灵，已确认游戏为 26.2、加载器为 Fabric。目前没有现场服务端日志、实体 UUID 或生成原因记录，因此不能确认这些实体来自增援，也不能认定用户观察错误。

26.2 官方类中，僵尸猪灵继承僵尸的受伤增援流程，初始增援概率通常为 0。附近已有猪灵的群体愤怒是另外的行为。自然生成、传送门生成、猪被雷击转化或数据包/其他模组独立召唤也可能产生新实体。

1.1.0 在父类伤害处理成功后立即结束增援流程，并保留增援属性读取值为 0 的保护。测试强制将实体增援概率读取值重新设为 1，确认直接拦截仍阻止创建。

## 旧版复查结果

使用原发布的 Fabric 1.0.0 + Minecraft 26.2 文件和同一受伤路径测试，僵尸猪灵正常读取属性时，1000 次调用进入增援创建 **0 次**。测试辅助代码强制将最终概率读取值改为 1 后，进入创建 **1000 次**，符合旧版仅保护属性读取的实现。1.1.0 在这两种条件下均为 0 次。

因此，**目前未在原版 26.2 受伤路径中复现旧版仍有少量增援**。强制概率测试是用于验证拦截的人工条件，不是现场装有其他模组覆盖概率的证据。完整旧版报告见 [TEST-ORIGINAL-26.2.txt](TEST-ORIGINAL-26.2.txt)。

## 升级后的现场检查

1. 确认 JAR 装在实际运行的服务端 `mods` 中，完整重启，并在启动模组列表中找到 `no_zombie_reinforcements` 1.1.0。
2. 移出 1.0.0，只保留 `no-zombie-reinforcements-1.1.0-fabric+mc26.2.jar`。
3. 在有命令权限时检查最近一只猪灵的最终增援属性：

```text
/attribute @e[type=minecraft:zombified_piglin,sort=nearest,limit=1] minecraft:spawn_reinforcements get
```

最终计算值应为 0。`base get` 查看的是保存的基值，不能用来判断拦截是否生效。

4. 攻击前给周围现有猪灵做临时标记：

```text
/tag @e[type=minecraft:zombified_piglin,distance=..64] add nzr_existing
```

观察疑似新增猪灵是否没有标记，并读取 UUID：

```text
/execute as @e[type=minecraft:zombified_piglin,tag=!nzr_existing,distance=..64] run data get entity @s UUID
```

标记只用于区分已有与后来进入范围的实体，不能单独证明生成原因。范围外走进来的猪灵也可能未标记。完成后移除测试标记：

```text
/tag @e[type=minecraft:zombified_piglin,tag=nzr_existing] remove nzr_existing
```

若更新后仍出现，保留发生时间、启动日志、其他模组和数据包列表，并确认附近是否有传送门、雷击或其他生成装置。完全独立于原版增援流程的召唤需要针对来源处理。
