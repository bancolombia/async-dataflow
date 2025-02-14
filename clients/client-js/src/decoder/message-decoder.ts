/* The default serializer for encoding and decoding messages */


import { ChannelMessage } from "../channel-message";

export interface MessageDecoder {
    decode(event: MessageEvent): ChannelMessage;
    decode_sse(event: any): ChannelMessage;
}
