-- Sprint 11: add the ADMIN-only unit cost basis to product_variant (database-spec §10.8).
-- Added nullable first so existing rows can be back-filled to the variant's effective selling
-- price (price_override when set, otherwise the owning product's base_price), then tightened to
-- NOT NULL. On an empty schema the UPDATE affects no rows and the column is enforced going forward.

ALTER TABLE product_variant
    ADD COLUMN cost_price DECIMAL(12, 2) NULL;

UPDATE product_variant pv
    JOIN product p ON p.id = pv.product_id
SET pv.cost_price = COALESCE(pv.price_override, p.base_price);

ALTER TABLE product_variant
    MODIFY COLUMN cost_price DECIMAL(12, 2) NOT NULL;
