package co.com.bancolombia.events.model;

import org.reactivecommons.api.domain.RawMessage;

import java.util.HashMap;
import java.util.Map;

public class CustomMessage extends HashMap<String, Object> implements RawMessage {
    private final String type;

    public CustomMessage(Map<? extends String, ?> m, String type) {
        super(m);
        this.type = type;
    }

    @Override
    public String getType() {
        return type;
    }
}
