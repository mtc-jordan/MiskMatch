"""
MiskMatch — Storage Service (AWS S3)
Encrypted photo and voice upload with CloudFront CDN delivery.
All user media stored with server-side encryption (SSE-S3).
"""

import io
import uuid
import logging
from enum import Enum
from typing import Optional, Tuple

import boto3
from botocore.exceptions import ClientError
from PIL import Image

from app.core.config import settings

logger = logging.getLogger(__name__)


# ─────────────────────────────────────────────
# MEDIA TYPES
# ─────────────────────────────────────────────

class MediaType(str, Enum):
    PROFILE_PHOTO = "profiles"
    GALLERY_PHOTO = "gallery"
    VOICE_INTRO   = "voice"
    QURAN_RECITATION = "quran"


ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/jpg", "image/png", "image/webp"}
ALLOWED_AUDIO_TYPES = {"audio/mpeg", "audio/mp4", "audio/webm", "audio/ogg", "audio/wav"}

MAX_PHOTO_SIZE_MB   = 10
MAX_AUDIO_SIZE_MB   = 20
MAX_VOICE_DURATION  = 60   # seconds


# ─────────────────────────────────────────────
# S3 CLIENT
# ─────────────────────────────────────────────

def get_s3_client():
    return boto3.client(
        "s3",
        region_name=settings.AWS_REGION,
        aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
        aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
    )


# ─────────────────────────────────────────────
# KEY BUILDERS
# ─────────────────────────────────────────────

def build_photo_key(user_id: str, filename_suffix: str = "main") -> str:
    """
    S3 key for profile photo.
    Format: profiles/{user_id}/photo_{suffix}_{uuid}.jpg
    Never predictable — prevents enumeration attacks.
    """
    unique = uuid.uuid4().hex[:8]
    return f"profiles/{user_id}/photo_{filename_suffix}_{unique}.jpg"


def build_voice_key(user_id: str) -> str:
    unique = uuid.uuid4().hex[:8]
    return f"voice/{user_id}/intro_{unique}.mp4"


def build_quran_key(user_id: str) -> str:
    unique = uuid.uuid4().hex[:8]
    return f"quran/{user_id}/recitation_{unique}.mp4"


def build_gallery_key(user_id: str, index: int) -> str:
    unique = uuid.uuid4().hex[:8]
    return f"gallery/{user_id}/photo_{index}_{unique}.jpg"


# ─────────────────────────────────────────────
# IMAGE PROCESSING
# ─────────────────────────────────────────────

def process_profile_photo(
    raw_bytes: bytes,
    content_type: str,
    max_dimension: int = 800,
) -> Tuple[bytes, str]:
    """
    Process and optimise a profile photo:
    1. Validate it's a real image
    2. Resize to max_dimension (preserving aspect ratio)
    3. Convert to JPEG for consistent format
    4. Strip EXIF metadata (privacy)
    5. Return processed bytes + content type

    Raises:
        ValueError: If image is invalid or too small
    """
    if content_type not in ALLOWED_IMAGE_TYPES:
        raise ValueError(
            f"Invalid image type: {content_type}. "
            f"Allowed: {', '.join(ALLOWED_IMAGE_TYPES)}"
        )

    try:
        img = Image.open(io.BytesIO(raw_bytes))
    except Exception:
        raise ValueError("File is not a valid image")

    # Minimum resolution check
    if img.width < 200 or img.height < 200:
        raise ValueError("Image too small. Minimum 200x200 pixels required.")

    # Convert to RGB (handles RGBA, palette modes, etc.)
    if img.mode != "RGB":
        img = img.convert("RGB")

    # Resize preserving aspect ratio
    img.thumbnail((max_dimension, max_dimension), Image.LANCZOS)

    # Strip EXIF (contains GPS, device info — privacy risk)
    clean_img = Image.new("RGB", img.size)
    clean_img.paste(img)

    # Encode to JPEG
    output = io.BytesIO()
    clean_img.save(output, format="JPEG", quality=85, optimize=True)
    output.seek(0)

    return output.read(), "image/jpeg"


# ─────────────────────────────────────────────
# UPLOAD FUNCTIONS
# ─────────────────────────────────────────────

async def upload_profile_photo(
    user_id: str,
    file_bytes: bytes,
    content_type: str,
    suffix: str = "main",
) -> str:
    """
    Process and upload a profile photo to S3.

    Returns:
        CloudFront CDN URL for the uploaded photo

    Raises:
        ValueError: If image is invalid
        RuntimeError: If S3 upload fails
    """
    # Validate size
    size_mb = len(file_bytes) / (1024 * 1024)
    if size_mb > MAX_PHOTO_SIZE_MB:
        raise ValueError(f"Photo too large: {size_mb:.1f}MB. Maximum {MAX_PHOTO_SIZE_MB}MB.")

    # Process image
    processed_bytes, processed_type = process_profile_photo(file_bytes, content_type)

    # Build S3 key
    key = build_photo_key(user_id, suffix)

    # Upload to S3 with server-side encryption
    try:
        s3 = get_s3_client()
        s3.put_object(
            Bucket=settings.S3_BUCKET_PROFILES,
            Key=key,
            Body=processed_bytes,
            ContentType=processed_type,
            ServerSideEncryption="AES256",          # SSE-S3 encryption at rest
            CacheControl="max-age=31536000",        # 1 year CDN cache
            Metadata={
                "user-id": str(user_id),
                "upload-type": "profile-photo",
            },
            # NOT public-read — accessed only via signed URLs or CloudFront
        )
    except ClientError as e:
        logger.error(f"S3 upload failed for user {user_id}: {e}")
        raise RuntimeError("Photo upload failed. Please try again.")

    # Return CloudFront URL (fast CDN, not direct S3)
    if settings.CLOUDFRONT_URL:
        return f"{settings.CLOUDFRONT_URL.rstrip('/')}/{key}"

    # Fallback to S3 URL in development
    return f"https://{settings.S3_BUCKET_PROFILES}.s3.{settings.AWS_REGION}.amazonaws.com/{key}"


async def upload_voice_intro(
    user_id: str,
    file_bytes: bytes,
    content_type: str,
) -> Tuple[str, Optional[float]]:
    """
    Upload a voice introduction audio file.

    Returns:
        Tuple of (CDN URL, duration in seconds)
    """
    if content_type not in ALLOWED_AUDIO_TYPES:
        raise ValueError(
            f"Invalid audio format: {content_type}. "
            f"Allowed: mp3, mp4, webm, ogg, wav"
        )

    size_mb = len(file_bytes) / (1024 * 1024)
    if size_mb > MAX_AUDIO_SIZE_MB:
        raise ValueError(f"Audio too large: {size_mb:.1f}MB. Maximum {MAX_AUDIO_SIZE_MB}MB.")

    key = build_voice_key(user_id)

    # Get audio duration
    duration = _get_audio_duration(file_bytes)
    if duration and duration > MAX_VOICE_DURATION:
        raise ValueError(f"Voice intro too long: {duration:.0f}s. Maximum {MAX_VOICE_DURATION}s.")

    try:
        s3 = get_s3_client()
        s3.put_object(
            Bucket=settings.S3_BUCKET_MEDIA,
            Key=key,
            Body=file_bytes,
            ContentType=content_type,
            ServerSideEncryption="AES256",
            Metadata={
                "user-id": str(user_id),
                "upload-type": "voice-intro",
                "duration": str(duration or ""),
            },
        )
    except ClientError as e:
        logger.error(f"S3 voice upload failed for user {user_id}: {e}")
        raise RuntimeError("Voice upload failed. Please try again.")

    if settings.CLOUDFRONT_URL:
        url = f"{settings.CLOUDFRONT_URL.rstrip('/')}/{key}"
    else:
        url = f"https://{settings.S3_BUCKET_MEDIA}.s3.{settings.AWS_REGION}.amazonaws.com/{key}"

    return url, duration


async def upload_quran_recitation(
    user_id: str,
    file_bytes: bytes,
    content_type: str,
) -> str:
    """Upload a Quran recitation sample for recitation matching."""
    if content_type not in ALLOWED_AUDIO_TYPES:
        raise ValueError("Invalid audio format")

    size_mb = len(file_bytes) / (1024 * 1024)
    if size_mb > MAX_AUDIO_SIZE_MB:
        raise ValueError(f"Audio too large. Maximum {MAX_AUDIO_SIZE_MB}MB.")

    key = build_quran_key(user_id)

    try:
        s3 = get_s3_client()
        s3.put_object(
            Bucket=settings.S3_BUCKET_MEDIA,
            Key=key,
            Body=file_bytes,
            ContentType=content_type,
            ServerSideEncryption="AES256",
            Metadata={"user-id": str(user_id), "upload-type": "quran-recitation"},
        )
    except ClientError as e:
        logger.error(f"Quran upload failed: {e}")
        raise RuntimeError("Upload failed. Please try again.")

    if settings.CLOUDFRONT_URL:
        return f"{settings.CLOUDFRONT_URL.rstrip('/')}/{key}"
    return f"https://{settings.S3_BUCKET_MEDIA}.s3.{settings.AWS_REGION}.amazonaws.com/{key}"


async def delete_media(key: str, bucket: str) -> None:
    """Delete a media file from S3. Used when user replaces their photo."""
    try:
        s3 = get_s3_client()
        s3.delete_object(Bucket=bucket, Key=key)
    except ClientError as e:
        # Log but don't crash — orphan files are not a fatal error
        logger.warning(f"Failed to delete S3 object {key}: {e}")


# ─────────────────────────────────────────────
# SIGNED URLS (for protected content)
# ─────────────────────────────────────────────

def generate_signed_url(key: str, bucket: str, expiry_seconds: int = 3600) -> str:
    """
    Generate a temporary signed URL for accessing private S3 content.
    Used for: profile photos of matches (before mutual interest confirmed).
    """
    try:
        s3 = get_s3_client()
        return s3.generate_presigned_url(
            "get_object",
            Params={"Bucket": bucket, "Key": key},
            ExpiresIn=expiry_seconds,
        )
    except ClientError as e:
        logger.error(f"Failed to generate signed URL for {key}: {e}")
        return ""


# ─────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────

def _get_audio_duration(file_bytes: bytes) -> Optional[float]:
    """
    Attempt to extract audio duration from file bytes.
    Returns None if unable to determine (non-fatal).
    """
    try:
        # Try mutagen for duration
        import mutagen
        from mutagen import File as MutagenFile
        audio = MutagenFile(io.BytesIO(file_bytes))
        if audio and hasattr(audio, "info") and hasattr(audio.info, "length"):
            return float(audio.info.length)
    except Exception:
        pass
    return None


def extract_s3_key_from_url(url: str) -> Optional[str]:
    """Extract S3 key from a CloudFront or S3 URL."""
    if not url:
        return None
    try:
        if settings.CLOUDFRONT_URL and url.startswith(settings.CLOUDFRONT_URL):
            return url.replace(settings.CLOUDFRONT_URL.rstrip("/") + "/", "")
        # Handle direct S3 URL
        parts = url.split(".amazonaws.com/")
        if len(parts) == 2:
            return parts[1]
    except Exception:
        pass
    return None
