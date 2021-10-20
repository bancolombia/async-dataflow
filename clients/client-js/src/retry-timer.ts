import {Utils} from "./utils";

export class RetryTimer {

    private timer : number;
    private tries: number = 0;

    constructor(
        private callback: Function,
        private initial: number = 10,
        private jitterFn : Function = num => Utils.jitter(num, 0.25)) {
    }

    public reset() : void {
        clearTimeout(this.timer)
        this.tries = 0;
    }

    public schedule() : void {
        this.timer = setTimeout(() => {
            this.tries = this.tries + 1;
            this.callback();
        }, this.delay())
    }

    private delay() : number {
        return Utils.expBackoff(this.initial, 6000, this.tries, this.jitterFn);
    }
}
