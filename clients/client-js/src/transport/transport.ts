export interface Transport {
    connect(): void;
    disconnect(): void;
    name(): string;
    connected(): boolean;
}
