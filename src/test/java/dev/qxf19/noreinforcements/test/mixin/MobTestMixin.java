package dev.qxf19.noreinforcements.test.mixin;
import dev.qxf19.noreinforcements.test.ReinforcementsTest;
import net.minecraft.world.entity.Mob;
import net.minecraft.world.entity.LivingEntity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;
@Mixin(Mob.class)
public class MobTestMixin {
    @Inject(method="getTarget", at=@At("HEAD"), cancellable=true)
    private void test$target(CallbackInfoReturnable<LivingEntity> cir) {
        if (ReinforcementsTest.damageTest) cir.setReturnValue(ReinforcementsTest.target);
    }
}
