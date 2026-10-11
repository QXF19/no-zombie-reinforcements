package dev.qxf19.noreinforcements.mixin;

import net.minecraft.core.Holder;
import net.minecraft.world.entity.ai.attributes.Attribute;
import net.minecraft.world.entity.ai.attributes.AttributeInstance;
import net.minecraft.world.entity.ai.attributes.Attributes;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Shadow;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(AttributeInstance.class)
public abstract class AttributeInstanceMixin {
    @Shadow
    public abstract Holder<Attribute> getAttribute();

    // Suppress the computed probability, including leader and command modifiers.
    // The stored base value and modifiers remain intact when the mod is removed.
    @Inject(method = "getValue()D", at = @At("HEAD"), cancellable = true, require = 1)
    private void noReinforcements$getValue(CallbackInfoReturnable<Double> cir) {
        if (getAttribute().equals(Attributes.SPAWN_REINFORCEMENTS_CHANCE)) {
            cir.setReturnValue(0.0D);
        }
    }
}
