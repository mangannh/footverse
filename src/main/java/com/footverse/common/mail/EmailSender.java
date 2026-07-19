package com.footverse.common.mail;

/**
 * Sends a plain-text email — the one infrastructure boundary the forgot-password flow (Sprint 13)
 * needs, placed in {@code common} alongside {@code common.security} (architecture-spec §4/§7).
 * Callers depend on this interface only and know nothing about SMTP.
 *
 * <p>Exactly one implementation is active at a time, selected by {@code footverse.mail.enabled}:
 * {@link LoggingEmailSender} (the default, which touches no real mail server) or
 * {@link SmtpEmailSender} (active only when explicitly enabled).</p>
 */
public interface EmailSender {

    /**
     * Sends a plain-text email.
     *
     * @param to      the recipient address
     * @param subject the subject line
     * @param body    the plain-text body
     */
    void send(String to, String subject, String body);
}
