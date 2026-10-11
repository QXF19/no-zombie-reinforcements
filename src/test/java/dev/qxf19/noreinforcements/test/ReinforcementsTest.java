package dev.qxf19.noreinforcements.test;

import java.lang.reflect.Field;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import net.minecraft.SharedConstants;
import net.minecraft.server.Bootstrap;
import net.minecraft.resources.Identifier;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.monster.zombie.Zombie;
import net.minecraft.util.RandomSource;
import net.minecraft.world.phys.Vec3;
import net.minecraft.world.entity.ai.attributes.AttributeInstance;
import net.minecraft.world.entity.ai.attributes.AttributeMap;
import net.minecraft.world.entity.ai.attributes.AttributeModifier;
import net.minecraft.world.entity.ai.attributes.AttributeSupplier;
import net.minecraft.world.entity.ai.attributes.Attributes;
import sun.misc.Unsafe;

/** Runs through the real Fabric class loader, before opening a server or world. */
public final class ReinforcementsTest {
    public static boolean damageTest;
    public static boolean acceptDamage = true;
    public static boolean forceChance;
    public static int creationAttempts;
    public static LivingEntity target;
    public static void run() {
        try {
            SharedConstants.tryDetectVersion();
            Bootstrap.bootStrap();
            if (Boolean.getBoolean("verification.platform")) {
                try {
                    Class.forName("net.neoforged.neoforge.server.loading.ServerModLoader")
                        .getMethod("load", boolean.class).invoke(null, false);
                } catch (ClassNotFoundException forge) {
                    Class.forName("net.minecraftforge.server.loading.ServerModLoader")
                        .getMethod("load").invoke(null);
                }
            }
            boolean enabled = Boolean.getBoolean("verification.mod");
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
                setField(entity, Entity.class, "random", RandomSource.create(12345));
                setField(entity, Entity.class, "position", Vec3.ZERO);
                setField(entity, Entity.class, "type", net.minecraft.core.registries.BuiltInRegistries.ENTITY_TYPE.getValue(Identifier.fromNamespaceAndPath("minecraft", "zombified_piglin")));
                target = entity;
                damageTest = true;
                for (boolean forced : List.of(false, true)) {
                    forceChance = forced;
                    creationAttempts = 0;
                    for (int hit = 0; hit < 1000; hit++) {
                        if (!((Zombie)entity).hurtServer(null, null, 1.0F)) {
                            throw new AssertionError(mob + " damage return changed");
                        }
                    }
                    int expectedAttempts = enabled && !(forced && Boolean.getBoolean("verification.original")) ? 0 : 1000;
                    if (creationAttempts != expectedAttempts) throw new AssertionError(
                        mob + " damage path forced=" + forced + ": expected " + expectedAttempts + ", got " + creationAttempts);
                    checks.add(mob + ": 1000 damage calls, forced chance=" + forced + ", creation attempts=" + creationAttempts);
                }
                forceChance = false;
                acceptDamage = false;
                creationAttempts = 0;
                if (((Zombie)entity).hurtServer(null, null, 1.0F) || creationAttempts != 0) {
                    throw new AssertionError(mob + " rejected damage result changed");
                }
                acceptDamage = true;
                checks.add(mob + ": rejected damage returns false, no creation");
                damageTest = false;
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

    private static void setField(Object entity, Class<?> owner, String name, Object value) throws Exception {
        Field field = owner.getDeclaredField(name);
        field.setAccessible(true);
        field.set(entity, value);
    }

    private static void equal(double actual, double expected, String label) {
        if (Double.compare(actual, expected) != 0) {
            throw new AssertionError(label + ": expected " + expected + ", got " + actual);
        }
    }
}
