const WebSocket = require('ws');

console.log('Connecting to ws://127.0.0.1:6550...');

const ws = new WebSocket('ws://127.0.0.1:6550');

ws.on('open', () => {
    console.log('WebSocket OPEN - sending handshake...');
    const handshake = {
        id: '1',
        command: 'mcp_handshake',
        params: {
            server_version: '4.1.0'
        }
    };
    ws.send(JSON.stringify(handshake));
});

ws.on('message', (data) => {
    console.log('Received:', data.toString());
});

ws.on('close', (code, reason) => {
    console.log('WebSocket CLOSED:', code, reason.toString());
    process.exit(0);
});

ws.on('error', (error) => {
    console.error('WebSocket ERROR:', error.message);
    process.exit(1);
});

setTimeout(() => {
    console.log('Timeout - exiting');
    ws.close();
    process.exit(0);
}, 10000);
