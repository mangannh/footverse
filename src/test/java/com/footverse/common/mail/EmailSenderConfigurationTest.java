package com.footverse.common.mail;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.ApplicationContext;

/**
 * Proves the default mail configuration (sprint-13-plan Task 04, Design Decision 4): with
 * {@code footverse.mail.enabled} left unset — the shape of every test and every local run that
 * has not opted in — {@link LoggingEmailSender} is the active {@link EmailSender} bean and
 * {@link SmtpEmailSender} does not even exist in the context, so it is structurally impossible for
 * this configuration to send a real email.
 */
@SpringBootTest
class EmailSenderConfigurationTest {

    @Autowired
    private ApplicationContext context;

    @Autowired
    private EmailSender emailSender;

    /**
     * The injected {@link EmailSender} is the logging implementation by default.
     */
    @Test
    void loggingEmailSenderIsTheActiveBeanByDefault() {
        assertThat(emailSender).isInstanceOf(LoggingEmailSender.class);
    }

    /**
     * {@link SmtpEmailSender} is not instantiated at all when {@code footverse.mail.enabled} is
     * unset — not merely inactive, but absent from the context.
     */
    @Test
    void smtpEmailSenderIsNotInstantiatedWhenMailIsNotEnabled() {
        assertThat(context.getBeanNamesForType(SmtpEmailSender.class)).isEmpty();
    }
}
