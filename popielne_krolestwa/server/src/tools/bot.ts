/**
 * Prosty bot testowy: loguje N postaci, które spacerują i piszą na czacie.
 * Przydaje się do sprawdzenia widoczności innych graczy i obciążenia serwera.
 *
 * Użycie: npm run bot -- ws://127.0.0.1:7171 3
 */
import WebSocket from 'ws';

const url = process.argv[2] ?? 'ws://127.0.0.1:7171';
const count = Number(process.argv[3] ?? 1);

function runBot(n: number) {
  const ws = new WebSocket(url);
  const name = `Bot${n}`;
  ws.on('open', () => {
    // Najpierw próba rejestracji; jeśli konto istnieje – logowanie.
    ws.send(JSON.stringify({ t: 'register', v: 1, name, pass: 'botbot' }));
  });
  ws.on('message', (data) => {
    const m = JSON.parse(data.toString());
    if (m.t === 'auth_error') ws.send(JSON.stringify({ t: 'login', v: 1, name, pass: 'botbot' }));
    if (m.t === 'welcome') {
      console.log(`${name} zalogowany`);
      setInterval(() => ws.send(JSON.stringify({ t: 'move', d: Math.floor(Math.random() * 4) })), 400);
      setInterval(() => ws.send(JSON.stringify({ t: 'say', text: `Pozdrowienia od ${name}!` })), 15000);
    }
  });
  ws.on('close', () => console.log(`${name} rozłączony`));
}

for (let i = 1; i <= count; i++) runBot(i);
