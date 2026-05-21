from rest_framework import serializers
from api.models import MyUser
from django.utils import timezone
from datetime import timedelta
import random
from django.conf import settings
from django.core.cache import cache
import uuid
import os
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from api.models import MyUser,Room,Peer,FileTransfer
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from api. models import EncryptedFile,EncryptedImage




class UserRegistrationSerializer(serializers.ModelSerializer):
    password2 = serializers.CharField(write_only=True)

    class Meta:
        model = MyUser
        fields = ['name', 'email', 'password', 'password2', 'image']
        extra_kwargs = {
            'password': {'write_only': True},
            'email': {'required': True}
        }

    def validate_email(self, value):
        # lowercasing email like how it is done normally
        normalized_email = value.lower()
        if MyUser.objects.filter(email=normalized_email, is_verified=True).exists():
            raise serializers.ValidationError(
                "A verified user with this email already exists. Please log in instead."
            )
        return normalized_email

    def validate(self, data):
        if data['password'] != data['password2']:
            raise serializers.ValidationError({"password": "Passwords do not match"})
        return data

    def create(self, validated_data):
        email = validated_data['email'].lower()
        password = validated_data.pop('password')
        validated_data.pop('password2')
        otp_code = str(random.randint(100000, 999999))
        cache_key = f"registration_{email}"
        image=validated_data.pop('image',None)
        image_path=None
        if image:
            # generating the unique name for the file so that it will not collide with others
            file_name=f"{uuid.uuid4().hex}_{image.name}"
            # save to this following folder temporaroly since i am caching
            temp_path=os.path.join(settings.MEDIA_ROOT,'profile_pictures',file_name)
            # if i have file to store the image then ok if not then join it
            os.makedirs(os.path.dirname(temp_path),exist_ok=True)
            # opens the file at this location if not create it wb+ means write b mostly used for image or non text files and saving this object as destination
            with open(temp_path,'wb+') as destination:
                for chunk in image.chunks():
                    destination.write(chunk)
                    
            # store the relative path
            image_path = os.path.join('profile_pictures', file_name)  
            
        # Store data in cache for 10 minutes
        cache.set(cache_key, {
            'name': validated_data['name'],
            'email': email,
            'password': password,
            'image': image_path,
            'otp_code': otp_code,
            'created_at': timezone.now().isoformat()
        }, timeout=600)
        
        self._send_otp_email(email, otp_code)
        return {
            'email':email
        }

    def _send_otp_email(self, email, otp_code):
        from api.email_templates import registration_otp_email
        from api.tasks import send_async_email as _send_task
        subject, html_body, plain_body = registration_otp_email(otp_code)
        email_kwargs = {
            'subject': subject,
            'message': plain_body,
            'from_email': settings.DEFAULT_FROM_EMAIL,
            'recipient_list': [email],
            'html_body': html_body,
            'plain_body': plain_body,
        }
        if getattr(settings, 'SEND_EMAILS_ASYNC', True):
            _send_task.delay(**email_kwargs)
        else:
            _send_task(**email_kwargs)

class UserLoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)


class VerifyOtpSerializer(serializers.Serializer):
    email = serializers.EmailField()
    otp_code = serializers.CharField(max_length=6)

    def validate(self, attrs):
        email = attrs['email'].lower()
        otp_code = attrs['otp_code']
        cache_key = f"registration_{email}"
        cached_data = cache.get(cache_key)

        if not cached_data:
            raise serializers.ValidationError("OTP expired or invalid session")

        if cached_data['otp_code'] != otp_code:
            raise serializers.ValidationError("Invalid OTP code")

        created_at = timezone.datetime.fromisoformat(cached_data['created_at'])
        if timezone.now() > created_at + timedelta(minutes=10):
            cache.delete(cache_key)
            raise serializers.ValidationError("OTP has expired")

        # Check if user was created while OTP was pending
        if MyUser.objects.filter(email=email, is_verified=True).exists():
            cache.delete(cache_key)
            raise serializers.ValidationError("User already verified")

        attrs['cached_data'] = cached_data
        return attrs

    def save(self):
        cached_data = self.validated_data['cached_data']
        email = cached_data['email']
        # setting the image_file value to None so that it will store the path
        image_file=None
        # get the path from cached data i.e temp/file_name
        # Should be using 'image' key, not 'image_path'
        if cached_data.get('image'):  # ✅ CORRECTED
            temp_path = os.path.join(settings.MEDIA_ROOT, cached_data['image'])
            
            if os.path.exists(temp_path):
            # open this directory and do the read operation
                image_file=open(temp_path,'rb')
                from django.core.files import File
                # name is also required since File function also requires the valid file name not only the data
                image_file=File(image_file,name=os.path.basename(cached_data['image']))
            
        
        # Create verified user
        user = MyUser.objects.create_user(
            email=email,
            name=cached_data['name'],
            password=cached_data['password'],
            image=image_file,
            is_verified=True
        )
        if image_file:
            image_file.close()
            os.remove(temp_path)
        
        # Clear cache
        cache.delete(f"registration_{email}")
        return user



class ForgotPasswordSerializer(serializers.Serializer):
    email = serializers.EmailField()

    def validate_email(self, value):
        try:
            user = MyUser.objects.get(email=value)
            if not user.is_verified:
                raise serializers.ValidationError("User is not verified")
            return value
        except MyUser.DoesNotExist:
            raise serializers.ValidationError("No user with this email address")

    def save(self):
        email = self.validated_data['email']
        user = MyUser.objects.get(email=email)
        otp_code = str(random.randint(100000, 999999))
        user.reset_otp_code = otp_code
        user.otp_created_at = timezone.now()
        user.save()

        from api.email_templates import forgot_password_otp_email
        from api.tasks import send_async_email as _send_task
        subject, html_body, plain_body = forgot_password_otp_email(otp_code)
        email_kwargs = {
            'subject': subject,
            'message': plain_body,
            'from_email': settings.DEFAULT_FROM_EMAIL,
            'recipient_list': [email],
            'html_body': html_body,
            'plain_body': plain_body,
        }
        if getattr(settings, 'SEND_EMAILS_ASYNC', True):
            _send_task.delay(**email_kwargs)
        else:
            _send_task(**email_kwargs)

class UpdateProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = MyUser
        fields = ["name", "image"]

class GetUserProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = MyUser
        fields = ["name","email","image"]

class ResetOtpVerifySerializer(serializers.Serializer):
    email = serializers.EmailField()
    reset_otp_code = serializers.CharField(max_length=6)

    def validate(self, attrs):
        email = attrs['email']
        code = attrs['reset_otp_code']

        try:
            user = MyUser.objects.get(email=email)
        except MyUser.DoesNotExist:
            raise serializers.ValidationError("User does not exist")

        if not user.is_verified:
            raise serializers.ValidationError("Please verify your account first")

        if user.reset_otp_code != code:
            raise serializers.ValidationError("Invalid OTP code")

        if timezone.now() > user.otp_created_at + timedelta(minutes=10):
            raise serializers.ValidationError("OTP has expired")

        attrs['user'] = user
        return attrs

class ResetPasswordSerializer(serializers.Serializer):
    email = serializers.EmailField()
    reset_otp_code = serializers.CharField(max_length=6)
    password = serializers.CharField(write_only=True)
    password2 = serializers.CharField(write_only=True)

    def validate(self, data):
        # Password validation
        if data['password'] != data['password2']:
            raise serializers.ValidationError("Passwords do not match")
        
        if len(data['password']) < 10:
            raise serializers.ValidationError("Password must be at least 10 characters")
        
        # Get user and validate OTP
        try:
            user = MyUser.objects.get(email=data['email'])
        except MyUser.DoesNotExist:
            raise serializers.ValidationError("User not found")

        if user.reset_otp_code != data['reset_otp_code']:
            raise serializers.ValidationError("Invalid OTP code")

        if timezone.now() > user.otp_created_at + timedelta(minutes=10):
            raise serializers.ValidationError("OTP has expired")

        return data

    def save(self):
        user = MyUser.objects.get(email=self.validated_data['email'])
        user.set_password(self.validated_data['password'])
        user.reset_otp_code = None  # Clear OTP after successful reset
        user.otp_created_at = None
        user.password_changed_at = timezone.now()
        user.save()

        from rest_framework_simplejwt.token_blacklist.models import OutstandingToken, BlacklistedToken
        tokens = OutstandingToken.objects.filter(user=user)
        for token in tokens:
            BlacklistedToken.objects.get_or_create(token=token)

        from api.models import DeviceInfo, SuspiciousActivityLog
        DeviceInfo.objects.filter(user=user).update(
            is_verified=False,
            is_trusted=False
        )
        
        SuspiciousActivityLog.objects.create(
            user=user,
            activity_type='password_change',
            threat_level='LOW',
            details={
                'action': 'password reset successfully',
                'devices_blacklisted': DeviceInfo.objects.filter(user=user).count(),
            },
            action_taken='logged',
        )
        
class ResendOtpCodeSerializer(serializers.Serializer):
    email = serializers.EmailField()

    def validate(self, attrs):
        email = attrs['email'].lower()
        cache_key = f"registration_{email}"
        cached_data = cache.get(cache_key)

        if not cached_data:
            raise serializers.ValidationError(
                {"error": "OTP session expired. Please register again."}
            )
            
        attrs['cache_key'] = cache_key
        attrs['cached_data'] = cached_data
        return attrs

    def save(self):
        email = self.validated_data['email'].lower()
        cache_key = self.validated_data['cache_key']
        cached_data = self.validated_data['cached_data']
        
        # Generate new OTP
        new_otp = str(random.randint(100000, 999999))
        
        # Update cache with new OTP and reset timestamp
        updated_data = {
            **cached_data,
            'otp_code': new_otp,
            'created_at': timezone.now().isoformat()
        }
        cache.set(cache_key, updated_data, timeout=600)
        
        # Resend email with HTML template
        from api.email_templates import resend_otp_email
        from api.tasks import send_async_email as _send_task
        subject, html_body, plain_body = resend_otp_email(new_otp)
        email_kwargs = {
            'subject': subject,
            'message': plain_body,
            'from_email': settings.DEFAULT_FROM_EMAIL,
            'recipient_list': [email],
            'html_body': html_body,
            'plain_body': plain_body,
        }
        if getattr(settings, 'SEND_EMAILS_ASYNC', True):
            _send_task.delay(**email_kwargs)
        else:
            _send_task(**email_kwargs)
        
        return {"email": email}
    
class ResendForgotOtpSerializer(serializers.Serializer):
    email=serializers.EmailField()
    def validate(self, attrs):
      email=attrs['email']
      
      try:
          user=MyUser.objects.get(email=email)
          if not user.is_verified:
              raise serializers.ValidationError({"msg":"Unable to resend the otp since you are not registered"})
          attrs['user']=user
          return attrs
          
          
      except MyUser.DoesNotExist:
          raise serializers.ValidationError({"msg":"Unable to resend the otp"})  
    def save(self):
        user=self.validated_data['user']
        new_otp=str(random.randint(100000,999999))
        user.reset_otp_code=new_otp
        user.otp_created_at=timezone.now()
        user.save()
        
        from api.email_templates import resend_forgot_otp_email
        from api.tasks import send_async_email as _send_task
        subject, html_body, plain_body = resend_forgot_otp_email(new_otp)
        email_kwargs = {
            'subject': subject,
            'message': plain_body,
            'from_email': settings.DEFAULT_FROM_EMAIL,
            'recipient_list': [user.email],
            'html_body': html_body,
            'plain_body': plain_body,
        }
        if getattr(settings, 'SEND_EMAILS_ASYNC', True):
            _send_task.delay(**email_kwargs)
        else:
            _send_task(**email_kwargs)
        
class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = MyUser
        fields = ['id','name', 'email', 'password']
        
class RoomSerializer(serializers.ModelSerializer):
    owner = UserSerializer(read_only=True)
    peer_count = serializers.SerializerMethodField()
    
    class Meta:
        model = Room
        fields = ['id', 'name', 'passcode', 'owner', 'created_at', 'is_active', 'max_peers', 'peer_count']
        read_only_fields = ['id', 'passcode', 'owner', 'created_at', 'peer_count']
        
    def get_peer_count(self, obj):
        return obj.peers.filter(is_connected=True, is_authenticated=True).count()

class RoomCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Room
        fields = ['name', 'max_peers']
        
class RoomJoinSerializer(serializers.Serializer):
    room_id = serializers.UUIDField()
    passcode = serializers.CharField(max_length=8)
    peer_id = serializers.CharField(max_length=100)
    device_name = serializers.CharField(max_length=100, default='Unknown Device')

class PeerSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)
    
    class Meta:
        model = Peer
        fields = ['id', 'peer_id', 'user', 'device_name', 'is_authenticated', 'is_connected', 'joined_at', 'last_seen']

class FileTransferSerializer(serializers.ModelSerializer):
    sender = UserSerializer(read_only=True)
    receiver = UserSerializer(read_only=True)
    progress = serializers.SerializerMethodField()
    
    class Meta:
        model = FileTransfer
        fields = ['id', 'sender', 'receiver', 'room', 'file_name', 'file_size', 
                 'file_type', 'status', 'progress', 'created_at', 'completed_at', 
                 'transfer_speed', 'chunk_count', 'chunks_received',
                 'sender_public_key', 'sender_signature', 'payload_hash', 
                 'encrypted_aes_key', 'file_nonce', 'file_tag']
        read_only_fields = fields
        
    def get_progress(self, obj):
        return obj.progress()

class FileTransferInitSerializer(serializers.Serializer):
    receiver_id = serializers.CharField(max_length=100)
    room_id = serializers.UUIDField()
    file_name = serializers.CharField(max_length=255)
    file_size = serializers.IntegerField(min_value=1, max_value=1024*1024*1024)  
    file_type = serializers.CharField(max_length=100)
    chunk_count = serializers.IntegerField(min_value=1)
    # E2EE fields (optional for REST init — the full metadata goes via WebSocket)
    sender_public_key = serializers.CharField(required=False, default='')
    sender_signature = serializers.CharField(required=False, allow_blank=True)    # base64
    payload_hash = serializers.CharField(required=False, allow_blank=True)        # hex SHA-256
    encrypted_aes_key = serializers.CharField(required=False, allow_blank=True)   # base64
    file_nonce = serializers.CharField(required=False, allow_blank=True)          # base64
    file_tag = serializers.CharField(required=False, allow_blank=True)            # base64

# serializers.py
class ChangePasswordSerializer(serializers.Serializer):
    current_password = serializers.CharField(required=True)
    password = serializers.CharField(required=True, write_only=True, min_length=8)
    password2 = serializers.CharField(required=True, write_only=True)
    otp_code = serializers.CharField(required=True, max_length=6)

    def validate_password(self, value):          
        import re
        if not re.search(r'[A-Z]', value):
            raise serializers.ValidationError("Must contain an uppercase letter.")
        if not re.search(r'\d', value):
            raise serializers.ValidationError("Must contain a number.")
        if not re.search(r'[!@#$%^&*(),.?\":{}|<>]', value):
            raise serializers.ValidationError("Must contain a special character.")
        return value

    def validate(self, attrs):                   
        if attrs['password'] != attrs['password2']:
            raise serializers.ValidationError({"password2": "Passwords do not match."})
        return attrs
        
        
        
        
        
    
        
