package dev.qxf19.noreinforcements.test.mixin;
import dev.qxf19.noreinforcements.test.ReinforcementsTest;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.EntitySpawnReason;
import net.minecraft.world.level.Level;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;
@Mixin(EntityType.class)
public class EntityTypeTestMixin {
    @Inject(method="create(Lnet/minecraft/world/level/Level;Lnet/minecraft/world/entity/EntitySpawnReason;)Lnet/minecraft/world/entity/Entity;", at=@At("HEAD"), cancellable=true)
    private void test$count(Level level, EntitySpawnReason reason, CallbackInfoReturnable<Entity> cir) {
        if (ReinforcementsTest.damageTest && reason == EntitySpawnReason.REINFORCEMENT) {
            ReinforcementsTest.creationAttempts++;
            cir.setReturnValue(null);
        }
    }
}
