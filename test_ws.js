const WebSocket = require('ws');
const ws = new WebSocket('ws://127.0.0.1:6550');
ws.on('open', () => {
    console.log('Connected to Godot!');
    ws.close();
    process.exit(0);
});
ws.on('error', (e) => {
    console.error('Error:', e.message);
    process.exit(1);
});
setTimeout(() => {
    console.error('Timeout');
    process.exit(1);
}, 5000);
