import * as chai from 'chai';

import {JsonDecoder} from "../src/json-decoder";
import {ChannelMessage} from "../src/channel-message";
import {MessageDecoder} from "../src/serializer";
import {MessageEvent} from "./support/event"

const assert = chai.assert;
describe('Json Serializer Tests', function()  {

    const serializer: MessageDecoder = new JsonDecoder()

    it('Should decode basic string payload' , () => {
        let payload = "[\"ids332msg1\", \"\", \"person.registered\", \"someData\"]";
        // @ts-ignore
        const event  = new MessageEvent('test', {
            data : payload
        });
        const message = serializer.decode(event);
        assert.deepEqual(message, new ChannelMessage("ids332msg1", "person.registered", "", "someData"));
    });

});
