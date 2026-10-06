import 'dart:typed_data';
import 'dart:isolate';

import 'package:cryptography/cryptography.dart';
import 'package:pointycastle/export.dart';
import 'package:pointycastle/pointycastle.dart';
import 'package:pointycastle/random/fortuna_random.dart';
import 'dart:math';

Future<AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>> generateRSAKeyPair(
    {int bitStrength = 4096}) async {
  return await Isolate.run(() => _generateRSA(bitStrength));
}

AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> _generateRSA(int bitStrength) {
  // initialize secure random generator this fortunaRandom uses the seedSource bytes to create the randomness
  final secureRandom = FortunaRandom();
// this actually creates the randomness if not secure then it could be predictable and could be used by others
  final seedSource = Random.secure();
  // this picks up the random 255 bytes which seedSource have generated
  final seeds = List<int>.generate(32, (_) => seedSource.nextInt(256));
  // it initializes fortunarandom
  secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));

  // set up the key generator 65537 is an public exponent 64 is the prime number testing higher the value more would be randomness but slower would be the process.
  final keyGen = RSAKeyGenerator()
    ..init(ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.parse('65537'), bitStrength, 64),
        secureRandom));

  final pair = keyGen.generateKeyPair();
  final myPublic = pair.publicKey as RSAPublicKey;
  final myPrivate = pair.privateKey as RSAPrivateKey;

  return AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(myPublic, myPrivate);
}

// Ed25519 generation

Future<SimpleKeyPair> generateEd25519KeyPair() async {
  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPair();
  return keyPair;
}
