import * as chai from 'chai';

import {RetryTimer} from "../src/retry-timer";


const assert = chai.assert;
describe('Exponential Retry Timer Tests', function()  {

    let timer: RetryTimer;
    
    it('Should retry with exponential delay' ,async () => {
        let counter = 0;
        let lastTime = Date.now();
        let times: number[] = [];
        const maxRetries = 7;

        let retryProcess = new Promise(resolve => {
            timer = new RetryTimer(() => {
                let now = Date.now();
                times.push(now - lastTime);
                lastTime = now;
                counter = counter + 1;
                counter < maxRetries ? timer.schedule() : resolve(0);
            }, 10, x => x, maxRetries);
        });

        timer.schedule();
        const result = await retryProcess;
        const exp = [ 10, 20, 40, 80, 160, 320, 640 ];
        times.forEach((delay, index) => assert.approximately(delay, exp[index], 10))

    });



});
