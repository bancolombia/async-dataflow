/* The Binary serializer for encoding and decoding messages */


import { ChannelMessage } from "../channel-message.js";
import { MessageDecoder } from "./message-decoder.js";

export class BinaryDecoder implements MessageDecoder {

    private readonly textDecoder: TextDecoder;

    constructor() {
        this.textDecoder = new TextDecoder();
    }

    public decode(messageEvent: MessageEvent): ChannelMessage {
        const buffer: ArrayBuffer = messageEvent.data;
        const view = new DataView(buffer)

        const control = view.getUint8(0);
        if (control != 255) {
            throw new Error('Invalid binary data; no control byte match')
        }

        const extractor: Extractor = new Extractor(this.textDecoder, buffer, 4);
        const message_id = extractor.decodeChunk(view.getUint8(1));
        const correlation_id = extractor.decodeChunk(view.getUint8(2));
        const event = extractor.decodeChunk(view.getUint8(3));
        const payload = extractor.decodeChunk(null);

        return new ChannelMessage(message_id, event, correlation_id, payload);
    }

    public decode_sse(sse_event: any): ChannelMessage {
        console.log('Binary Decoder. decoding sse not supported');
        return null;
    }
}

class Extractor {
    constructor(private readonly textDecoder: TextDecoder,
        private readonly buffer: ArrayBuffer,
        private offset: number) {
    }

    public decodeChunk(size: number): string {
        if (size === 0) {
            return "";
        }
        const endIndex = size ? this.offset + size : this.buffer.byteLength + 1;
        const data = this.textDecoder.decode(this.buffer.slice(this.offset, endIndex));
        this.offset = endIndex;
        return data;
    }
}

