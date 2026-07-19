package com.footverse.common.mail;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.ApplicationContext;
import org.springframework.test.context.TestPropertySource;

/**
 * Proves the other half of the {@code footverse.mail.enabled} switch (sprint-13-plan Task 04,
 * Design Decision 4): when an environment explicitly opts in, {@link SmtpEmailSender} becomes the
 * active {@link EmailSender} bean and {@link LoggingEmailSender} does not exist in the context.
 * This test never calls {@link EmailSender#send}, so no real email is ever attempted even here.
 */
@SpringBootTest
@TestPropertySource(properties = {
        "footverse.mail.enabled=true",
        "footverse.mail.from=test@example.com"
})
class SmtpEmailSenderEnabledTest {

    @Autowired
    private ApplicationContext context;

    @Autowired
    private EmailSender emailSender;

    /**
     * The injected {@link EmailSender} is the SMTP implementation once explicitly enabled.
     */
    @Test
    void smtpEmailSenderIsTheActiveBeanWhenExplicitlyEnabled() {
        assertThat(emailSender).isInstanceOf(SmtpEmailSender.class);
    }

    /**
     * {@link LoggingEmailSender} is not instantiated at all once mail is explicitly enabled.
     */
    @Test
    void loggingEmailSenderIsNotInstantiatedWhenMailIsEnabled() {
        assertThat(context.getBeanNamesForType(LoggingEmailSender.class)).isEmpty();
    }
}
