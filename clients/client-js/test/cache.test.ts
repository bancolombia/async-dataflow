import * as chai from 'chai';

import { Cache } from "../src/cache";

const assert: Chai.AssertStatic = chai.assert;
describe('Cache Tests', function () {

    it('Should save at most item count', () => {
        const cache = new Cache(3);
        cache.save('a', 1);
        cache.save('b', 2);
        cache.save('c', 3);
        cache.save('d', 4);
        assert.isUndefined(cache.get('a'));
        assert.equal(cache.get('b'), 2);
        assert.equal(cache.get('c'), 3);
        assert.equal(cache.get('d'), 4);
    });

});
