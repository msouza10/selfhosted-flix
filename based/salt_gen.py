#!/usr/bin/env python3
import os, sys, argparse, base64, hashlib, hmac

_ITERATIONS = 100_000
_HASH_NAME   = 'sha512'
_SALT_SIZE   = 16
_DKLEN       = 64

def generate_salt() -> str:
    return base64.b64encode(os.urandom(_SALT_SIZE)).decode('ascii')

def hash_password(password: str, salt_b64: str) -> str:
    try:
        salt = base64.b64decode(salt_b64)
    except Exception as e:
        print(f"[ERRO] Salt inválido: {e}", file=sys.stderr)
        sys.exit(1)
    key = hashlib.pbkdf2_hmac(
        _HASH_NAME,
        password.encode('utf-8'),
        salt,
        _ITERATIONS,
        dklen=_DKLEN
    )
    return base64.b64encode(key).decode('ascii')

def verify(secret: str, password: str) -> bool:
    try:
        salt_b64, key_b64 = secret.split(':', 1)
    except ValueError:
        return False
    new_key_b64 = hash_password(password, salt_b64)
    return hmac.compare_digest(key_b64, new_key_b64)

def main():
    parser = argparse.ArgumentParser(
        description="Gera/verifica hash PBKDF2-SHA512 — form 'salt:hash' em Base64"
    )
    parser.add_argument('--gensalt', action='store_true',
                        help='Só gera um salt em Base64')
    parser.add_argument('--hash', type=str,
                        help='Senha em texto claro para gerar salt:hash')
    parser.add_argument('--verify', type=str,
                        help="Verifica senha contra 'salt:hash'")
    parser.add_argument('--salt', type=str,
                        help='Salt em Base64 (opcional)')
    args = parser.parse_args()

    if args.gensalt:
        print(generate_salt())
        return

    if args.hash:
        salt = args.salt or generate_salt()
        hashed = hash_password(args.hash, salt)
        print(f"{salt}:{hashed}")
        return

    if args.verify:
        secret, password = args.verify.split(',',1)
        ok = verify(secret, password)
        print("OK" if ok else "FAIL")
        return

    parser.print_help()

if __name__ == "__main__":
    main()
