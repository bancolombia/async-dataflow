Event xxxx

```json
{
    "requestContext": {
        "routeKey": "auth",
        "messageId": "HEJvQdEmoAMCJPQ=",
        "eventType": "MESSAGE",
        "extendedRequestId": "HEJvQHXKoAMEi7A=",
        "requestTime": "07/Mar/2025:16:47:42 +0000",
        "messageDirection": "IN",
        "stage": "dev",
        "connectedAt": 1741365800627,
        "requestTimeEpoch": 1741366062027,
        "identity": {
            "userAgent": "insomnium/0.2.3-a",
            "sourceIp": "191.94.0.73"
        },
        "requestId": "HEJvQHXKoAMEi7A=",
        "domainName": "5nn096u8h6.execute-api.us-east-1.amazonaws.com",
        "connectionId": "HEJGadx-IAMCJPQ=",
        "apiId": "5nn096u8h6"
    },
    "body": "{\n 
       "action" : "auth",\n    "data" : {\n        "room" : "room12345"\n   }\n}",
    "isBase64Encoded": False
}
```

Connected:

```json
{
    "headers": {
        "Host": "5nn096u8h6.execute-api.us-east-1.amazonaws.com",
        "Sec-WebSocket-Extensions": "permessage-deflate; client_max_window_bits",
        "Sec-WebSocket-Key": "GUa6in8K5oSsqWhn4Xu4hw==",
        "Sec-WebSocket-Version": "13",
        "User-Agent": "insomnium/0.2.3-a",
        "X-Amzn-Trace-Id": "Root=1-67cb271e-1c39194673f190e36f64e47b",
        "X-Forwarded-For": "191.94.0.73",
        "X-Forwarded-Port": "443",
        "X-Forwarded-Proto": "https"
    },
    "multiValueHeaders": {
        "Host": [
            "5nn096u8h6.execute-api.us-east-1.amazonaws.com"
        ],
        "Sec-WebSocket-Extensions": [
            "permessage-deflate; client_max_window_bits"
        ],
        "Sec-WebSocket-Key": [
            "GUa6in8K5oSsqWhn4Xu4hw=="
        ],
        "Sec-WebSocket-Version": [
            "13"
        ],
        "User-Agent": [
            "insomnium/0.2.3-a"
        ],
        "X-Amzn-Trace-Id": [
            "Root=1-67cb271e-1c39194673f190e36f64e47b"
        ],
        "X-Forwarded-For": [
            "191.94.0.73"
        ],
        "X-Forwarded-Port": [
            "443"
        ],
        "X-Forwarded-Proto": [
            "https"
        ]
    },
    "queryStringParameters": {
        "channel": "abc"
    },
    "multiValueQueryStringParameters": {
        "channel": [
            "abc"
        ]
    },
    "requestContext": {
        "routeKey": "$connect",
        "eventType": "CONNECT",
        "extendedRequestId": "HEMM0GseIAMESYg=",
        "requestTime": "07/Mar/2025:17:04:30 +0000",
        "messageDirection": "IN",
        "stage": "dev",
        "connectedAt": 1741367070493,
        "requestTimeEpoch": 1741367070493,
        "identity": {
            "userAgent": "insomnium/0.2.3-a",
            "sourceIp": "191.94.0.73"
        },
        "requestId": "HEMM0GseIAMESYg=",
        "domainName": "5nn096u8h6.execute-api.us-east-1.amazonaws.com",
        "connectionId": "HEMM0fIjIAMCFvA=",
        "apiId": "5nn096u8h6"
    },
    "isBase64Encoded": false
}
```

aws apigatewayv2 update-route \
    --route-id 2ztsq79 \
    --api-id 5nn096u8h6 \
    --request-parameters '{"route.request.querystring.channel": {"Required": true}}'

aws apigatewayv2 update-integration \
    --integration-id 3rtexxr \
    --api-id 5nn096u8h6 \
    --request-parameters 'integration.request.header.channel'='route.request.querystring.channel'


aws apigatewaymanagementapi delete-connection \
    --endpoint-url https://zf2fc0xj0i.execute-api.us-east-1.amazonaws.com/beta \
    --connection-id HLc8-HNyoAMEFhA=

aws apigatewaymanagementapi post-to-connection \
    --endpoint-url https://zf2fc0xj0i.execute-api.us-east-1.amazonaws.com/beta \
    --connection-id HLc81fyBIAMCECQ= --data 'eyJtZXNzYWdlIjogImhlbGxvIn0K'