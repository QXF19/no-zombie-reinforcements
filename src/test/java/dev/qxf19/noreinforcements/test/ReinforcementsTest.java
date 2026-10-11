package dev.qxf19.noreinforcements.test;

import java.lang.reflect.Field;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import net.fabricmc.api.ModInitializer;
import net.fabricmc.loader.api.FabricLoader;
import net.minecraft.SharedConstants;
import net.minecraft.server.Bootstrap;
import net.minecraft.resources.Identifier;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.ai.attributes.AttributeInstance;
import net.minecraft.world.entity.ai.attributes.AttributeMap;
import net.minecraft.world.entity.ai.attributes.AttributeModifier;
import net.minecraft.world.entity.ai.attributes.AttributeSupplier;
import net.minecraft.world.entity.ai.attributes.Attributes;
import sun.misc.Unsafe;

/** Runs through the real Fabric class loader, before opening a server or world. */
public final class ReinforcementsTest implements ModInitializer {
    @Override
    public void onInitialize() {
        try {
            SharedConstants.tryDetectVersion();
            Bootstrap.bootStrap();
            boolean enabled = FabricLoader.getInstance().isModLoaded("no_zombie_reinforcements");
            double expected = enabled ? 0.0 : 1.0;
            List<String> checks = new ArrayList<>();
            AttributeSupplier supplier = LivingEntity.createLivingAttributes()
                .add(Attributes.SPAWN_REINFORCEMENTS_CHANCE, 1.0).build();
            AttributeMap defaults = new AttributeMap(supplier);
            equal(defaults.getValue(Attributes.SPAWN_REINFORCEMENTS_CHANCE), expected, "supplier default");
            checks.add("supplier default");

            Field unsafeField = Unsafe.class.getDeclaredField("theUnsafe");
            unsafeField.setAccessible(true);
            Unsafe unsafe = (Unsafe) unsafeField.get(null);
            Field attributesField = LivingEntity.class.getDeclaredField("attributes");
            attributesField.setAccessible(true);
            for (String mob : List.of("Zombie", "Husk", "Drowned", "ZombieVillager", "ZombifiedPiglin")) {
                Class<?> type;
                try { type = Class.forName("net.minecraft.world.entity.monster.zombie." + mob); }
                catch (ClassNotFoundException oldPackage) {
                    type = Class.forName("net.minecraft.world.entity.monster." + mob);
                }
                LivingEntity entity = (LivingEntity) unsafe.allocateInstance(type);
                AttributeMap map = new AttributeMap(supplier);
                attributesField.set(entity, map);
                AttributeInstance chance = map.getInstance(Attributes.SPAWN_REINFORCEMENTS_CHANCE);
                chance.setBaseValue(1.0);
                chance.addPermanentModifier(new AttributeModifier(
                    Identifier.fromNamespaceAndPath("test", "leader_bonus"), 0.75,
                    AttributeModifier.Operation.ADD_VALUE));
                equal(entity.getAttributeValue(Attributes.SPAWN_REINFORCEMENTS_CHANCE), expected, mob + " entity query");
                equal(chance.getValue(), expected, mob + " direct instance query");
                equal(chance.getBaseValue(), 1.0, mob + " stored base preserved");
                if (chance.getModifiers().size() != 1) throw new AssertionError("Modifier removed: " + mob);
                AttributeInstance restored = new AttributeInstance(Attributes.SPAWN_REINFORCEMENTS_CHANCE, ignored -> {});
                restored.apply(chance.pack());
                equal(restored.getValue(), expected, mob + " saved/reloaded instance");
                AttributeInstance health = map.getInstance(Attributes.MAX_HEALTH);
                health.setBaseValue(40.0);
                health.addTransientModifier(new AttributeModifier(
                    Identifier.fromNamespaceAndPath("test", "health_bonus"), 2.0,
                    AttributeModifier.Operation.ADD_VALUE));
                equal(entity.getAttributeValue(Attributes.MAX_HEALTH), 42.0, mob + " other attributes unchanged");
                checks.add(mob + ": entity query, direct query, base/modifier preservation, save/reload, health control");
            }
            String report = "PASS: Minecraft " + SharedConstants.getCurrentVersion().id()
                + ", mod=" + enabled + "\n" + String.join("\n", checks) + "\n";
            Files.writeString(Path.of("verification.txt"), report);
            System.out.println(report);
            System.exit(0);
        } catch (Throwable error) {
            error.printStackTrace();
            System.exit(1);
        }
    }

    private static void equal(double actual, double expected, String label) {
        if (Double.compare(actual, expected) != 0) {
            throw new AssertionError(label + ": expected " + expected + ", got " + actual);
        }
    }
}
