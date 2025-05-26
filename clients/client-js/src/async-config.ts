export interface AsyncConfig {
    socket_url: string;
    sse_url?: string;
    channel_ref: string;
    channel_secret: string;
    enable_binary_transport?: boolean;
    heartbeat_interval?: number;
    dedupCacheDisable?: boolean;
    dedupCacheMaxSize?: number;
    dedupCacheTtl?: number;
    maxReconnectAttempts?: number;
    checkConnectionOnFocus?: boolean;
}