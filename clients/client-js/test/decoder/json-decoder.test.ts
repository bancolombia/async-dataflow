import * as chai from 'chai';

import { MessageDecoder, JsonDecoder } from "../../src/decoder/index.js";
import { ChannelMessage } from "../../src/channel-message.js";

const assert = chai.assert;
describe('Json Serializer Tests', function () {

    const serializer: MessageDecoder = new JsonDecoder()

    it('Should decode basic string payload', () => {
        const payload = "[\"ids332msg1\", \"\", \"person.registered\", \"someData\"]";
        const event = new MessageEvent('test', {
            data: payload
        });
        const message = serializer.decode(event);
        assert.deepEqual(message, new ChannelMessage("ids332msg1", "person.registered", "", "someData"));
    });

    it('Should decode basic sse string payload', () => {
        const sse_event = {
            id: undefined,
            data: '["aa6db9ef-bbad-41dc-9099-4e28bbb9c37b","7595b125-e503-4a0b-a4d5-c92edd5591c2","businessEvent",{"code":"100","title":"process after 500","severity":"INFO","detail":"some detail 014438cd-ed20-488a-8237-c8cb9e4d18c5"}]',
            event: 'message',
            retry: undefined
        }
        const message = serializer.decode_sse(sse_event.data);
        assert.deepEqual(message, new ChannelMessage("aa6db9ef-bbad-41dc-9099-4e28bbb9c37b", "businessEvent", "7595b125-e503-4a0b-a4d5-c92edd5591c2", { "code": "100", "title": "process after 500", "severity": "INFO", "detail": "some detail 014438cd-ed20-488a-8237-c8cb9e4d18c5" }));
    });
});
