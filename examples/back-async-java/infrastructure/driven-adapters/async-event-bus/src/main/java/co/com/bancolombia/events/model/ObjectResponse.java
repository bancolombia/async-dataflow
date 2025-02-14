package co.com.bancolombia.events.model;

import com.fasterxml.jackson.annotation.JsonAlias;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder(toBuilder = true)
@NoArgsConstructor
@AllArgsConstructor
public class ObjectResponse {
    private Credentials result;

    @Data
    public static class Credentials {
        @JsonAlias("channel_ref")
        String channelRef;
        @JsonAlias("channel_secret")
        String channelSecret;
    }
}