import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/export.dart';
import 'package:crypto/crypto.dart' as crypto_hash;
import 'package:pointycastle/pointycastle.dart';

class CryptographyService {
  final _storage = FlutterSecureStorage();
  // convert the RSA key to PEM format because my djando server is expecting rsa private key in that format
  String encodeRSAPublicKeyToPem(RSAPublicKey publicKey) {
    // sequence manner data store
    final topLevel = ASN1Sequence();

    topLevel.add(ASN1Integer(publicKey.n));
    topLevel.add(ASN1Integer(publicKey.publicExponent ?? publicKey.exponent));
    // encode the sequence to the raw bytes
    final dataBase64 = base64.encode(topLevel.encode());
    final chunks = <String>[];
    //PEM requires lines to be wrapped at 64 characters so formatting
    for (var i = 0; i < dataBase64.length; i += 64) {
      chunks.add(dataBase64.substring(
          i, i + 64 > dataBase64.length ? dataBase64.length : i + 64));
    }
    return "-----BEGIN PUBLIC KEY-----\n${chunks.join('\n')}\n-----END PUBLIC KEY-----";
  }

  // Helper to save the private key securely
  Future<void> savePrivateKeys({
    required RSAPrivateKey rsaPriv,
    required List<int> ed25591priv,
  }) async {
    final primeP = rsaPriv.p;
    final primeQ = rsaPriv.q;
    if (primeP == null || primeQ == null) {
      throw Exception("RSA private key is missing prime factors.");
    }

    // convert RSA private keys to string
    // we use two different keys to save the private key because RSA is not just one mathematical structure
    //the modulus n explains about the size of the key
    // modulus means the lock
    await _storage.write(key: 'rsa_modulus', value: rsaPriv.n.toString());
    // this is the secret part that would actually do the work.
    // actual key
    await _storage.write(key: 'rsa_exponent', value: (rsaPriv.privateExponent ?? rsaPriv.exponent).toString());
    await _storage.write(key: 'rsa_prime_p', value: primeP.toString());
    await _storage.write(key: 'rsa_prime_q', value: primeQ.toString());
    // convert ed25519 private key to base64 because If you try to save "Raw Bytes" as a normal String (like UTF-8), it will corrupt your key. This is because some byte values (like 0x00) mean "End of File" in text, or they represent characters that your phone's screen can't display.
    // Base64 is a translator. It takes those 32 dangerous "Binary Bytes" and turns them into a safe string of 44 characters (using only A-Z, a-z, 0-9, and + /).
    await _storage.write(key: 'ed25519_priv', value: base64Encode(ed25591priv));
  }

  /// Save the public keys so they can be re-uploaded to the server
  /// without needing to regenerate or re-derive them.
  Future<void> savePublicKeys({
    required String rsaPublicKeyPem,
    required String ed25519PublicKeyBase64,
  }) async {
    await _storage.write(key: 'rsa_public_pem', value: rsaPublicKeyPem);
    await _storage.write(key: 'ed25519_pub', value: ed25519PublicKeyBase64);
  }

  /// Load the stored RSA public key PEM string.
  Future<String?> loadRSAPublicKeyPem() async {
    return await _storage.read(key: 'rsa_public_pem');
  }

  /// Load the stored Ed25519 public key (base64-encoded).
  Future<String?> loadEd25519PublicKeyBase64() async {
    return await _storage.read(key: 'ed25519_pub');
  }

  Future<RSAPrivateKey?> loadRSAPrivateKey() async {
    final modulus = await _storage.read(key: 'rsa_modulus');
    final exponent = await _storage.read(key: 'rsa_exponent');
    final primeP = await _storage.read(key: 'rsa_prime_p');
    final primeQ = await _storage.read(key: 'rsa_prime_q');

    if (modulus == null ||
        exponent == null ||
        primeP == null ||
        primeQ == null) {
      return null;
    }

    return RSAPrivateKey(
      BigInt.parse(modulus),
      BigInt.parse(exponent),
      BigInt.parse(primeP),
      BigInt.parse(primeQ),
    );
  }

  // Encrypts the raw bytes using AES-256-GCM
  Future<Map<String, Uint8List>> encryptAesGcm(
      Uint8List plaintext, Uint8List key) async {
    final algorithm = crypto.AesGcm.with256bits();
    final secretKey = crypto.SecretKey(key);
    final nonce = algorithm.newNonce();
    final secretBox =
        await algorithm.encrypt(plaintext, secretKey: secretKey, nonce: nonce);
    return {
      'ciphertext': Uint8List.fromList(secretBox.cipherText),
      'nonce': Uint8List.fromList(secretBox.nonce),
      'tag': Uint8List.fromList(secretBox.mac.bytes)
    };
  }

  // Decrypts the AES-256-GCM
  Future<Uint8List> decryptAesGcm(
      {required Uint8List ciphertext,
      required Uint8List key,
      required Uint8List nonce,
      required Uint8List tag}) async {
    final algorithm = crypto.AesGcm.with256bits();
    final secretKey = crypto.SecretKey(key);
    final mac = crypto.Mac(tag);
    final secretBox = crypto.SecretBox(mac: mac, nonce: nonce, ciphertext);
    final cleartext = await algorithm.decrypt(secretBox, secretKey: secretKey);
    return Uint8List.fromList(cleartext);
  }

  // ═══════════════════════════════════════════════════════════════
  //  STREAMING: Per-chunk AES-GCM encrypt / decrypt
  // ═══════════════════════════════════════════════════════════════

  /// Encrypts a single chunk with AES-256-GCM.
  /// Each chunk gets its own nonce (derived from base nonce + chunk index)
  /// and produces its own 16-byte GCM authentication tag.
  /// This means tamper detection happens per-chunk — fail fast.
  Future<Map<String, Uint8List>> encryptChunkAesGcm(
      Uint8List plaintext, Uint8List key, Uint8List nonce) async {
    final algorithm = crypto.AesGcm.with256bits();
    final secretKey = crypto.SecretKey(key);
    final secretBox = await algorithm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );
    return {
      'ciphertext': Uint8List.fromList(secretBox.cipherText),
      'tag': Uint8List.fromList(secretBox.mac.bytes),
    };
  }

  /// Decrypts a single chunk with AES-256-GCM.
  /// If the GCM tag doesn't match, the chunk was tampered with.
  Future<Uint8List> decryptChunkAesGcm({
    required Uint8List ciphertext,
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List tag,
  }) async {
    final algorithm = crypto.AesGcm.with256bits();
    final secretKey = crypto.SecretKey(key);
    final mac = crypto.Mac(tag);
    final secretBox = crypto.SecretBox(mac: mac, nonce: nonce, ciphertext);
    final cleartext = await algorithm.decrypt(secretBox, secretKey: secretKey);
    return Uint8List.fromList(cleartext);
  }

  /// Derives a unique 12-byte nonce for each chunk by XOR-ing the
  /// last 4 bytes of the base nonce with the chunk index.
  /// This guarantees nonce uniqueness per chunk (critical for GCM security)
  /// and supports up to 2^32 chunks (~64TB with 16KB chunks).
  Uint8List deriveChunkNonce(Uint8List baseNonce, int chunkIndex) {
    final nonce = Uint8List.fromList(baseNonce); // copy to avoid mutation
    final indexBytes = ByteData(4)..setUint32(0, chunkIndex, Endian.big);
    // XOR the last 4 bytes of the 12-byte nonce with the chunk index
    for (int i = 0; i < 4; i++) {
      nonce[8 + i] ^= indexBytes.getUint8(i);
    }
    return nonce;
  }

  /// Generates a random 12-byte nonce for AES-GCM.
  /// Used as the "base nonce" for streaming encryption — each chunk
  /// derives its own nonce from this via deriveChunkNonce().
  Uint8List generateBaseNonce() {
    final secureRandom = FortunaRandom();
    final seedSource = Random.secure();
    final seeds = List<int>.generate(32, (_) => seedSource.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));

    final nonce = Uint8List(12);
    for (int i = 0; i < 12; i++) {
      nonce[i] = secureRandom.nextUint8();
    }
    return nonce;
  }

  // ═══════════════════════════════════════════════════════════════
  //  STREAMING: File hashing without loading into RAM
  // ═══════════════════════════════════════════════════════════════

  /// Computes SHA256 of a file by streaming it from disk.
  /// Memory usage: ~64KB regardless of file size (vs loading entire file).
  /// Returns the hex-encoded hash string (same format as sha256.convert().toString()).
  Future<String> computeFileHashStreaming(File file) async {
    final sink = _DigestSink();
    final hasher = crypto_hash.sha256.startChunkedConversion(sink);

    // openRead() streams the file in ~64KB chunks from disk
    await for (final chunk in file.openRead()) {
      hasher.add(chunk);
    }
    hasher.close();

    return sink.digest!.toString();
  }

  /// Computes SHA256 of a temp file (already decrypted on disk).
  /// Used by the receiver to verify the sender's signature without
  /// loading the entire decrypted file into RAM.
  Future<String> computeTempFileHashStreaming(String filePath) async {
    return computeFileHashStreaming(File(filePath));
  }

  /// Builds the transfer payload from a pre-computed file hash string.
  /// Used in the streaming flow where the file hash is computed via
  /// streaming (never loading the whole file into RAM).
  Uint8List buildTransferPayloadFromHash({
    required String fileHashHex,
    required String senderId,
    required String timestamp,
  }) {
    final rawString = "$fileHashHex:$senderId:$timestamp";
    final payload = crypto_hash.sha256.convert(utf8.encode(rawString)).bytes;
    return Uint8List.fromList(payload);
  }

  // now we have to deliver the key from one user to another securely so for that we would use RSA-OAEP algorithm normal RSA algorithm would give the same output on the same data which can be predictable so to add some level of randomness we use RSA-OAEP OAEP add randomness.
  // so i am encrypting the aes key with the public key
  Uint8List wrapWithRsa(Uint8List aesKey, RSAPublicKey publicKey) {
    final cipher = OAEPEncoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
    return cipher.process(aesKey);
  }

  Uint8List unwrapKeyWithRsa(Uint8List encryptedKey, RSAPrivateKey privateKey) {
    final cipher = OAEPEncoding(RSAEngine())
      ..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    return cipher.process(encryptedKey);
  }

//Build the unique payload for signing like who send it, when send it and finally what they send it.
  Uint8List buildTransferPayload(
      {required Uint8List fileBytes,
      required String senderId,
      required String timestamp}) {
    // Hashing the file itself
    final fileHash = crypto_hash.sha256.convert(fileBytes).toString();
    // combine with sender and time stamp to prevent replay attack
    final rawString = "$fileHash:$senderId:$timestamp";
    // return the final hash as bytes
    final payload = crypto_hash.sha256.convert(utf8.encode(rawString)).bytes;
    return Uint8List.fromList(payload);
  }

// sign the payload using the Ed25519 algorithm so that they would know that i signed it.
  Future<Uint8List> signPayLoad(
      Uint8List payload, Uint8List ed25519PrivBytes) async {
    final algorithm = crypto.Ed25519();
    // construct the new key pair from the stored private bytes
    final keyPair = await algorithm.newKeyPairFromSeed(ed25519PrivBytes);
    final signature = await algorithm.sign(payload, keyPair: keyPair);
    return Uint8List.fromList(signature.bytes);
  }

// Verifies a signature using the senders public key to really know who send it.
  Future<bool> verifySignature(
      {required Uint8List payload,
      required Uint8List signature,
      required Uint8List publicKeyBytes}) async {
    final algorithm = crypto.Ed25519();
    final signatureObj = crypto.Signature(signature,
        publicKey: crypto.SimplePublicKey(publicKeyBytes,
            type: crypto.KeyPairType.ed25519));
    return await algorithm.verify(payload, signature: signatureObj);
  }

  Future<Uint8List?> loadEd25519PrivKey() async {
    final encoded = await _storage.read(key: 'ed25519_priv');
    if (encoded == null) return null;
    return base64Decode(encoded);
  }

  // Generate a cryptographically secure random 32-byte AES-256 key.
  // Each file transfer needs a unique key — reusing keys lets an attacker
  // who cracks one file crack all of them.
  // FortunaRandom seeded with Random.secure() is the same pattern used
  // in KeyGeneration.dart for RSA key generation.
  Uint8List generateAesKey() {
    // Fortuna Random needs seeds to produce random value.
    final secureRandom = FortunaRandom();
    final seedSource = Random.secure();
    final seeds = List<int>.generate(32, (_) => seedSource.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));

    final key = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      key[i] = secureRandom.nextUint8();
    }
    return key;
  }
}

/// Helper sink that captures a single digest value from the chunked
/// SHA256 conversion. Avoids needing an external dependency for AccumulatorSink.
class _DigestSink implements Sink<crypto_hash.Digest> {
  crypto_hash.Digest? digest;

  @override
  void add(crypto_hash.Digest data) => digest = data;

  @override
  void close() {}
}

