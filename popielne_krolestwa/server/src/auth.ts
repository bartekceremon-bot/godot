/**
 * Hashowanie haseł (scrypt z losową solą) i walidacja danych logowania.
 */
import crypto from 'node:crypto';

const KEY_LEN = 32;

export function hashPassword(password: string): string {
  const salt = crypto.randomBytes(16);
  const hash = crypto.scryptSync(password, salt, KEY_LEN);
  return `scrypt$${salt.toString('hex')}$${hash.toString('hex')}`;
}

export function verifyPassword(password: string, stored: string): boolean {
  const [algo, saltHex, hashHex] = stored.split('$');
  if (algo !== 'scrypt' || !saltHex || !hashHex) return false;
  const expected = Buffer.from(hashHex, 'hex');
  const actual = crypto.scryptSync(password, Buffer.from(saltHex, 'hex'), expected.length);
  return crypto.timingSafeEqual(expected, actual);
}

/** Nazwa: 3–16 znaków, litery (także polskie), cyfry, spacja w środku. */
const NAME_RE = /^[A-Za-zĄĆĘŁŃÓŚŹŻąćęłńóśźż][A-Za-zĄĆĘŁŃÓŚŹŻąćęłńóśźż0-9 ]{1,14}[A-Za-zĄĆĘŁŃÓŚŹŻąćęłńóśźż0-9]$/;

export function validateName(name: unknown): string | null {
  if (typeof name !== 'string') return 'Nieprawidłowa nazwa.';
  if (!NAME_RE.test(name) || name.includes('  ')) return 'Nazwa: 3–16 znaków, litery, cyfry i pojedyncze spacje.';
  return null;
}

export function validatePassword(pass: unknown): string | null {
  if (typeof pass !== 'string' || pass.length < 4 || pass.length > 64) return 'Hasło musi mieć 4–64 znaki.';
  return null;
}
