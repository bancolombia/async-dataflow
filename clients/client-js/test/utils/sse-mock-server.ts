import * as http from 'http';

const DEFAULT_HTTP_STATUS_CODE = 200;
const UNAUTHORIZED_STATUS = 401;
function mockSSServer(port: number, onListening: (server: http.Server) => void): void {

    const server = http.createServer((req, res) => {
        function sendEvent(event: string) {
            console.log(`SSEMockServer: Sending event`, event);
            res.write(`data: ${event}\n\n`);
        }

        console.log(`SSEMockServer: ${req.method} ${req.url}`);
        const mockResponse = SSEMockServer.getMock(req.url!);
        if (mockResponse) {
            if (req.headers['authorization'] !== `Bearer ${mockResponse.token}`) {
                res.writeHead(UNAUTHORIZED_STATUS, { 'Content-Type': 'text/plain' });
                res.end('SSEMockServer: Unauthorized');
                return;
            }
            const headers = {
                'Content-Type': 'text/event-stream',
                'Cache-Control': 'no-cache',
                'Connection': 'keep-alive',
                'Transfer-Encoding': 'chunked',
            };
            if (mockResponse.headers) {
                Object.entries(mockResponse.headers).forEach(([key, value]) => {
                    headers[key] = value;
                });
            }
            const status = mockResponse.status || DEFAULT_HTTP_STATUS_CODE;
            console.log('SSEMockServer: Sending headers with status', mockResponse.status, headers);
            res.writeHead(status, headers);
            if (status !== DEFAULT_HTTP_STATUS_CODE) {
                res.end();
                return;
            }

            for (const message of mockResponse.messages) {
                if (message.afterRequest === undefined || message.afterRequest === 0) {
                    sendEvent(message.message);
                } else {
                    setTimeout(() => {
                        sendEvent(message.message);
                    }, message.afterRequest);
                }
            };

            req.on('close', () => {
                console.log('SSEMockServer: Connection closed');
                res.end();
            });
        } else {
            const NOT_FOUND_STATUS = 404;
            res.writeHead(NOT_FOUND_STATUS, { 'Content-Type': 'text/plain' });
            res.end('SSEMockServer: Resource not found');
        }
    });

    server.listen(port, '127.0.0.1', async () => {
        console.log(`SSEMockServer: is running at http://localhost:${port}`);
        onListening(server);
    });
}

interface SSEMock {
    url: string;
    response: SSEResponse;
}

interface SSEResponse {
    token: string;
    status?: number;
    headers?: {
        [key: string]: string;
    }
    messages: SSEMessage[];
}

interface SSEMessage {
    afterRequest?: number;
    message: string;
}

export class SSEMockServer {
    private static mocks: Map<string, SSEResponse> = new Map<string, SSEResponse>();;

    private static server: http.Server;

    public static mock(mock: SSEMock) {
        this.mocks.set(mock.url, mock.response);
    }

    public static getMock(url: string): SSEResponse | undefined {
        return this.mocks.get(url);
    }

    public static start(port: number = 3000): Promise<http.Server> {
        if (this.server) {
            throw new Error('SSEMockServer: Server already started');
        }
        return new Promise((resolve) => {
            mockSSServer(port, (server) => {
                this.server = server;
                resolve(server);
            });
        });
    }

    public static stop(callback: () => void) {
        console.log('SSEMockServer: Stopping server');
        // this.server.emit('close');
        this.server.closeAllConnections();
        this.server.close((err) => {
            if (err) {
                console.error('SSEMockServer: Error stopping server', err);
            } else {
                console.log('SSEMockServer: Server stopped');
            }
            callback();
        });
    }
}