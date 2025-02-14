export interface Settings {
    heartbeatDelay: number;
    maxRetries: number;
    defaultRequestDelay: number;
    transports: Array<string>;
    server: string;
}