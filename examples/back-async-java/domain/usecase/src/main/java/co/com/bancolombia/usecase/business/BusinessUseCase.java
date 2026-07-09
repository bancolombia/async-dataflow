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
import java.util.Random;
import java.util.UUID;

@Log
@RequiredArgsConstructor
public class BusinessUseCase {
    private final AsyncDataFlowGateway asyncDataFlowGateway;
    private static final Random random = new Random();

    public Mono<Credentials> generateCredentials(String userIdentifier) {
        return asyncDataFlowGateway.generateCredentials(userIdentifier);
    }

    public Mono<Object> asyncBusinessFlow(String delay, String channelRef, String userRef, String correlationId) {
        log.info("Delaying async flow message: " + channelRef);
        Mono.delay(Duration.ofMillis(Integer.parseInt(delay)))
                .then(Mono.defer(() -> {
                    log.info("Delivering async flow message: " + channelRef);
                    DeliverMessage deliverMessage = DeliverMessage.builder()
                            .messageId(UUID.randomUUID().toString())
                            .CorrelationId(correlationId)
                            .messageData(Message.builder()
                                    .code("100")
                                    .title("process after " + delay)
                                    .detail("response for id:" + correlationId)
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

    /**
     * Delivers two different events to the same channel sequentially.
     * This simulates a scenario where a user makes a request and receives two different async responses.
     * 
     * @param delay Delay in milliseconds before sending the events
     * @param channelRef Channel reference to deliver messages to
     * @param userRef User reference
     * @param correlationId Correlation ID for both events
     * @return Empty Mono
     */
    public Mono<Object> asyncBusinessFlowTwoEvents(String delay, String channelRef, String userRef, String correlationId) {
        log.info("Delaying async flow with two events for channel: " + channelRef);
        
        Mono.delay(Duration.ofMillis(Integer.parseInt(delay)))
                .then(Mono.defer(() -> {
                    log.info("Delivering first event to channel: " + channelRef);
                    
                    // First event - Process Started
                    DeliverMessage firstEvent = DeliverMessage.builder()
                            .messageId(UUID.randomUUID().toString())
                            .CorrelationId(correlationId)
                            .messageData(Message.builder()
                                    .code("100")
                                    .title("ch-ms-async-callback.svp.p2p")
                                    .detail("Your request is being processed - correlation: " + correlationId)
                                    .severity("INFO")
                                    .build())
                            .channelRef(channelRef)
                            .eventName("ch-ms-async-callback.svp.p2p")
                            .build();

                    
                    
                    // Second event - Process Completed
                    DeliverMessage secondEvent = DeliverMessage.builder()
                            .messageId(UUID.randomUUID().toString())
                            .CorrelationId(correlationId)
                            .messageData(Message.builder()
                                    .code("200")
                                    .title("ch-ms-async-callback.svp.p2m")
                                    .detail("Your request has been successfully processed - correlation: " + correlationId)
                                    .severity("SUCCESS")
                                    .build())
                            .channelRef(channelRef)
                            .eventName("ch-ms-async-callback.svp.p2m")
                            .build();
                    
                    // Deliver first event, then second event after a small delay
                    return asyncDataFlowGateway.deliverMessage(channelRef, userRef, firstEvent)
                            .doOnSuccess(ignored -> log.info("First event delivered to channel: " + channelRef))
                            .then(Mono.delay(Duration.ofMillis(random.nextInt(10001)))) // Random delay between 0-10 seconds
                            .then(asyncDataFlowGateway.deliverMessage(channelRef, userRef, secondEvent))
                            .doOnSuccess(ignored -> log.info("Second event delivered to channel: " + channelRef))
                            .doOnSuccess(ignored -> log.info("Both events successfully delivered to channel: " + channelRef));
                }))
                .subscribeOn(Schedulers.boundedElastic())
                .subscribe();
        
        return Mono.empty();
    }
}
