# signaling/consumers.py
import json
import logging
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from django.conf import settings
from django.utils import timezone
from api. models import Room, Peer, FileTransfer
import os
import hashlib
import base64


logger = logging.getLogger(__name__)

class SignalingConsumer(AsyncWebsocketConsumer):
    MAX_CHUNK_SIZE = 16 * 1024  # 16KB chunks
    
    async def connect(self):
        self.room_id = self.scope['url_route']['kwargs']['room_id']
        self.room_group_name = f'room_{self.room_id}'
        self.peer_id = None
        self.user = self.scope.get('user')
        
        if not self.user or self.user.is_anonymous:
            await self.close(code=4001)
            return
            
        # Check if user is temporarily blocked or account is locked
        is_blocked = await self.is_user_blocked(self.user)
        if is_blocked:
            await self.send_error('Account temporarily blocked')
            await self.close(code=4003)
            return

        # Join room group
        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name
        )
        await self.accept()

    async def disconnect(self, close_code):
        # Leave room group
        await self.channel_layer.group_discard(
            self.room_group_name,
            self.channel_name
        )
        
        # Update peer status
        if self.peer_id:
            await self.update_peer_status(False)
            
            # Notify others about peer leaving
            await self.channel_layer.group_send(
                self.room_group_name,
                {
                    'type': 'peer_left',
                    'peer_id': self.peer_id,
                    'user_id': str(self.user.id),
                    'sender_channel': self.channel_name
                }
            )

    async def receive(self, text_data):
        try:
            data = json.loads(text_data)
            message_type = data.get('type')

            # Authentication and connection
            if message_type == 'authenticate':
                await self.handle_authentication(data)
            elif message_type == 'join':
                await self.handle_join(data)
                
            # WebRTC signaling
            elif message_type == 'offer':
                await self.handle_offer(data)
            elif message_type == 'answer':
                await self.handle_answer(data)
            elif message_type == 'ice-candidate':
                await self.handle_ice_candidate(data)
            elif message_type == 'leave':
                await self.handle_leave(data)
                
            # File transfer handling
            elif message_type == 'file_metadata':
                await self.handle_file_metadata(data)
            elif message_type == 'data_channel_ready':
                await self.handle_data_channel_ready(data)
            elif message_type == 'request_resume':
                await self.handle_request_resume(data)
            elif message_type == 'resume_data':
                await self.handle_resume_data(data)
            elif message_type == 'chunk_ack':
                await self.handle_chunk_ack(data)
            elif message_type == 'integrity_failure':
                await self.handle_integrity_failure(data)
                
            # Transfer management
            elif message_type == 'transfer_complete':
                await self.handle_transfer_complete(data)
            elif message_type == 'transfer_error':
                await self.handle_transfer_error(data)

        except json.JSONDecodeError:
            await self.send_error('Invalid JSON format')
        except Exception as e:
            logger.error(f"Error processing message: {str(e)}", exc_info=True)
            await self.send_error('Internal server error')

    async def send_error(self, message):
        """Send standardized error message to client"""
        await self.send(text_data=json.dumps({
            'type': 'error',
            'message': message
        }))

    # ========================
    # Authentication Handlers
    # ========================
    async def handle_authentication(self, data):
        peer_id = data.get('peer_id')
        device_name = data.get('device_name', 'Unknown Device')
        
        if not self.user or self.user.is_anonymous:
            await self.send_error('Authentication failed: Invalid user')
            await self.close()
            return

        self.peer_id = peer_id
        
        # Create or update peer
        peer = await self.create_or_update_peer(peer_id, device_name, True)
        
        if peer:
            await self.send(text_data=json.dumps({
                'type': 'authentication-success',
                'peer_id': peer_id,
                'message': 'Successfully authenticated'
            }))
        else:
            await self.send_error('Failed to create peer record')

    async def handle_join(self, data):
        if not self.peer_id:
            await self.send_error('Not authenticated. Please authenticate first.')
            return

        for peer in await self.get_connected_peers_excluding_self():
            await self.send(text_data=json.dumps({
                'type': 'peer-joined',
                'peer_id': peer['peer_id'],
                'user_id': peer['user_id'],
                'username': peer['username'],
            }))
        
        # Notify others in the room about new peer
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'peer_joined',
                'peer_id': self.peer_id,
                'user_id': str(self.user.id),
                'username': self.user.name,
                'sender_channel': self.channel_name
            }
        )

    # ========================
    # WebRTC Signaling
    # ========================
    async def handle_offer(self, data):
        if not self.peer_id:
            return
            
        target_peer = data.get('target_peer')
        offer = data.get('offer')
        
        # Verify target peer is authenticated
        is_target_authenticated = await self.verify_peer_authentication(target_peer)
        if not is_target_authenticated:
            await self.send_error(f'Target peer {target_peer} is not authenticated')
            return
        
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'webrtc_offer',
                'sender_peer': self.peer_id,
                'target_peer': target_peer,
                'offer': offer,
                'sender_channel': self.channel_name
            }
        )

    async def handle_answer(self, data):
        if not self.peer_id:
            return
            
        target_peer = data.get('target_peer')
        answer = data.get('answer')
        
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'webrtc_answer',
                'sender_peer': self.peer_id,
                'target_peer': target_peer,
                'answer': answer,
                'sender_channel': self.channel_name
            }
        )

    async def handle_ice_candidate(self, data):
        if not self.peer_id:
            return
            
        target_peer = data.get('target_peer')
        candidate = data.get('candidate')
        
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'ice_candidate',
                'sender_peer': self.peer_id,
                'target_peer': target_peer,
                'candidate': candidate,
                'sender_channel': self.channel_name
            }
        )

    async def handle_leave(self, data):
        if self.peer_id:
            await self.update_peer_status(False)
            
            await self.channel_layer.group_send(
                self.room_group_name,
                {
                    'type': 'peer_left',
                    'peer_id': self.peer_id,
                    'user_id': str(self.user.id),
                    'sender_channel': self.channel_name
                }
            )

    # ========================
    # File Transfer Handlers
    # ========================
    async def handle_file_metadata(self, data):
        """
        Handle encrypted file metadata with full E2EE fields.

        The server acts as a DUMB RELAY — it stores the transfer record
        for tracking/resumption but NEVER sees the plaintext AES key.
        All crypto fields are passed straight through from sender to receiver.
        """
        try:
            required_fields = [
                'transfer_id', 'receiver_id', 'file_name',
                'file_size', 'file_type', 'chunk_count',
                'encrypted_aes_key',    # RSA-OAEP wrapped AES key (base64)
                'file_nonce',           # 12-byte GCM nonce (base64)
                'file_tag',             # 16-byte GCM auth tag (base64)
                'sender_public_key',    # Ed25519 public key PEM (for signature verification)
                'sender_signature',     # Ed25519 signature (base64)
                'payload_hash',         # SHA-256 of transfer payload (hex)
                'timestamp',            # ISO timestamp baked into signed payload
            ]
            if not all(field in data for field in required_fields):
                missing = [f for f in required_fields if f not in data]
                await self.send_error(f'Missing required fields: {missing}')
                return
                
            transfer_id = data['transfer_id']
            receiver_id = data['receiver_id']
            
            # Verify receiver is authenticated in this room
            is_receiver_authenticated = await self.verify_peer_authentication(receiver_id)
            if not is_receiver_authenticated:
                await self.send_error(f'Receiver {receiver_id} not authenticated')
                return
                
            # Create file transfer record with E2EE metadata
            transfer = await self.create_file_transfer(
                transfer_id=transfer_id,
                file_name=data['file_name'],
                file_size=data['file_size'],
                file_type=data['file_type'],
                chunk_count=data['chunk_count'],
                encrypted_aes_key=data['encrypted_aes_key'],
                file_nonce=data['file_nonce'],
                file_tag=data['file_tag'],
                sender_public_key=data['sender_public_key'],
                sender_signature=data['sender_signature'],
                payload_hash=data['payload_hash'],
            )
            
            if not transfer:
                await self.send_error('Failed to create transfer record')
                return
                
            # Relay ALL E2EE metadata to the receiver — server is a dumb pipe
            await self.channel_layer.group_send(
                self.room_group_name,
                {
                    'type': 'file_metadata',
                    'sender_peer': self.peer_id,
                    'target_peer': receiver_id,
                    'transfer_id': transfer_id,
                    'file_name': data['file_name'],
                    'file_size': data['file_size'],
                    'file_type': data['file_type'],
                    'chunk_count': data['chunk_count'],
                    # --- E2EE fields relayed untouched ---
                    'encrypted_aes_key': data['encrypted_aes_key'],
                    'file_nonce': data['file_nonce'],
                    'file_tag': data['file_tag'],
                    'sender_public_key': data['sender_public_key'],
                    'sender_signature': data['sender_signature'],
                    'payload_hash': data['payload_hash'],
                    'timestamp': data['timestamp'],
                    'sender_id': str(self.user.id),
                }
            )
            
            logger.info(f"E2EE file metadata sent for transfer {transfer_id}")
            
        except Exception as e:
            logger.error(f"File metadata error: {str(e)}")
            await self.send_error('File metadata processing failed')

    async def handle_data_channel_ready(self, data):
        """Handle data channel readiness notification"""
        sender_peer = data.get('sender_peer')
        transfer_id = data.get('transfer_id')
        
        # Notify sender that data channel is ready
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'data_channel_ready',
                'sender_peer': self.peer_id,
                'target_peer': sender_peer,
                'transfer_id': transfer_id
            }
        )

    async def handle_request_resume(self, data):
        """Handle request to resume interrupted transfer"""
        transfer_id = data.get('transfer_id')
        sender_peer = data.get('sender_peer')
        
        # Get current progress from database
        progress = await self.get_transfer_progress(transfer_id)
        
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'resume_data',
                'sender_peer': self.peer_id,
                'target_peer': sender_peer,
                'transfer_id': transfer_id,
                'last_chunk': progress
            }
        )

    async def handle_resume_data(self, data):
        """Handle resume information"""
        transfer_id = data.get('transfer_id')
        last_chunk = data.get('last_chunk')
        
        # Update sender with resume information
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'resume_info',
                'sender_peer': self.peer_id,
                'target_peer': data['sender_peer'],
                'transfer_id': transfer_id,
                'last_chunk': last_chunk
            }
        )

    async def handle_chunk_ack(self, data):
        """Handle acknowledgment of chunk reception"""
        transfer_id = data.get('transfer_id')
        chunk_index = data.get('chunk_index')
        
        # Update transfer progress
        updated = await self.update_transfer_chunk(transfer_id, chunk_index)
        
        if updated:
            logger.debug(f"Chunk {chunk_index} acked for transfer {transfer_id}")
        else:
            logger.warning(f"Failed to update chunk ack for transfer {transfer_id}")

    async def handle_integrity_failure(self, data):
        """Handle chunk integrity failure notification"""
        transfer_id = data.get('transfer_id')
        chunk_index = data.get('chunk_index')
        
        # Notify sender to resend the chunk
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'resend_chunk',
                'sender_peer': self.peer_id,
                'target_peer': data['sender_peer'],
                'transfer_id': transfer_id,
                'chunk_index': chunk_index
            }
        )

    async def handle_transfer_complete(self, data):
        """Handle transfer completion notification"""
        transfer_id = data.get('transfer_id')
        
        # Mark transfer as complete in database
        updated = await self.complete_transfer(transfer_id)
        
        if updated:
            logger.info(f"Transfer {transfer_id} marked as completed")
            await self.send(text_data=json.dumps({
                'type': 'transfer_complete_ack',
                'transfer_id': transfer_id
            }))
        else:
            logger.warning(f"Failed to mark transfer {transfer_id} as complete")
            await self.send_error(f'Failed to complete transfer {transfer_id}')

    async def handle_transfer_error(self, data):
        """Handle transfer error notification"""
        transfer_id = data.get('transfer_id')
        error = data.get('error', 'Unknown error')
        
        # Mark transfer as failed in database
        await self.fail_transfer(transfer_id, error)
        logger.error(f"Transfer {transfer_id} failed: {error}")

    # ========================
    # WebSocket Message Handlers
    # ========================
    async def peer_joined(self, event):
        if event['sender_channel'] != self.channel_name:
            await self.send(text_data=json.dumps({
                'type': 'peer-joined',
                'peer_id': event['peer_id'],
                'user_id': event['user_id'],
                'username': event['username']
            }))

    async def peer_left(self, event):
        if event['sender_channel'] != self.channel_name:
            await self.send(text_data=json.dumps({
                'type': 'peer-left',
                'peer_id': event['peer_id'],
                'user_id': event['user_id']
            }))

    async def webrtc_offer(self, event):
        if event['target_peer'] == self.peer_id:
            await self.send(text_data=json.dumps({
                'type': 'offer',
                'sender_peer': event['sender_peer'],
                'offer': event['offer']
            }))

    async def webrtc_answer(self, event):
        if event['target_peer'] == self.peer_id:
            await self.send(text_data=json.dumps({
                'type': 'answer',
                'sender_peer': event['sender_peer'],
                'answer': event['answer']
            }))

    async def ice_candidate(self, event):
        if event['target_peer'] == self.peer_id:
            await self.send(text_data=json.dumps({
                'type': 'ice-candidate',
                'sender_peer': event['sender_peer'],
                'candidate': event['candidate']
            }))

    async def file_metadata(self, event):
        """Relay full E2EE metadata to the target receiver."""
        if event['target_peer'] == self.peer_id:
            await self.send(text_data=json.dumps({
                'type': 'file_metadata',
                'sender_peer': event['sender_peer'],
                'transfer_id': event['transfer_id'],
                'file_name': event['file_name'],
                'file_size': event['file_size'],
                'file_type': event['file_type'],
                'chunk_count': event['chunk_count'],
                # --- E2EE fields ---
                'encrypted_aes_key': event['encrypted_aes_key'],
                'file_nonce': event['file_nonce'],
                'file_tag': event['file_tag'],
                'sender_public_key': event['sender_public_key'],
                'sender_signature': event['sender_signature'],
                'payload_hash': event['payload_hash'],
                'timestamp': event['timestamp'],
                'sender_id': event['sender_id'],
            }))

    async def data_channel_ready(self, event):
        if event['target_peer'] == self.peer_id:
            await self.send(text_data=json.dumps({
                'type': 'data_channel_ready',
                'sender_peer': event['sender_peer'],
                'transfer_id': event['transfer_id']
            }))
    
    async def resume_data(self, event):
        if event['target_peer'] == self.peer_id:
            await self.send(text_data=json.dumps({
                'type': 'resume_data',
                'transfer_id': event['transfer_id'],
                'last_chunk': event['last_chunk']
            }))
    
    async def resume_info(self, event):
        if event['target_peer'] == self.peer_id:
            await self.send(text_data=json.dumps({
                'type': 'resume_info',
                'transfer_id': event['transfer_id'],
                'last_chunk': event['last_chunk']
            }))
            
    async def resend_chunk(self, event):
        if event['target_peer'] == self.peer_id:
            await self.send(text_data=json.dumps({
                'type': 'resend_chunk',
                'transfer_id': event['transfer_id'],
                'chunk_index': event['chunk_index']
            }))



    def generate_chunk_hash(self, chunk_data):
        """Generate SHA-256 hash for chunk validation"""
        return hashlib.sha256(chunk_data).hexdigest()

    # ========================
    # Database Operations
    # ========================
    @database_sync_to_async
    def is_user_blocked(self, user):
        from django.contrib.auth import get_user_model
        User = get_user_model()
        try:
            db_user = User.objects.get(id=user.id)
            return db_user.is_temporarily_blocked_active() or db_user.is_account_locked()
        except User.DoesNotExist:
            return True

    @database_sync_to_async
    def verify_peer_authentication(self, peer_id):
        """Verify peer is authenticated and in the same room"""
        try:
            room = Room.objects.get(id=self.room_id)
            peer = Peer.objects.get(
                room=room,
                peer_id=peer_id,
                is_authenticated=True,
                is_connected=True
            )
            return True
        except (Room.DoesNotExist, Peer.DoesNotExist):
            return False

    @database_sync_to_async
    def create_or_update_peer(self, peer_id, device_name, is_authenticated):
        """Create or update peer record"""
        try:
            room = Room.objects.get(id=self.room_id)
            peer, created = Peer.objects.get_or_create(
                room=room,
                peer_id=peer_id,
                defaults={
                    'user': self.user,
                    'device_name': device_name,
                    'is_authenticated': is_authenticated,
                    'is_connected': True
                }
            )
            if not created:
                peer.user = self.user
                peer.device_name = device_name
                peer.is_authenticated = is_authenticated
                peer.is_connected = True
                peer.save()
            return peer
        except Room.DoesNotExist:
            logger.error(f"Room {self.room_id} not found")
            return None
        except Exception as e:
            logger.error(f"Error creating/updating peer: {str(e)}")
            return None

    @database_sync_to_async
    def get_connected_peers_excluding_self(self):
        """Return already-connected peers so a joining client can send too."""
        try:
            room = Room.objects.get(id=self.room_id)
            peers = room.peers.filter(
                is_connected=True,
                is_authenticated=True,
            ).exclude(peer_id=self.peer_id).select_related('user')
            return [
                {
                    'peer_id': peer.peer_id,
                    'user_id': str(peer.user.id),
                    'username': peer.user.name,
                }
                for peer in peers
            ]
        except Room.DoesNotExist:
            logger.error(f"Room {self.room_id} not found")
            return []
        except Exception as e:
            logger.error(f"Error fetching connected peers: {str(e)}")
            return []

    @database_sync_to_async
    def update_peer_status(self, is_connected):
        """Update peer connection status"""
        try:
            room = Room.objects.get(id=self.room_id)
            peer = Peer.objects.get(room=room, peer_id=self.peer_id)
            peer.is_connected = is_connected
            if not is_connected:
                peer.is_authenticated = False
            peer.save()
            return True
        except (Room.DoesNotExist, Peer.DoesNotExist):
            logger.warning(f"Peer {self.peer_id} not found in room {self.room_id}")
            return False

    @database_sync_to_async
    def create_file_transfer(
        self, transfer_id, file_name, file_size, file_type, chunk_count,
        encrypted_aes_key, file_nonce, file_tag,
        sender_public_key, sender_signature, payload_hash,
    ):
        """
        Create a FileTransfer record with full E2EE metadata.

        All crypto fields are stored as-is (base64 strings from the client).
        The server never decrypts or inspects the AES key — it just persists
        the record for tracking, resumption, and audit.
        """
        try:
            room = Room.objects.get(id=self.room_id)
            peers = room.peers.filter(
                is_connected=True, 
                is_authenticated=True
            ).exclude(user=self.user)
            
            if not peers.exists():
                logger.error(f"No valid receiver found for transfer {transfer_id}")
                return None
                
            receiver = peers.first().user
            
            # Decode base64 fields into bytes for BinaryField storage
            transfer = FileTransfer.objects.create(
                id=transfer_id,
                sender=self.user,
                receiver=receiver,
                room=room,
                file_name=file_name,
                file_size=file_size,
                file_type=file_type,
                chunk_count=chunk_count,
                # E2EE fields — stored for audit/resumption, server never decrypts
                encrypted_aes_key=base64.b64decode(encrypted_aes_key),
                file_nonce=base64.b64decode(file_nonce),
                file_tag=base64.b64decode(file_tag),
                sender_public_key=sender_public_key,
                sender_signature=base64.b64decode(sender_signature),
                payload_hash=payload_hash,
            )
            return transfer
        except Room.DoesNotExist:
            logger.error(f"Room {self.room_id} not found")
            return None
        except Exception as e:
            logger.error(f"Error creating transfer: {str(e)}")
            return None

    @database_sync_to_async
    def update_transfer_chunk(self, transfer_id, chunk_index):
        """Update last successful chunk received"""
        try:
            transfer = FileTransfer.objects.get(id=transfer_id, receiver=self.user)
            if chunk_index > transfer.last_chunk_index:
                transfer.last_chunk_index = chunk_index
                transfer.chunks_received = chunk_index + 1
                transfer.save()
            return True
        except FileTransfer.DoesNotExist:
            logger.warning(f"Transfer {transfer_id} not found")
            return False

    @database_sync_to_async
    def get_transfer_progress(self, transfer_id):
        """Get current transfer progress"""
        try:
            transfer = FileTransfer.objects.get(id=transfer_id, receiver=self.user)
            return transfer.last_chunk_index
        except FileTransfer.DoesNotExist:
            return 0

    @database_sync_to_async
    def complete_transfer(self, transfer_id):
        """Mark transfer as completed"""
        try:
            transfer = FileTransfer.objects.get(id=transfer_id)
            transfer.status = 'completed'
            transfer.completed_at = timezone.now()
            transfer.save()
            return True
        except FileTransfer.DoesNotExist:
            return False

    @database_sync_to_async
    def fail_transfer(self, transfer_id, error):
        """Mark transfer as failed"""
        try:
            transfer = FileTransfer.objects.get(id=transfer_id)
            transfer.status = 'failed'
            transfer.save()
            return True
        except FileTransfer.DoesNotExist:
            return False
