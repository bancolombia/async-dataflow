package co.com.bancolombia.config;


import io.netty.handler.timeout.ReadTimeoutHandler;
import io.netty.handler.timeout.WriteTimeoutHandler;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpHeaders;
import org.springframework.http.client.reactive.ClientHttpConnector;
import org.springframework.http.client.reactive.ReactorClientHttpConnector;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.netty.http.client.HttpClient;

import static io.netty.channel.ChannelOption.CONNECT_TIMEOUT_MILLIS;
import static java.util.concurrent.TimeUnit.MILLISECONDS;

@Configuration
@Slf4j
public class RestConsumerConfig {

    public static final String BRIDGE = "BRIDGE";
    @Value("${adapter.restconsumer.url}")
    private String url;
    @Value("${adapter.restconsumer.url-bridge}")
    private String urlBridge;
    @Value("${adapter.restconsumer.timeout}")
    private int timeout;
    @Value("${adapter.reply-mode}")
    private String mode;

    @Bean
    public WebClient getWebClient() {
        String resolvedUrl = BRIDGE.equals(mode) ? urlBridge : url;
        return WebClient.builder()
                .baseUrl(resolvedUrl)
                .defaultHeader(HttpHeaders.CONTENT_TYPE, "application/json")
                .clientConnector(getClientHttpConnector())
                .build();
    }

    private ClientHttpConnector getClientHttpConnector() {
        /*
        IF YO REQUIRE APPEND SSL CERTIFICATE SELF SIGNED
        SslContext sslContext = SslContextBuilder.forClient().trustManager(InsecureTrustManagerFactory.INSTANCE)
                .build();*/
        return new ReactorClientHttpConnector(HttpClient.create()
                //.secure(sslContextSpec -> sslContextSpec.sslContext(sslContext))
                .compress(true)
                .keepAlive(true)
                .option(CONNECT_TIMEOUT_MILLIS, timeout)
                .doOnConnected(connection -> {
                    connection.addHandlerLast(new ReadTimeoutHandler(timeout, MILLISECONDS));
                    connection.addHandlerLast(new WriteTimeoutHandler(timeout, MILLISECONDS));
                }));
    }

}
