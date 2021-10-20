export class ChannelMessage {
    constructor(
        public message_id: string,
        public event: string,
        public correlation_id: string,
        public payload: string) {}
}
