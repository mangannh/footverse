-- Sprint 12: order-line unit cost snapshot (database-spec §10.12/§12, sprint-12-plan Design
-- Decision 2). A margin is unit_price - unit_cost_price *as of the moment of sale*. order_item
-- already snapshots unit_price, product_name, color, and size precisely so history can never be
-- restated -- but until now it carried no cost at all.
--
-- This column is deliberately left NULL FOREVER for existing rows -- there is NO back-fill
-- statement here, unlike V3's cost_price migration. Every order placed before this migration has
-- no recoverable cost basis: seeding it from product_variant.cost_price's *current* value would
-- write a number that was never true, and once written it would be indistinguishable from a real
-- checkout snapshot -- corrupted history silently reported as fact. NULL is the honest encoding
-- of "this line predates cost tracking"; a future consumer (Sprint 13) must treat it as "unknown
-- cost", never as zero. The column therefore also stays nullable going forward: every order
-- placed from this migration onward gets an exact, non-null value written once at checkout
-- (OrderServiceImpl), but the column itself can never be tightened to NOT NULL without lying
-- about the rows that came before it.

ALTER TABLE order_item
    ADD COLUMN unit_cost_price DECIMAL(12, 2) NULL;
