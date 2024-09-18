package co.com.bancolombia.consumer.models;

import co.com.bancolombia.model.async.Message;
import com.fasterxml.jackson.annotation.JsonAlias;
import com.fasterxml.jackson.databind.PropertyNamingStrategy;
import com.fasterxml.jackson.databind.annotation.JsonNaming;
import lombok.Builder;
import lombok.Data;
import lombok.Getter;

@Data
@Builder
@Getter
@JsonNaming(PropertyNamingStrategy.SnakeCaseStrategy.class)
public class DTODeliverMessage {
    String channelRef;
    String messageId;
    String correlationId;
    Message messageData;
    String eventName;
}
