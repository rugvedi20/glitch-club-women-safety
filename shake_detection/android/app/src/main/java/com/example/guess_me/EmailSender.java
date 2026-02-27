package com.example.guess_me;

import android.util.Log;
import java.util.Properties;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import javax.mail.Authenticator;
import javax.mail.Message;
import javax.mail.MessagingException;
import javax.mail.PasswordAuthentication;
import javax.mail.Session;
import javax.mail.Transport;
import javax.mail.internet.InternetAddress;
import javax.mail.internet.MimeMessage;

public class EmailSender {
    private static final String TAG = "EmailSender";

    private static final String SMTP_HOST = "smtp.gmail.com";
    private static final int SMTP_PORT = 587;
    private static final boolean USE_TLS = true;
    private static final String USERNAME = "desk.atharv16@gmail.com";
    private static final String PASSWORD = "pgvv cryb qglz izil";
    private static final String FROM = "desk.atharv16@gmail.com";
    private static final String TO = "maneatharv36@gmail.com";

    private static final ExecutorService EXECUTOR = Executors.newSingleThreadExecutor();

    public static void sendAsync(String subject, String body) {
        EXECUTOR.execute(() -> {
            try {
                Session session = buildSession();
                Message message = new MimeMessage(session);
                message.setFrom(new InternetAddress(FROM));
                message.setRecipients(Message.RecipientType.TO, InternetAddress.parse(TO));
                message.setSubject(subject);
                message.setText(body);
                Transport.send(message);
                Log.i(TAG, "Email sent: " + subject);
            } catch (Exception e) {
                Log.e(TAG, "Failed to send email", e);
            }
        });
    }

    private static Session buildSession() {
        Properties props = new Properties();
        props.put("mail.smtp.auth", "true");
        props.put("mail.smtp.starttls.enable", String.valueOf(USE_TLS));
        props.put("mail.smtp.host", SMTP_HOST);
        props.put("mail.smtp.port", String.valueOf(SMTP_PORT));
        return Session.getInstance(props, new Authenticator() {
            @Override
            protected PasswordAuthentication getPasswordAuthentication() {
                return new PasswordAuthentication(USERNAME, PASSWORD);
            }
        });
    }
}
