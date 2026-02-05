package co.com.bancolombia.consumer.models;

import co.com.bancolombia.model.async.Message;
import lombok.Builder;
import lombok.Data;
import lombok.Getter;
import tools.jackson.databind.PropertyNamingStrategies;
import tools.jackson.databind.annotation.JsonNaming;

@Data
@Builder
@Getter
@JsonNaming(PropertyNamingStrategies.SnakeCaseStrategy.class)
public class DTODeliverMessage {
    String channelRef;
    String messageId;
    String correlationId;
    Message messageData;
    String eventName;
}