package dev.qxf19.noreinforcements.mixin;

import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.entity.monster.zombie.Zombie;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

/** This point is reached only after the superclass accepted and applied damage.
 * The remainder of Zombie.hurtServer handles reinforcements and returns true.
 * Exiting here also prevents Forge/NeoForge summon-aid events overriding chance.
 */
@Mixin(Zombie.class)
public abstract class ZombieMixin {
    @Inject(method = "hurtServer", at = @At(value = "INVOKE", target =
        "Lnet/minecraft/world/entity/monster/zombie/Zombie;getTarget()Lnet/minecraft/world/entity/LivingEntity;"), cancellable = true, require = 1)
    private void noReinforcements$stopAfterDamage(ServerLevel level, DamageSource source, float amount, CallbackInfoReturnable<Boolean> cir) {
        cir.setReturnValue(true);
    }
}
