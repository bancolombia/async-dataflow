package co.com.bancolombia.usecase.business;

import co.com.bancolombia.model.async.Credentials;
import co.com.bancolombia.model.async.DeliverMessage;
import co.com.bancolombia.model.async.Message;
import co.com.bancolombia.model.async.gateways.AsyncDataFlowGateway;
import lombok.RequiredArgsConstructor;
import reactor.core.Disposable;
import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;

import java.util.UUID;

@RequiredArgsConstructor
public class BusinessUseCase {
    private final AsyncDataFlowGateway asyncDataFlowGateway;

    public Mono<Credentials> generateCredentials(String user_identifier) {
        return asyncDataFlowGateway.generateCredentials(user_identifier);
    }

    public Mono<Object> asyncBusinessFlow(String delay, String channelRef) {
        return Mono.empty().doOnSuccess(serverResponse -> processAsyncIOBlocking(Integer.parseInt(delay), channelRef));
    }

    private Disposable processAsyncIOBlocking(int delay, String channelRef) {
        return Mono.fromRunnable(() -> doThisAsync(delay, channelRef).subscribe()).subscribeOn(Schedulers.boundedElastic()).subscribe();
    }

    private Mono<Void> doThisAsync(int delay, String channelRef) {
        try {
            Thread.sleep(delay);
            DeliverMessage deliverMessage = DeliverMessage.builder()
                    .messageId(UUID.randomUUID().toString())
                    .CorrelationId(UUID.randomUUID().toString())
                    .messageData(Message.builder().code("100").title("process after "+ delay).detail("some detail " +UUID.randomUUID().toString()).severity("INFO").build())
                    .channelRef(channelRef)
                    .eventName("businessEvent")
                    .build();

            return asyncDataFlowGateway.deliverMessage(channelRef, deliverMessage);

        } catch (InterruptedException e) {
            e.printStackTrace();
        }

        return Mono.empty();
    }
}
