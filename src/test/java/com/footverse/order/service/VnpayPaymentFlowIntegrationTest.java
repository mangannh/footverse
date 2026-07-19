package com.footverse.order.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.math.BigDecimal;
import java.util.LinkedHashMap;
import java.util.Map;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import com.footverse.common.security.JwtUtil;
import com.footverse.order.entity.PaymentTransaction;
import com.footverse.order.entity.PaymentTransactionStatus;
import com.footverse.order.repository.CouponRepository;
import com.footverse.order.repository.PaymentTransactionRepository;
import com.footverse.product.repository.ProductVariantRepository;
import com.footverse.support.AuthFixtures;
import com.footverse.user.repository.UserRepository;
import com.jayway.jsonpath.JsonPath;

/**
 * End-to-end VNPay sandbox payment flow through the real filter chain, services, and database (no
 * mocks, sprint-13-plan Task 09) — placed in the {@code order.service} package deliberately, the same
 * package as the package-private {@link VnpaySigner}, so the return callback can be signed with the
 * production canonicalization exactly as the task requires ("only sign with {@code VnpaySigner} and a
 * test secret" — no VNPay sandbox is ever contacted).
 *
 * <p>Walks two flows: (1) place a {@code VNPAY} order, request its payment URL, simulate the
 * gateway's signed return, and read the order back {@code PAID}; (2) place a {@code VNPAY} order with
 * a coupon, request its payment URL (creating a {@code PENDING} transaction), cancel the order, and
 * assert the transaction is failed alongside the frozen stock-restore and coupon-usage compensation.
 * Runs in a rolled-back transaction so no state leaks (the {@code CheckoutFlowIntegrationTest}
 * precedent).</p>
 */
@SpringBootTest
@AutoConfigureMockMvc
@Transactional
class VnpayPaymentFlowIntegrationTest {

    private static final String ADMIN_EMAIL = "vnpay-admin@example.com";
    private static final String ADMIN_PHONE = "0900000099";
    private static final String CUSTOMER_EMAIL = "vnpay-customer@example.com";
    private static final String CUSTOMER_PHONE = "0900000101";

    private static final String COUPON_CODE = "FVVNPAY";
    private static final String COUPON_BODY = """
            {"code":"FVVNPAY","name":"VNPay Save","discountType":"FIXED","discountValue":10000,
             "minOrderAmount":0,"startAt":"2020-01-01T00:00:00","endAt":"2030-01-01T00:00:00","enabled":true}
            """;
    private static final String ADDRESS_BODY = """
            {"recipientName":"Jane Doe","recipientPhone":"0912345678","province":"HCM",
             "district":"D1","ward":"W1","streetAddress":"1 Nguyen Hue"}
            """;

    private final MockMvc mockMvc;
    private final JwtUtil jwtUtil;
    private final UserRepository userRepository;
    private final ProductVariantRepository productVariantRepository;
    private final CouponRepository couponRepository;
    private final PaymentTransactionRepository paymentTransactionRepository;
    private final String vnpayHashSecret;

    VnpayPaymentFlowIntegrationTest(@Autowired MockMvc mockMvc, @Autowired JwtUtil jwtUtil,
            @Autowired UserRepository userRepository,
            @Autowired ProductVariantRepository productVariantRepository,
            @Autowired CouponRepository couponRepository,
            @Autowired PaymentTransactionRepository paymentTransactionRepository,
            @Value("${footverse.vnpay.hash-secret}") String vnpayHashSecret) {
        this.mockMvc = mockMvc;
        this.jwtUtil = jwtUtil;
        this.userRepository = userRepository;
        this.productVariantRepository = productVariantRepository;
        this.couponRepository = couponRepository;
        this.paymentTransactionRepository = paymentTransactionRepository;
        this.vnpayHashSecret = vnpayHashSecret;
    }

    @BeforeEach
    void persistUsers() {
        userRepository.save(AuthFixtures.admin(ADMIN_EMAIL, ADMIN_PHONE));
        userRepository.save(AuthFixtures.customer(CUSTOMER_EMAIL, CUSTOMER_PHONE));
    }

    private String adminToken() {
        return "Bearer " + jwtUtil.createAccessToken(ADMIN_EMAIL);
    }

    private String customerToken() {
        return "Bearer " + jwtUtil.createAccessToken(CUSTOMER_EMAIL);
    }

    /** Performs an authenticated {@code POST} that must answer {@code 201 Created}, returning its id. */
    private long create(String path, String token, String json) throws Exception {
        String body = mockMvc.perform(post(path)
                        .header(HttpHeaders.AUTHORIZATION, token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return ((Number) JsonPath.read(body, "$.data.id")).longValue();
    }

    /** Seeds a minimal category/brand/product/one ACTIVE in-stock variant/image hierarchy as ADMIN. */
    private long seedVariant() throws Exception {
        long categoryId = create("/api/v1/categories", adminToken(),
                "{\"name\":\"VNPay Sneakers\",\"description\":\"flow category\"}");
        long brandId = create("/api/v1/brands", adminToken(), "{\"name\":\"VNPay Nike\"}");
        long productId = create("/api/v1/products", adminToken(),
                "{\"name\":\"FV VNPay Runner\",\"description\":\"flow product\",\"basePrice\":100000.00,"
                        + "\"categoryId\":" + categoryId + ",\"brandId\":" + brandId + "}");
        long variantId = create("/api/v1/products/" + productId + "/variants", adminToken(),
                "{\"color\":\"Black\",\"size\":\"42\",\"stockQuantity\":10,\"sku\":\"FV-VP-A\","
                        + "\"status\":\"ACTIVE\",\"costPrice\":40.00}");
        create("/api/v1/products/" + productId + "/images", adminToken(),
                "{\"imageUrl\":\"http://img/vnpay-primary.png\",\"displayOrder\":0,\"isPrimary\":true}");
        return variantId;
    }

    /** Adds the given variant and quantity to the customer's cart. */
    private void addToCart(long variantId, int quantity) throws Exception {
        mockMvc.perform(post("/api/v1/cart/items")
                        .header(HttpHeaders.AUTHORIZATION, customerToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"productVariantId\":" + variantId + ",\"quantity\":" + quantity + "}"))
                .andExpect(status().isOk());
    }

    /** Reads the caller's cart and returns the cart-line id holding the given variant. */
    private long cartItemIdForVariant(long variantId) throws Exception {
        String body = mockMvc.perform(get("/api/v1/cart").header(HttpHeaders.AUTHORIZATION, customerToken()))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        return ((Number) JsonPath.<java.util.List<Object>>read(
                body, "$.data.items[?(@.productVariantId == " + variantId + ")].id").get(0)).longValue();
    }

    /** Returns a variant's current persisted stock. */
    private int stockOf(long variantId) {
        return productVariantRepository.findById(variantId).orElseThrow().getStockQuantity();
    }

    /** Signs a minimal VNPay return parameter set with the real configured hash secret. */
    private Map<String, String> signedReturnParams(String txnRef, BigDecimal amount, String responseCode) {
        Map<String, String> params = new LinkedHashMap<>();
        params.put("vnp_Amount", amount.multiply(new BigDecimal("100")).toBigInteger().toString());
        params.put("vnp_ResponseCode", responseCode);
        params.put("vnp_TransactionNo", "14000555");
        params.put("vnp_TxnRef", txnRef);
        params.put("vnp_SecureHash", VnpaySigner.sign(params, vnpayHashSecret));
        return params;
    }

    /**
     * Places a {@code VNPAY} order, requests its payment URL, simulates the gateway's signed return,
     * and confirms the order reads back {@code PAID} through {@code GET /orders/{id}} — the server,
     * never the client, decides the outcome (business-rules → Payment).
     */
    @Test
    void placingAVnpayOrderPayingItAndReadingItBackShowsPaid() throws Exception {
        long variantId = seedVariant();
        long addressId = create("/api/v1/addresses", customerToken(), ADDRESS_BODY);
        addToCart(variantId, 1);
        long cartItemId = cartItemIdForVariant(variantId);

        String checkoutBody = "{\"cartItemIds\":[" + cartItemId + "],\"addressId\":" + addressId
                + ",\"paymentMethod\":\"VNPAY\"}";
        String orderJson = mockMvc.perform(post("/api/v1/orders")
                        .header(HttpHeaders.AUTHORIZATION, customerToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(checkoutBody))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.paymentMethod").value("VNPAY"))
                .andExpect(jsonPath("$.data.paymentStatus").value("UNPAID"))
                .andReturn().getResponse().getContentAsString();
        long orderId = ((Number) JsonPath.read(orderJson, "$.data.id")).longValue();

        String urlJson = mockMvc.perform(post("/api/v1/orders/" + orderId + "/payment")
                        .header(HttpHeaders.AUTHORIZATION, customerToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.paymentUrl").isNotEmpty())
                .andReturn().getResponse().getContentAsString();
        String txnRef = JsonPath.read(urlJson, "$.data.txnRef");

        PaymentTransaction transaction = paymentTransactionRepository.findByTxnRef(txnRef).orElseThrow();
        assertThat(transaction.getStatus()).isEqualTo(PaymentTransactionStatus.PENDING);

        Map<String, String> returnParams = signedReturnParams(txnRef, transaction.getAmount(), "00");
        mockMvc.perform(get("/api/v1/payments/vnpay/return")
                        .param("vnp_Amount", returnParams.get("vnp_Amount"))
                        .param("vnp_ResponseCode", returnParams.get("vnp_ResponseCode"))
                        .param("vnp_TransactionNo", returnParams.get("vnp_TransactionNo"))
                        .param("vnp_TxnRef", returnParams.get("vnp_TxnRef"))
                        .param("vnp_SecureHash", returnParams.get("vnp_SecureHash")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.success").value(true))
                .andExpect(jsonPath("$.data.orderId").value((int) orderId));

        mockMvc.perform(get("/api/v1/orders/" + orderId).header(HttpHeaders.AUTHORIZATION, customerToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.paymentStatus").value("PAID"));

        // Replaying the identical signed return is a no-op returning the same outcome.
        mockMvc.perform(get("/api/v1/payments/vnpay/return")
                        .param("vnp_Amount", returnParams.get("vnp_Amount"))
                        .param("vnp_ResponseCode", returnParams.get("vnp_ResponseCode"))
                        .param("vnp_TransactionNo", returnParams.get("vnp_TransactionNo"))
                        .param("vnp_TxnRef", returnParams.get("vnp_TxnRef"))
                        .param("vnp_SecureHash", returnParams.get("vnp_SecureHash")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.success").value(true));
    }

    /**
     * Cancelling a {@code PENDING} {@code VNPAY} order fails its pending payment transaction and still
     * restores stock and coupon usage exactly as a {@code COD} cancellation does (Sprint 13 Task 09).
     */
    @Test
    void cancellingAVnpayOrderFailsThePendingTransactionAndRestoresStockAndCoupon() throws Exception {
        long variantId = seedVariant();
        create("/api/v1/coupons", adminToken(), COUPON_BODY);
        long addressId = create("/api/v1/addresses", customerToken(), ADDRESS_BODY);
        addToCart(variantId, 2);
        long cartItemId = cartItemIdForVariant(variantId);

        String checkoutBody = "{\"cartItemIds\":[" + cartItemId + "],\"addressId\":" + addressId
                + ",\"couponCode\":\"" + COUPON_CODE + "\",\"paymentMethod\":\"VNPAY\"}";
        String orderJson = mockMvc.perform(post("/api/v1/orders")
                        .header(HttpHeaders.AUTHORIZATION, customerToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(checkoutBody))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        long orderId = ((Number) JsonPath.read(orderJson, "$.data.id")).longValue();
        assertThat(stockOf(variantId)).isEqualTo(8);
        assertThat(couponRepository.findByCode(COUPON_CODE).orElseThrow().getUsedCount()).isEqualTo(1);

        String urlJson = mockMvc.perform(post("/api/v1/orders/" + orderId + "/payment")
                        .header(HttpHeaders.AUTHORIZATION, customerToken()))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        String txnRef = JsonPath.read(urlJson, "$.data.txnRef");

        mockMvc.perform(post("/api/v1/orders/" + orderId + "/cancel")
                        .header(HttpHeaders.AUTHORIZATION, customerToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("CANCELLED"))
                .andExpect(jsonPath("$.data.paymentStatus").value("UNPAID"));

        PaymentTransaction transaction = paymentTransactionRepository.findByTxnRef(txnRef).orElseThrow();
        assertThat(transaction.getStatus()).isEqualTo(PaymentTransactionStatus.FAILED);
        assertThat(stockOf(variantId)).isEqualTo(10);
        assertThat(couponRepository.findByCode(COUPON_CODE).orElseThrow().getUsedCount()).isEqualTo(0);
    }
}
