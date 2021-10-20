export class EventPrototype {
    public stopPropagation() {}
    public stopImmediatePropagation() {}

    public type: string;
    public bubbles: boolean;
    public cancelable: boolean;
    // if no arguments are passed then the type is set to "undefined" on
    // chrome and safari.
    public initEvent(type = 'undefined', bubbles = false, cancelable = false) {
        this.type = `${type}`;
        this.bubbles = Boolean(bubbles);
        this.cancelable = Boolean(cancelable);
    }
}

export class MessageEvent extends EventPrototype {

    public timeStamp: number;
    public target = null;
    public AT_TARGET = null;
    public BUBBLING_PHASE = null;
    public CAPTURING_PHASE = null;
    public NONE = null;
    public srcElement = null;
    public returnValue: boolean;
    public isTrusted: boolean;
    public eventPhase: number;
    public defaultPrevented: boolean;
    public cancelBubble: boolean;
    public composed: boolean;
    public preventDefault: any;
    public origin: string;
    public composedPath: any;
    public lastEventId: string;
    public currentTarget = null;
    public ports = null;
    public data: any;
    public source: any;

    constructor(type: string, eventInitConfig: any = {}) {
        super();
        const { bubbles, cancelable, data, origin, lastEventId, ports } = eventInitConfig;
        this.type = `${type}`;
        this.timeStamp = Date.now();
        this.returnValue = true;
        this.isTrusted = false;
        this.eventPhase = 0;
        this.defaultPrevented = false;
        this.cancelable = cancelable ? Boolean(cancelable) : false;
        this.cancelBubble = false;
        this.bubbles = bubbles ? Boolean(bubbles) : false;
        this.origin = `${origin}`;
        this.ports = typeof ports === 'undefined' ? null : ports;
        this.data = typeof data === 'undefined' ? null : data;
        this.lastEventId = `${lastEventId || ''}`;
    }
}
