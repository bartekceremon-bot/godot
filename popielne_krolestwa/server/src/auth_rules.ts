/**
 * Walidacja nazw i haseł (bez zależności od Node – używana też w trybie offline).
 */

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
