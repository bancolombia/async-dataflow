import { Utils } from "./utils";

const MAX_DELAY = 6000;
export class RetryTimer {

    private timer: number;
    private tries: number = 0;
    private limitReachedNotified: boolean = false;

    constructor(
        private callback: () => void,
        private initial: number = 10,
        private jitterFn: (x: number) => number,
        private maxRetries: number = 10,
        private limitReachedCallback: () => void = () => { }) {
    }

    public reset(): void {
        clearTimeout(this.timer)
        this.tries = 0;
        this.limitReachedNotified = false;
    }

    public schedule(): void {
        if (typeof window !== 'undefined') {
            if (this.tries < this.maxRetries) {
                const delayMS = this.delay();
                this.tries = this.tries + 1;
                console.log(`async-client. scheduling retry in ${delayMS} ms`);
                this.timer = window.setTimeout(() => {
                    console.log(`async-client. retrying ${this.tries} of ${this.maxRetries}`);
                    this.callback();
                }, delayMS)
            } else {
                if (this.limitReachedCallback && !this.limitReachedNotified) {
                    this.limitReachedNotified = true;
                    console.log(`async-client. notifying limit reached.`);
                    this.limitReachedCallback();
                }
                console.log(`async-client. max retries reached.`);
            }
        } else {
            console.warn(`async-client. could not setup scheduler for rety: window is undefined.`);
        }
    }

    private delay(): number {
        if (this.jitterFn === undefined) {
            return Utils.expBackoff(this.initial, MAX_DELAY, this.tries, (num) => Utils.jitter(num, 0.25));
        } else {
            return Utils.expBackoff(this.initial, MAX_DELAY, this.tries, this.jitterFn);
        }
    }

}
