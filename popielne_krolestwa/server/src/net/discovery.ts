/**
 * Wykrywanie serwera w sieci lokalnej (tryb „lokalny serwer”).
 * Klient wysyła broadcast UDP "PK_DISCOVER" na port 7172, serwer odpowiada
 * "PK_SERVER <port_websocket>". Dzięki temu na telefonie nie trzeba wpisywać IP.
 */
import dgram from 'node:dgram';

export function startDiscovery(udpPort: number, wsPort: number): dgram.Socket {
  const sock = dgram.createSocket({ type: 'udp4', reuseAddr: true });
  sock.on('message', (msg, rinfo) => {
    if (msg.toString().trim() !== 'PK_DISCOVER') return;
    sock.send(`PK_SERVER ${wsPort}`, rinfo.port, rinfo.address);
  });
  sock.on('error', (e) => console.warn('[discovery] wyłączone:', e.message));
  sock.bind(udpPort);
  return sock;
}
