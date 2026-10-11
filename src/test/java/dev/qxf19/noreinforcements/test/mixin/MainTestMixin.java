package dev.qxf19.noreinforcements.test.mixin;
import dev.qxf19.noreinforcements.test.ReinforcementsTest;
import net.minecraft.server.Main;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;
@Mixin(Main.class)
public class MainTestMixin {
    @Inject(method="main", at=@At("HEAD"))
    private static void test$start(String[] args, CallbackInfo ci) { ReinforcementsTest.run(); }
}
