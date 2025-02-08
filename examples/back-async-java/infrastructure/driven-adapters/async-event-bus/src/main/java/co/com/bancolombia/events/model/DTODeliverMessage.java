package co.com.bancolombia.events.model;

import co.com.bancolombia.model.async.Message;
import lombok.Builder;
import lombok.Data;
import lombok.Getter;

import java.util.HashMap;
import java.util.Map;

@Data
@Builder
@Getter
public class DTODeliverMessage {
    private final Request request;
    private final Reply reply;

    @Data
    public static class Request {
        Map<String, String> headers = new HashMap<>();
        Map<String, String> body = new HashMap<>();

        public Request(String userRef) {
            headers.put("session-tracker", userRef);
        }
    }

    @Data
    @Builder
    public static class Reply {
        String channelRef;
        String messageId;
        String correlationId;
        Message messageData;
        String eventName;
    }
}

/*
{
  "data": {
    "request": {
      "headers": {
        "channel": "BLM",
        "application-id": "abc321",
        "session-tracker": "dbb3e0a4-c3fb-4c87-86b9-cc82c54eda91",
        "documentType": "CC",
        "documentId": "198961",
        "async-type": "command",
        "target": "some.ms",
        "operation": "some operation"
      },
      "body": {
        "say": "Hi"
      }
    },
    "reply": {
      "msg": "Hello World"
    }
  },
  "dataContentType": "application/json",
  "id": "1",
  "invoker": "invoker1",
  "source": "source1",
  "specVersion": "0.1",
  "time": "xxx",
  "type": "type1"
}

 */