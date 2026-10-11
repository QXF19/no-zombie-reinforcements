package dev.qxf19.noreinforcements.test.mixin;
import dev.qxf19.noreinforcements.test.ReinforcementsTest;
import net.minecraft.core.Holder;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.ai.attributes.Attribute;
import net.minecraft.world.entity.ai.attributes.Attributes;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;
@Mixin(LivingEntity.class)
public class LivingEntityTestMixin {
    @Inject(method="hurtServer", at=@At("HEAD"), cancellable=true)
    private void test$damage(ServerLevel level, DamageSource source, float amount, CallbackInfoReturnable<Boolean> cir) {
        if (ReinforcementsTest.damageTest) cir.setReturnValue(ReinforcementsTest.acceptDamage);
    }
    @Inject(method="getAttributeValue", at=@At("HEAD"), cancellable=true)
    private void test$force(Holder<Attribute> attribute, CallbackInfoReturnable<Double> cir) {
        if (ReinforcementsTest.forceChance && attribute.equals(Attributes.SPAWN_REINFORCEMENTS_CHANCE)) cir.setReturnValue(1.0);
    }
}
