const servers = {
  local: {
    api_business: 'http://localhost:8080/api',
    socket_url_async: 'ws://localhost:8082'
  }
} as { [key: string]: { api_business: string, socket_url_async: string } };

export const environment = {
  production: false,
  servers,
  heartbeat_interval: 2000,
} as any;
