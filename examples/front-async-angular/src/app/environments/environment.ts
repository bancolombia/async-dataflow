const servers = {
  local: {
    api_business: 'http://localhost:8080/api',
    socket_url_async: 'ws://localhost:82',
    sse_url_async: 'http://localhost:82'
  }
} as { [key: string]: { api_business: string, socket_url_async: string, sse_url_async: string } };

export const environment = {
  production: false,
  servers,
  heartbeat_interval: 2000,
} as any;
