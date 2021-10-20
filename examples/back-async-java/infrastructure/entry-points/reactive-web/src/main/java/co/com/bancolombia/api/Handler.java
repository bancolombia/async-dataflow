package co.com.bancolombia.api;

import co.com.bancolombia.usecase.business.BusinessUseCase;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.BodyInserters;
import org.springframework.web.reactive.function.server.ServerRequest;
import org.springframework.web.reactive.function.server.ServerResponse;
import reactor.core.publisher.Mono;

@Component
@RequiredArgsConstructor
public class Handler {
    private final BusinessUseCase useCase;

    public Mono<ServerResponse> listenBusiness(ServerRequest serverRequest) {

        return ServerResponse.accepted()
                .body(
                        useCase.asyncBusinessFlow(serverRequest.queryParam("delay").orElse("5000"),
                                serverRequest.queryParam("channel_ref").orElse("")),
                        String.class);
    }


    public Mono<ServerResponse> listenGenerateCredentials(ServerRequest serverRequest) {
        return useCase.generateCredentials(serverRequest.queryParam("user_ref").toString())
                .flatMap(credentials -> responseHandler(credentials, HttpStatus.OK));

    }

    public static <T> Mono<ServerResponse> responseHandler(T response, HttpStatus status) {
        return ServerResponse.status(status)
                .contentType(MediaType.APPLICATION_JSON)
                .body(BodyInserters.fromValue(response))
                .switchIfEmpty(ServerResponse.notFound().build());
    }
}
