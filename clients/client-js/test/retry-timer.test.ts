import * as chai from 'chai';
import sinonPkg from "sinon";

import { RetryTimer } from "../src/retry-timer.js";
const { spy } = sinonPkg;

const assert: Chai.AssertStatic = chai.assert;
describe('Exponential Retry Timer Tests', function () {

    let timer: RetryTimer;

    it('Should retry with exponential delay', async () => {
        let counter = 0;
        let lastTime = Date.now();
        const times: number[] = [];
        const maxRetries = 7;

        const retryProcess = new Promise(resolve => {
            timer = new RetryTimer(() => {
                const now = Date.now();
                times.push(now - lastTime);
                lastTime = now;
                counter = counter + 1;
                counter < maxRetries ? timer.schedule() : resolve(0);
            }, 10, x => x, maxRetries);
        });

        timer.schedule();
        await retryProcess;
        const exp = [10, 20, 40, 80, 160, 320, 640];
        times.forEach((delay, index) => assert.approximately(delay, exp[index], 10))
    });

    it('Should call maxRetriesReachenCallback', async () => {
        let counter = 0;
        let lastTime = Date.now();
        const times: number[] = [];
        const maxRetries = 3;
        const rechedCallback: sinon.SinonSpy = spy();

        const retryProcess = new Promise(resolve => {
            timer = new RetryTimer(() => {
                const now = Date.now();
                times.push(now - lastTime);
                lastTime = now;
                counter = counter + 1;
                if (counter <= maxRetries) { timer.schedule() }
                if (counter == maxRetries) { resolve(0) }
            }, 10, x => x, maxRetries, rechedCallback);
        });

        timer.schedule();
        await retryProcess;
        assert.isTrue(rechedCallback.called);
    });

});
