import * as chai from 'chai';

import { Utils } from "../src/utils.js";

const assert = chai.assert;
describe('Utils Tests', function () {

    it('Should generate random jitter', () => {
        for (let i = 0; i < 100; i++) {
            const result = Utils.jitter(1000, 0.25)
            assert.isAbove(result, 749);
            assert.isBelow(result, 1000);
        }
    });

    it('Should generate Exp Backoff no Jitter', () => {
        const expected = [
            [0, 10],
            [1, 20],
            [2, 40],
            [3, 80],
            [4, 160],
            [5, 320],
            [6, 640],
            [7, 1280],
            [8, 2560],
            [9, 5120],
            [10, 6000],
            [11, 6000],
        ];

        const results = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11].map(x => [x, Utils.expBackoff(10, 6000, x, (x) => x)]);
        assert.deepEqual(expected, results);
    });

    it('Should generate Exp Backoff with Jitter', () => {
        const expected = [
            [0, 10],
            [1, 20],
            [2, 40],
            [3, 80],
            [4, 160],
            [5, 320],
            [6, 640],
            [7, 1280],
            [8, 2560],
            [9, 5120],
            [10, 6000],
            [11, 6000],
        ];

        const jitterFactor = 0.25;
        const jitterFn = num => Utils.jitter(num, jitterFactor);

        expected.forEach(x => {
            const result = Utils.expBackoff(10, 6000, x[0], jitterFn);
            assert.isAbove(result, (x[1] * (1 - jitterFactor)) - 1);
            assert.isBelow(result, x[1]);
        });
    });

    it('Should extract reason number', () => {
        assert.equal(Utils.extractReason('123'), 123);
        assert.equal(Utils.extractReason('abc'), 0);
    });

});
