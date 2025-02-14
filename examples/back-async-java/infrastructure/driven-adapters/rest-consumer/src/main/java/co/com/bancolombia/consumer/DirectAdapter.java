package co.com.bancolombia.consumer;

import co.com.bancolombia.consumer.models.DTOCredentials;
import co.com.bancolombia.consumer.models.DTODeliverMessage;
import co.com.bancolombia.consumer.models.ObjectRequest;
import co.com.bancolombia.consumer.models.ObjectResponse;
import co.com.bancolombia.model.async.Credentials;
import co.com.bancolombia.model.async.DeliverMessage;
import co.com.bancolombia.model.async.gateways.AsyncDataFlowGateway;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

@Service
@RequiredArgsConstructor
@ConditionalOnProperty(value = "adapter.reply-mode", havingValue = "DIRECT")
public class DirectAdapter implements AsyncDataFlowGateway {
    @Value("${spring.application.name}")
    public String applicationRef;

    private final WebClient client;


    // these methods are an example that illustrates the implementation of WebClient.
    // You should use the methods that you implement from the Gateway from the domain.

    public Mono<ObjectResponse> testGet() {
        return client
                .get()
                .retrieve()
                .bodyToMono(ObjectResponse.class);
    }

    @Override
    public Mono<Credentials> generateCredentials(String userIdentifier) {
        ObjectRequest request = ObjectRequest.builder()
                .application_ref(applicationRef)
                .user_ref(userIdentifier)
                .build();

        return client
                .post().uri("/create")
                .body(Mono.just(request), ObjectRequest.class)
                .retrieve()
                .bodyToMono(DTOCredentials.class)
                .map(DirectAdapter::mapperToCredentials);
    }

    @Override
    public Mono<Void> deliverMessage(String channelRef, String userRef, DeliverMessage deliverMessage) {
        return client
                .post().uri("/deliver_message")
                .bodyValue(mapperDTO(deliverMessage))
                .retrieve().toBodilessEntity().then();
    }

    private static DTODeliverMessage mapperDTO(DeliverMessage deliverMessage) {
        return DTODeliverMessage.builder()
                .channelRef(deliverMessage.getChannelRef())
                .correlationId(deliverMessage.getCorrelationId())
                .eventName(deliverMessage.getEventName())
                .messageId(deliverMessage.getMessageId())
                .messageData(deliverMessage.getMessageData())
                .build();
    }

    private static Credentials mapperToCredentials(DTOCredentials dtoCredentials) {
        return Credentials.builder().channelRef(dtoCredentials.getChannelRef()).channelSecret(dtoCredentials.getChannelSecret()).build();
    }


}