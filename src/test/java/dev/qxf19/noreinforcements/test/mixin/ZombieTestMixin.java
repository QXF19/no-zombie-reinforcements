package dev.qxf19.noreinforcements.test.mixin;
import dev.qxf19.noreinforcements.test.ReinforcementsTest;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.Difficulty;
import net.minecraft.world.entity.monster.zombie.Zombie;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Redirect;
@Mixin(Zombie.class)
public class ZombieTestMixin {
    @Redirect(method="hurtServer", at=@At(value="INVOKE", target="Lnet/minecraft/server/level/ServerLevel;getDifficulty()Lnet/minecraft/world/Difficulty;"))
    private Difficulty test$difficulty(ServerLevel level) { return Difficulty.HARD; }
    @Redirect(method="hurtServer", at=@At(value="INVOKE", target="Lnet/minecraft/server/level/ServerLevel;isSpawningMonsters()Z"))
    private boolean test$spawning(ServerLevel level) { return true; }
}
