package co.com.bancolombia.usecase.business;

import co.com.bancolombia.model.async.Credentials;
import co.com.bancolombia.model.async.DeliverMessage;
import co.com.bancolombia.model.async.Message;
import co.com.bancolombia.model.async.gateways.AsyncDataFlowGateway;
import lombok.RequiredArgsConstructor;
import lombok.extern.java.Log;
import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;

import java.time.Duration;
import java.util.UUID;

@Log
@RequiredArgsConstructor
public class BusinessUseCase {
    private final AsyncDataFlowGateway asyncDataFlowGateway;

    public Mono<Credentials> generateCredentials(String userIdentifier) {
        return asyncDataFlowGateway.generateCredentials(userIdentifier);
    }

    public Mono<Object> asyncBusinessFlow(String delay, String channelRef, String userRef) {
        log.info("Delaying async flow message: " + channelRef);
        Mono.delay(Duration.ofMillis(Integer.parseInt(delay)))
                .then(Mono.defer(() -> {
                    log.info("Delivering async flow message: " + channelRef);
                    DeliverMessage deliverMessage = DeliverMessage.builder()
                            .messageId(UUID.randomUUID().toString())
                            .CorrelationId(UUID.randomUUID().toString())
                            .messageData(Message.builder()
                                    .code("100")
                                    .title("process after " + delay)
                                    .detail("some detail " + UUID.randomUUID())
                                    .severity("INFO")
                                    .build())
                            .channelRef(channelRef)
                            .eventName("businessEvent")
                            .build();

                    return asyncDataFlowGateway.deliverMessage(channelRef, userRef, deliverMessage)
                            .doOnSuccess(ignored -> log.info("Async flow message delivered: " + channelRef));

                }))
                .subscribeOn(Schedulers.boundedElastic())
                .subscribe();
        return Mono.empty();
    }
}
