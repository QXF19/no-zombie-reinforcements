package dev.qxf19.noreinforcements.mixin;

import net.minecraft.core.Holder;
import net.minecraft.world.entity.ai.attributes.Attribute;
import net.minecraft.world.entity.ai.attributes.AttributeMap;
import net.minecraft.world.entity.ai.attributes.Attributes;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(AttributeMap.class)
public abstract class AttributeMapMixin {
    // Also cover supplier defaults before an AttributeInstance is materialized.
    @Inject(method = "getValue(Lnet/minecraft/core/Holder;)D", at = @At("HEAD"),
            cancellable = true, require = 1)
    private void noReinforcements$getValue(Holder<Attribute> attribute,
                                         CallbackInfoReturnable<Double> cir) {
        if (attribute.equals(Attributes.SPAWN_REINFORCEMENTS_CHANCE)) {
            cir.setReturnValue(0.0D);
        }
    }
}
