package com.footverse.common.mail;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Component;

/**
 * The real {@link EmailSender}, delegating to Spring's {@link JavaMailSender}. Active only when
 * {@code footverse.mail.enabled} is explicitly {@code true} — an environment that has deliberately
 * supplied SMTP credentials via the externalized {@code FOOTVERSE_MAIL_*} environment variables
 * (sprint-13-plan Task 04). Never active by default.
 */
@Component
@ConditionalOnProperty(name = "footverse.mail.enabled", havingValue = "true")
public class SmtpEmailSender implements EmailSender {

    private final JavaMailSender mailSender;
    private final String fromAddress;

    /**
     * Creates the SMTP sender.
     *
     * @param mailSender  the Spring-Boot-autoconfigured mail sender (backed by {@code spring.mail.*})
     * @param fromAddress the externalized sender address ({@code footverse.mail.from})
     */
    public SmtpEmailSender(JavaMailSender mailSender, @Value("${footverse.mail.from}") String fromAddress) {
        this.mailSender = mailSender;
        this.fromAddress = fromAddress;
    }

    @Override
    public void send(String to, String subject, String body) {
        SimpleMailMessage message = new SimpleMailMessage();
        message.setFrom(fromAddress);
        message.setTo(to);
        message.setSubject(subject);
        message.setText(body);
        mailSender.send(message);
    }
}
