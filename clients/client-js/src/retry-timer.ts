import { Utils } from "./utils";

export class RetryTimer {

    private timer: number;
    private tries: number = 0;

    constructor(
        private callback: () => void,
        private initial: number = 10,
        private jitterFn: (x: number) => number,
        private maxRetries: number = 10) {
    }

    public reset(): void {
        clearTimeout(this.timer)
        this.tries = 0;
    }

    public schedule(): void {
        if (typeof window !== 'undefined') {
            const delayMS = this.delay();
            console.log(`async-client. scheduling retry in ${delayMS} ms`);
            this.timer = window.setTimeout(() => {
                this.tries = this.tries + 1;
                if (this.tries <= this.maxRetries) {
                    console.log(`async-client. retrying ${this.tries} of ${this.maxRetries}`);
                    this.callback();
                }
            }, delayMS)
        } else {
            console.warn(`async-client. could not setup scheduler for rety: window is undefined.`);
        }
    }

    private delay(): number {
        if (this.jitterFn === undefined) {
            return Utils.expBackoff(this.initial, 6000, this.tries, (num) => Utils.jitter(num, 0.25));
        } else {
            return Utils.expBackoff(this.initial, 6000, this.tries, this.jitterFn);
        }
    }

}
