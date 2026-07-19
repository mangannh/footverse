package com.footverse.common.mail;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * The default {@link EmailSender}: logs the message and returns, touching no real mail server.
 * Active whenever {@code footverse.mail.enabled} is absent or {@code false} — which is every
 * environment that has not explicitly opted into SMTP, including every test and every local run
 * that has not read the docs (sprint-13-plan Task 04 Design Decision 4). A developer can walk the
 * whole password-reset flow by reading the one-time code out of the application log.
 *
 * <p>This is a safety mechanism, not a convenience: it is what makes it structurally impossible
 * for a default configuration to send a real email.</p>
 */
@Component
@ConditionalOnProperty(name = "footverse.mail.enabled", havingValue = "false", matchIfMissing = true)
public class LoggingEmailSender implements EmailSender {

    private static final Logger log = LoggerFactory.getLogger(LoggingEmailSender.class);

    @Override
    public void send(String to, String subject, String body) {
        log.info("Email (not sent — footverse.mail.enabled=false) to={} subject={} body={}", to, subject, body);
    }
}
