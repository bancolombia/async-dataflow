/* The Json serializer for encoding and decoding messages */


import {ChannelMessage} from "./channel-message";
import {MessageDecoder} from "./serializer";

export class JsonDecoder implements MessageDecoder {

    public decode(messageEvent: MessageEvent): ChannelMessage {
        const [message_id, correlation_id, event, payload] = JSON.parse(messageEvent.data);
        return new ChannelMessage(message_id, event, correlation_id, payload);
    }
}

