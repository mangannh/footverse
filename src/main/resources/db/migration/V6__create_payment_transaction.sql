-- Sprint 13 Task 08: VNPay sandbox payment-attempt persistence (database-spec §10.17). One row per
-- payment attempt; a new attempt on the same order supersedes the previous PENDING row (marked
-- FAILED) rather than reusing it, keeping a complete attempt history. Mirrors order_item (V1) for
-- the order_id foreign key: CASCADE, since a transaction cannot exist without its order.

CREATE TABLE payment_transaction (
    id               BIGINT         NOT NULL AUTO_INCREMENT,
    order_id         BIGINT         NOT NULL,
    txn_ref          VARCHAR(64)    NOT NULL,
    provider         VARCHAR(20)    NOT NULL,
    amount           DECIMAL(12, 2) NOT NULL,
    status           VARCHAR(20)    NOT NULL,
    provider_txn_no  VARCHAR(64)    NULL,
    response_code    VARCHAR(20)    NULL,
    paid_at          DATETIME(6)    NULL,
    created_at       DATETIME(6)    NOT NULL,
    updated_at       DATETIME(6)    NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_payment_transaction_txn_ref (txn_ref),
    KEY idx_payment_transaction_order_id (order_id),
    CONSTRAINT fk_payment_transaction_orders FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
