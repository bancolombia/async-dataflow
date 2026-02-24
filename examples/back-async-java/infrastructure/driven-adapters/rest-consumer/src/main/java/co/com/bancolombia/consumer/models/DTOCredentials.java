package co.com.bancolombia.consumer.models;

import lombok.Data;
import tools.jackson.databind.PropertyNamingStrategies;
import tools.jackson.databind.annotation.JsonNaming;

@Data
@JsonNaming(PropertyNamingStrategies.SnakeCaseStrategy.class)
public class DTOCredentials {
    String channelRef;
    String channelSecret;
}