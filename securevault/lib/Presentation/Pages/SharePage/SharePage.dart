// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';

// class RoomScreen extends StatelessWidget {
//   final String roomId;
  
//   RoomScreen({required this.roomId});

//   @override
//   Widget build(BuildContext context) {
//     return BlocProvider(
//       create: (context) => RoomBloc(
//         webSocketService: WebSocketService('ws://your-server/ws/signaling/$roomId/'),
//         apiService: ApiService(
//           baseUrl: 'https://securevault-h1nz.onrender.com',
//           prefs: context.read<SharedPreferences>(),
//         ),
//       )..add(ConnectToRoom(roomId)),
//       child: _RoomView(),
//     );
//   }
// }

// class _RoomView extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Room')),
//       body: BlocBuilder<RoomBloc, RoomState>(
//         builder: (context, state) {
//           if (state is RoomInitial) {
//             return Center(child: CircularProgressIndicator());
//           }
          
//           return Column(
//             children: [
//               // Display peers
//               Expanded(child: _buildPeerList(context)),
              
//               // File transfer section
//               _buildFileTransferSection(context),
//             ],
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildPeerList(BuildContext context) {
//     // Implement peer listing UI
//     return ListView.builder(
//       itemCount: 0, // Replace with actual peer count
//       itemBuilder: (context, index) => ListTile(
//         title: Text('Peer ${index + 1}'),
//       ),
//     );
//   }

//   Widget _buildFileTransferSection(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.all(16.0),
//       child: Column(
//         children: [
//           ElevatedButton(
//             onPressed: () => _startFileTransfer(context),
//             child: Text('Send File'),
//           ),
//           BlocBuilder<RoomBloc, RoomState>(
//             builder: (context, state) {
//               if (state is FileTransferInitiated) {
//                 return Text('Transfer ID: ${state.transferId}');
//               } else if (state is FileTransferFailed) {
//                 return Text('Error: ${state.error}');
//               }
//               return SizedBox.shrink();
//             },
//           ),
//         ],
//       ),
//     );
//   }

//   void _startFileTransfer(BuildContext context) {
//     final bloc = context.read<RoomBloc>();
    
//     // 1. Generate RSA key pair
//     final keyPair = await GenerateKeyPairUseCase().execute();
//     final publicKeyPem = _exportPublicKey(keyPair.publicKey);
    
//     // 2. Get file info
//     final file = await FilePicker.platform.pickFiles();
//     if (file == null) return;
    
//     final fileSize = file.files.single.size;
//     const CHUNK_SIZE = 16 * 1024; // 16KB chunks
//     final chunkCount = (fileSize / CHUNK_SIZE).ceil();
    
//     // 3. Initiate transfer
//     bloc.add(InitFileTransfer(
//       roomId: 'current-room-id',
//       receiverId: 'selected-peer-id',
//       fileName: file.files.single.name,
//       fileSize: fileSize,
//       fileType: file.files.single.extension ?? 'application/octet-stream',
//       chunkCount: chunkCount,
//       publicKeyPem: publicKeyPem,
//     ));
//   }

//   String _exportPublicKey(RSAPublicKey publicKey) {
//     // Implement PEM export
//     return '-----BEGIN PUBLIC KEY-----\n...\n-----END PUBLIC KEY-----';
//   }
// }