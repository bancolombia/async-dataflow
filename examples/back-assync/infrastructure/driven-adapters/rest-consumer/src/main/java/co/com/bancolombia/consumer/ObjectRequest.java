package co.com.bancolombia.consumer;

    import lombok.Builder;
    import lombok.Data;

    @Data
    @Builder(toBuilder = true)
public class ObjectRequest {

private String application_ref;
private String user_ref;

}
