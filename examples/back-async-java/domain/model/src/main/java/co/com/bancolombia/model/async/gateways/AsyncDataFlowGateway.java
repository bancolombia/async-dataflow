package co.com.bancolombia.model.async.gateways;

import co.com.bancolombia.model.async.Credentials;
import co.com.bancolombia.model.async.DeliverMessage;
import reactor.core.publisher.Mono;

public interface AsyncDataFlowGateway {
    Mono<Credentials> generateCredentials(String user_identifier);

    Mono<Void> deliverMessage(String channelRef, String userRef, DeliverMessage message);
}
