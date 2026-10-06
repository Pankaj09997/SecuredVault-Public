import os
import hashlib
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.backends import default_backend

CHUNK_SIZE = 16 * 1024


def encrypt_chunk(chunk: bytes, key: bytes) -> tuple[bytes, bytes, bytes]:
    nonce = os.urandom(12)

    cipher = Cipher(
        algorithms.AES(key),
        modes.GCM(nonce),
        backend=default_backend()
    )

    encryptor = cipher.encryptor()
    ciphertext = encryptor.update(chunk) + encryptor.finalize()

    return ciphertext, nonce, encryptor.tag


def decrypt_chunk(ciphertext: bytes, nonce: bytes, tag: bytes, key: bytes) -> bytes:
    cipher = Cipher(
        algorithms.AES(key),
        modes.GCM(nonce, tag),
        backend=default_backend()
    )

    decryptor = cipher.decryptor()
    plaintext = decryptor.update(ciphertext) + decryptor.finalize()

    return plaintext


def generate_chunk_hash(chunk: bytes) -> str:
    return hashlib.sha256(chunk).hexdigest()


def validate_chunk(chunk: bytes, chunk_hash: str) -> bool:
    return generate_chunk_hash(chunk) == chunk_hash


def split_file(file_path: str, chunk_size=CHUNK_SIZE):
    chunks = []
    with open(file_path, 'rb') as f:
        while True:
            chunk = f.read(chunk_size)
            if not chunk:
                break
            chunks.append(chunk)
    return chunks
