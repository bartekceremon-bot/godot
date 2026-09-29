/**
 * Punkt wejścia serwera Popielnych Królestw.
 */
import os from 'node:os';
import { config } from './config';
import { Database } from './db/database';
import { World } from './game/world';
import { GameServer } from './net/server';
import { startDiscovery } from './net/discovery';

async function main() {
  const db = new Database(config.dbPath);
  const world = new World(db);
  const server = new GameServer(world);
  const port = await server.listen();
  world.start();
  const discovery = config.discoveryPort ? startDiscovery(config.discoveryPort, port) : null;

  console.log('==============================================');
  console.log(' POPIELNE KRÓLESTWA – serwer uruchomiony');
  console.log(`  port: ${port}, baza: ${config.dbPath}`);
  console.log(`  potwory: ${world.monsters.size}, mapa: ${world.map.width}x${world.map.height}`);
  console.log(' Adresy do wpisania w kliencie (ta sama sieć Wi-Fi):');
  for (const addrs of Object.values(os.networkInterfaces()))
    for (const a of addrs ?? []) if (a.family === 'IPv4' && !a.internal) console.log(`   ws://${a.address}:${port}`);
  console.log('==============================================');

  let stopping = false;
  const shutdown = async (sig: string) => {
    if (stopping) return;
    stopping = true;
    console.log(`[${sig}] zapisuję postacie i zamykam serwer...`);
    discovery?.close();
    await server.close();
    world.stop();
    db.close();
    process.exit(0);
  };
  process.on('SIGINT', () => void shutdown('SIGINT'));
  process.on('SIGTERM', () => void shutdown('SIGTERM'));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
