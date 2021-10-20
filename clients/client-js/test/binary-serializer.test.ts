import * as chai from 'chai';

import {ChannelMessage} from "../src/channel-message";
import {MessageDecoder} from "../src/serializer";
import {MessageEvent} from "./support/event"
import {BinaryDecoder} from "../src/binary-decoder";
import "fast-text-encoding"

const assert = chai.assert;
describe('Binary Serializer Tests', function()  {

    const serializer: MessageDecoder = new BinaryDecoder();

    it('Should decode basic binary payload' , () => {

        const data: ArrayBuffer = binaryData();
        const event  = new MessageEvent('test', {
            data : data
        });

        const message = serializer.decode(event);

        assert.deepEqual(message, new ChannelMessage("message_id2", "event_name2", "correlation_id2", "message_data1"));
    });

    it('Should decode basic Auth Frame' , () => {

        const data: ArrayBuffer = simpleAuthOkFrame();
        const event  = new MessageEvent('test', {
            data : data
        });

        const message = serializer.decode(event);

        assert.deepEqual(message, new ChannelMessage("", "AuthOk", "", ""));
    });

    it('Should decode UTF-8 with special characters binary payload' , () => {
        const plainPayload = "{\"strange_message: \"áéíóú@ñ&%$#!especíalç\", \"strange_message: \"áéíóú@ñ&%$#!especíal2ç\"}";
        const data: ArrayBuffer = specialBinaryData();
        const event  = new MessageEvent('test', {
            data : data
        });

        const message = serializer.decode(event);

        assert.deepEqual(message, new ChannelMessage("message_id2", "event_name2", "correlation_id2", plainPayload));
    });

});

/*
  message_id: "message_id2",
  correlation_id: "correlation_id2",
  message_data: "message_data1",
  event_name: "event_name2"
*/
function binaryData() : ArrayBuffer {
    const rawData = [255, 11, 15, 11, 109, 101, 115, 115, 97, 103, 101, 95, 105, 100, 50, 99, 111,
        114, 114, 101, 108, 97, 116, 105, 111, 110, 95, 105, 100, 50, 101, 118, 101,
        110, 116, 95, 110, 97, 109, 101, 50, 109, 101, 115, 115, 97, 103, 101, 95,
        100, 97, 116, 97, 49];
    const byteArray = new Uint8Array(rawData);
    return byteArray.buffer;
}

/*
  message_id: "",
  correlation_id: "",
  message_data: "",
  event_name: "AuthOk"
*/
function simpleAuthOkFrame() {
    const rawData = [255, 0, 0, 6, 65, 117, 116, 104, 79, 107]
    const byteArray = new Uint8Array(rawData);
    return byteArray.buffer;
}

function specialBinaryData() : ArrayBuffer {
    const rawData = [255, 11, 15, 11, 109, 101, 115, 115, 97, 103, 101, 95, 105, 100, 50, 99, 111,
        114, 114, 101, 108, 97, 116, 105, 111, 110, 95, 105, 100, 50, 101, 118, 101,
        110, 116, 95, 110, 97, 109, 101, 50, 123, 34, 115, 116, 114, 97, 110, 103,
        101, 95, 109, 101, 115, 115, 97, 103, 101, 58, 32, 34, 195, 161, 195, 169,
        195, 173, 195, 179, 195, 186, 64, 195, 177, 38, 37, 36, 35, 33, 101, 115, 112,
        101, 99, 195, 173, 97, 108, 195, 167, 34, 44, 32, 34, 115, 116, 114, 97, 110,
        103, 101, 95, 109, 101, 115, 115, 97, 103, 101, 58, 32, 34, 195, 161, 195,
        169, 195, 173, 195, 179, 195, 186, 64, 195, 177, 38, 37, 36, 35, 33, 101, 115,
        112, 101, 99, 195, 173, 97, 108, 50, 195, 167, 34, 125];
    const byteArray = new Uint8Array(rawData);
    return byteArray.buffer;
}
