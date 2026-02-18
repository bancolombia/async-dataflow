/* The Json serializer for encoding and decoding messages */


import { ChannelMessage } from "../channel-message.js";
import { MessageDecoder } from "./message-decoder.js";

export class JsonDecoder implements MessageDecoder {

    public decode(messageEvent: MessageEvent): ChannelMessage {
        const [message_id, correlation_id, event, payload] = JSON.parse(messageEvent.data);
        return new ChannelMessage(message_id, event, correlation_id, payload);
    }

    public decode_sse(sse_event: string): ChannelMessage {
        const [message_id, correlation_id, event, payload] = JSON.parse(sse_event);
        return new ChannelMessage(message_id, event, correlation_id, payload);
    }
}

