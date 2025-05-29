package co.com.bancolombia.events;


import co.com.bancolombia.secretsmanager.api.GenericManager;
import co.com.bancolombia.secretsmanager.connector.AWSSecretManagerConnector;
import lombok.SneakyThrows;
import org.reactivecommons.async.rabbit.config.RabbitProperties;
import org.reactivecommons.async.rabbit.config.props.AsyncPropsDomain;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.util.StringUtils;

import java.util.Map;

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
        rabbitProperties.setHost((String) secret.get("host"));
        rabbitProperties.setPort(((Double)secret.get("port")).intValue());
        rabbitProperties.setUsername((String) secret.get("username"));
        rabbitProperties.setPassword((String) secret.get("password"));
        rabbitProperties.setVirtualHost((String) secret.get("virtualhost"));
        rabbitProperties.getSsl().setEnabled((Boolean) secret.get("ssl"));
        return rabbitProperties;
    }
}
