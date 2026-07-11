-- V2: Variant color migration (2026-07-11 catalog architecture amendment).
-- color becomes an attribute of product_variant so one product carries all of its colorways
-- (previously each color had to be a separate product). Variant uniqueness widens from
-- (product_id, size) to (product_id, color, size), and order_item snapshots the color at
-- checkout (database-spec §10.8, §10.12, §12).
--
-- Additive and non-destructive: existing rows are backfilled with the placeholder color
-- 'Default' (the old (product_id, size) key was strictly narrower, so the backfill cannot
-- collide under the new key); the transient DEFAULT is dropped immediately so the column
-- stays NOT NULL with no default, matching the entity mapping.

-- 1. product_variant.color
ALTER TABLE product_variant
    ADD COLUMN color VARCHAR(50) NOT NULL DEFAULT 'Default' AFTER product_id;
ALTER TABLE product_variant
    ALTER COLUMN color DROP DEFAULT;

-- 2. Variant uniqueness: (product_id, size) → (product_id, color, size).
-- Drop and add happen in ONE statement: fk_product_variant_product needs an index prefixed by
-- product_id at all times, and the single ALTER swaps the keys atomically so the new key
-- satisfies the FK the moment the old one goes.
ALTER TABLE product_variant
    DROP KEY uk_product_variant_product_id_size,
    ADD UNIQUE KEY uk_product_variant_product_id_color_size (product_id, color, size);

-- 3. order_item.color snapshot (frozen at checkout, database-spec §12)
ALTER TABLE order_item
    ADD COLUMN color VARCHAR(50) NOT NULL DEFAULT 'Default' AFTER product_image_url;
ALTER TABLE order_item
    ALTER COLUMN color DROP DEFAULT;
