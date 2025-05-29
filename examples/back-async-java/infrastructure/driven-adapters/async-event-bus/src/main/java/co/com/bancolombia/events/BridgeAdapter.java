package co.com.bancolombia.events;

import co.com.bancolombia.events.model.CustomMessage;
import co.com.bancolombia.events.model.DTODeliverMessage;
import co.com.bancolombia.events.model.ObjectResponse;
import co.com.bancolombia.model.async.Credentials;
import co.com.bancolombia.model.async.DeliverMessage;
import co.com.bancolombia.model.async.gateways.AsyncDataFlowGateway;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.cloudevents.CloudEvent;
import io.cloudevents.core.builder.CloudEventBuilder;
import io.cloudevents.jackson.JsonCloudEventData;
import lombok.RequiredArgsConstructor;
import lombok.extern.java.Log;
import org.reactivecommons.api.domain.DomainEventBus;
import org.reactivecommons.async.impl.config.annotations.EnableDomainEventBus;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

import java.net.URI;
import java.time.OffsetDateTime;
import java.util.Map;
import java.util.Random;
import java.util.UUID;

import static reactor.core.publisher.Mono.from;

@Log
@RequiredArgsConstructor
@EnableDomainEventBus
@ConditionalOnProperty(value = "adapter.reply-mode", havingValue = "BRIDGE")
public class BridgeAdapter implements AsyncDataFlowGateway {
    public static final String SOME_EVENT_NAME = "ch-ms-async-callback.svp.reply";
    private final DomainEventBus domainEventBus;
    private final ObjectMapper om;
    private final WebClient client;
    @Value("${spring.application.name}")
    public String applicationRef;
    private static final Random random = new Random();

    @Override
    public Mono<Credentials> generateCredentials(String userIdentifier) {
        return client
                .post().uri("/ext/channel")
                .header("application-id", applicationRef)
                .header("session-tracker", userIdentifier)
                .header("document-id", generateUserId())
                .header("document-type", "CC")
                .retrieve()
                .bodyToMono(ObjectResponse.class)
                .map(BridgeAdapter::mapperToCredentials);
    }

    @Override
    public Mono<Void> deliverMessage(String channelRef, String userRef, DeliverMessage message) {
        DTODeliverMessage deliverMessage = DTODeliverMessage.builder()
                .request(new DTODeliverMessage.Request(userRef))
                .reply(DTODeliverMessage.Reply.builder()
                        .correlationId(message.getCorrelationId())
                        .eventName(message.getEventName())
                        .messageData(message.getMessageData())
                        .messageId(message.getMessageId())
                        .build())
                .build();

        CloudEvent eventCloudEvent = CloudEventBuilder.v1()
                .withId(UUID.randomUUID().toString())
                .withSource(URI.create("https://reactive-commons.org/foos"))
                .withType(SOME_EVENT_NAME)
                .withTime(OffsetDateTime.now())
                .withData("application/json", JsonCloudEventData.wrap(om.valueToTree(deliverMessage)))
                .build();

        return from(domainEventBus.emit(eventCloudEvent));
    }

    @Override
    public Mono<Void> deliverCloudEvent(String messageType, Map<String, Object> message) {
        CustomMessage rawMessage = new CustomMessage(message, messageType);
        return from(domainEventBus.emit(rawMessage));
    }

    private static Credentials mapperToCredentials(ObjectResponse dtoCredentials) {
        return Credentials.builder()
                .channelRef(dtoCredentials.getResult().getChannelRef())
                .channelSecret(dtoCredentials.getResult().getChannelSecret())
                .build();
    }

    private static String generateUserId() {
        int length = random.nextInt(3) + 8;
        StringBuilder randomNumber = new StringBuilder();

        for (int i = 0; i < length; i++) {
            int digit = random.nextInt(10);
            randomNumber.append(digit);
        }
        return randomNumber.toString();
    }
}
