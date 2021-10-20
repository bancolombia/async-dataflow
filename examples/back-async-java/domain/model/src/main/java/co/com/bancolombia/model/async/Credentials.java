package co.com.bancolombia.model.async;

import lombok.Builder;
import lombok.Getter;

@Builder(toBuilder = true)
@Getter
public class Credentials {
    private final String channelRef;
    private final String channelSecret;
}
