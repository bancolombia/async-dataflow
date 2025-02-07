package co.com.bancolombia.consumer.models;

import com.fasterxml.jackson.annotation.JsonAlias;
import lombok.Data;

@Data
public class DTOCredentials {
    @JsonAlias("channel_ref")
    String channelRef;
    @JsonAlias("channel_secret")
    String channelSecret;
}
