/**
 * Konfiguracja serwera. Wszystkie wartości można nadpisać zmiennymi środowiskowymi
 * (np. w docker-compose.yml).
 */
export const config = {
  /** Port WebSocket, na którym nasłuchuje serwer. */
  port: Number(process.env.PORT ?? 7171),
  /** Port UDP do wykrywania serwera w sieci LAN (0 = wyłączone). */
  discoveryPort: Number(process.env.DISCOVERY_PORT ?? 7172),
  /** Adres nasłuchu – 0.0.0.0 pozwala łączyć się telefonom z sieci LAN. */
  host: process.env.HOST ?? '0.0.0.0',
  /** Ścieżka do pliku bazy SQLite. */
  dbPath: process.env.DB_PATH ?? './data/game.db',
  /** Długość ticka symulacji w ms (10 ticków/s). */
  tickMs: 100,
  /** Co ile ms zapisywać wszystkie postacie online. */
  autosaveMs: 60_000,
  /** Maksymalna liczba wiadomości od klienta na sekundę (ochrona przed floodem). */
  maxMessagesPerSecond: 40,
  /** Promień widoczności (w kafelkach) – ile świata widzi klient. */
  viewRadiusX: 13,
  viewRadiusY: 9,
  /** Wersja protokołu – klient i serwer muszą się zgadzać. */
  protocolVersion: 2,
};
