package co.com.bancolombia.model.async;

import lombok.Builder;
import lombok.Getter;

@Builder(toBuilder = true)
@Getter
public class DeliverMessage {
    private final String channelRef;
    private final String messageId;
    private final String CorrelationId;
    private final Message messageData;
    private final String eventName;
}
