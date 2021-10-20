/* The default serializer for encoding and decoding messages */


import {ChannelMessage} from "./channel-message";

export interface MessageDecoder {
    decode(event: MessageEvent) : ChannelMessage;
    // encode(message: ChannelMessage): any;
}
