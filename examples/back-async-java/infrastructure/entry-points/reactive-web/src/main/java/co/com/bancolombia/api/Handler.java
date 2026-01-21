package co.com.bancolombia.api;

import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.BodyInserters;
import org.springframework.web.reactive.function.server.ServerRequest;
import org.springframework.web.reactive.function.server.ServerResponse;
import reactor.core.publisher.Mono;
import co.com.bancolombia.usecase.business.BusinessUseCase;

import java.util.UUID;

@Component
@RequiredArgsConstructor
public class Handler {
    private final BusinessUseCase useCase;

    public Mono<ServerResponse> listenBusiness(ServerRequest serverRequest) {

        return ServerResponse.accepted()
                .body(
                        useCase.asyncBusinessFlow(serverRequest.queryParam("delay").orElse("5000"),
                                serverRequest.queryParam("channel_ref").orElse(""),
                                serverRequest.queryParam("user_ref").toString(),
                                serverRequest.queryParam("correlationId").orElse(UUID.randomUUID().toString())),
                        String.class);
    }


    public Mono<ServerResponse> listenGenerateCredentials(ServerRequest serverRequest) {
        return useCase.generateCredentials(serverRequest.queryParam("user_ref").toString())
                .flatMap(credentials -> responseHandler(credentials, HttpStatus.OK));

    }

    public Mono<ServerResponse> listenBusinessTwoEvents(ServerRequest serverRequest) {
        return ServerResponse.accepted()
                .body(
                        useCase.asyncBusinessFlowTwoEvents(
                                serverRequest.queryParam("delay").orElse("5000"),
                                serverRequest.queryParam("channel_ref").orElse(""),
                                serverRequest.queryParam("user_ref").toString(),
                                serverRequest.queryParam("correlationId").orElse(UUID.randomUUID().toString())),
                        String.class);
    }

    public static <T> Mono<ServerResponse> responseHandler(T response, HttpStatus status) {
        return ServerResponse.status(status)
                .contentType(MediaType.APPLICATION_JSON)
                .body(BodyInserters.fromValue(response))
                .switchIfEmpty(ServerResponse.notFound().build());
    }
}
