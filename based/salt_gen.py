#!/usr/bin/env python3

import base64
import hashlib
import os
import argparse
import sys

def generate_salt():
    return base64.b64encode(os.urandom(16)).decode('utf-8')

def hash_password(password, salt_b64):
    try:
        salt_bytes = base64.b64decode(salt_b64)
    except Exception as e:
        print(f"[ERRO] Salt inválido: {e}", file=sys.stderr)
        sys.exit(1)

    hashed = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt_bytes, 100_000)
    return base64.b64encode(hashed).decode('utf-8')

def main():
    parser = argparse.ArgumentParser(description="Gera salt e hash com PBKDF2-SHA256 em Base64.")
    parser.add_argument('--gensalt', action='store_true', help='Apenas gera um novo salt em Base64')
    parser.add_argument('--hash', type=str, help='Senha em texto claro a ser hasheada')
    parser.add_argument('--salt', type=str, help='Salt em Base64 (opcional)')

    args = parser.parse_args()

    if args.gensalt:
        print(generate_salt())
        return

    if args.hash:
        salt_b64 = args.salt if args.salt else generate_salt()
        hash_b64 = hash_password(args.hash, salt_b64)
        print(f"{salt_b64}:{hash_b64}")
        return

    parser.print_help()

if __name__ == "__main__":
    main()
