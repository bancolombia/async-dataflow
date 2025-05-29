package co.com.bancolombia.events;


import co.com.bancolombia.secretsmanager.api.GenericManager;
import co.com.bancolombia.secretsmanager.connector.AWSSecretManagerConnector;
import lombok.SneakyThrows;
import lombok.extern.java.Log;
import org.reactivecommons.async.rabbit.config.RabbitProperties;
import org.reactivecommons.async.rabbit.config.props.AsyncPropsDomain;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.util.StringUtils;

import java.util.Map;

@Log
@Configuration
@ConditionalOnProperty(value = "adapter.reply-mode", havingValue = "BRIDGE")
public class BridgeMQConfig {

    @Bean
    public GenericManager genericManager() {
        String endpoint = System.getenv("AWS_ENDPOINT");
        if (StringUtils.hasText(endpoint)) {
            return new AWSSecretManagerConnector(System.getenv("AWS_REGION"), endpoint);
        }
        return new AWSSecretManagerConnector(System.getenv("AWS_REGION"));
    }

    @Bean
    @Primary
    public AsyncPropsDomain.RabbitSecretFiller filler(GenericManager manager) {
        return (s, genericAsyncProps) -> {
            if (StringUtils.hasText(genericAsyncProps.getSecret())) {
                genericAsyncProps.setConnectionProperties(loadProperties(manager, genericAsyncProps.getSecret()));
            }
        };
    }

    @SneakyThrows
    private RabbitProperties loadProperties(GenericManager manager, String secretName) {
        RabbitProperties rabbitProperties = new RabbitProperties();
        Map<String, Object> secret = manager.getSecret(secretName, Map.class);
        if (secret == null || secret.isEmpty()) {
            throw new IllegalArgumentException("Secret not found or empty: " + secretName);
        }
        log.info("Loading RabbitMQ properties from secret: " + secretName);
        log.info("RabbitMQ properties: " + secret.keySet());
        rabbitProperties.setHost((String) secret.get("hostname"));
        log.info("RabbitMQ hostname: " + secret.get("hostname"));
        rabbitProperties.setPort(Integer.parseInt((String) secret.get("port")));
        rabbitProperties.setUsername((String) secret.get("username"));
        rabbitProperties.setPassword((String) secret.get("password"));
        rabbitProperties.setVirtualHost((String) secret.get("virtualhost"));
        rabbitProperties.getSsl().setEnabled((Boolean) secret.get("ssl"));
        return rabbitProperties;
    }
}
