/* The Json serializer for encoding and decoding messages */


import { ChannelMessage } from "../channel-message";
import { MessageDecoder } from "./message-decoder";

export class JsonDecoder implements MessageDecoder {

    public decode(messageEvent: MessageEvent): ChannelMessage {
        console.log('JsonDecoder.decode', messageEvent.data); // TODO: manage json parse errors
        const [message_id, correlation_id, event, payload] = JSON.parse(messageEvent.data);
        return new ChannelMessage(message_id, event, correlation_id, payload);
    }

    public decode_sse(sse_event: string): ChannelMessage {
        const [message_id, correlation_id, event, payload] = JSON.parse(sse_event);
        return new ChannelMessage(message_id, event, correlation_id, payload);
    }
}

