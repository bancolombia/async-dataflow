package co.com.bancolombia.consumer.models;

import com.fasterxml.jackson.annotation.JsonAlias;
import lombok.Builder;
import lombok.Data;

@Data
@Builder(toBuilder = true)
public class ObjectRequest {
    private String application_ref;
    private String user_ref;
}
