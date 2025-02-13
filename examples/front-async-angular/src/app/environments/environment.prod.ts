const servers = {
  main: {
    api_business: 'REPLACE',
    socket_url_async: 'REPLACE'
  }
} as { [key: string]: { api_business: string, socket_url_async: string } };

export const environment = {
  production: true,
  servers,
  heartbeat_interval: 20000,
} as any;
