"""MiskMatch — Storage Service Tests"""

import io
import pytest
from unittest.mock import patch, MagicMock, AsyncMock
from botocore.exceptions import ClientError

from app.services.storage import (
    build_photo_key,
    build_voice_key,
    build_quran_key,
    build_gallery_key,
    process_profile_photo,
    upload_profile_photo,
    upload_voice_intro,
    upload_quran_recitation,
    delete_media,
    generate_signed_url,
    extract_s3_key_from_url,
    ALLOWED_IMAGE_TYPES,
    ALLOWED_AUDIO_TYPES,
    MAX_PHOTO_SIZE_MB,
    MAX_AUDIO_SIZE_MB,
)


# ─────────────────────────────────────────────
# KEY BUILDERS
# ─────────────────────────────────────────────

class TestKeyBuilders:

    def test_photo_key_format(self):
        key = build_photo_key("user123", "main")
        assert key.startswith("profiles/user123/photo_main_")
        assert key.endswith(".jpg")

    def test_photo_key_unique(self):
        k1 = build_photo_key("user123")
        k2 = build_photo_key("user123")
        assert k1 != k2  # UUID suffix makes them unique

    def test_voice_key_format(self):
        key = build_voice_key("user123")
        assert key.startswith("voice/user123/intro_")
        assert key.endswith(".mp4")

    def test_quran_key_format(self):
        key = build_quran_key("user123")
        assert key.startswith("quran/user123/recitation_")

    def test_gallery_key_includes_index(self):
        key = build_gallery_key("user123", 2)
        assert "photo_2_" in key


# ─────────────────────────────────────────────
# IMAGE PROCESSING
# ─────────────────────────────────────────────

def _create_test_image(width=400, height=400, mode="RGB"):
    """Create a minimal valid image in memory."""
    from PIL import Image
    img = Image.new(mode, (width, height), color="red")
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


class TestProcessProfilePhoto:

    def test_valid_jpeg(self):
        raw = _create_test_image()
        result_bytes, content_type = process_profile_photo(raw, "image/jpeg")
        assert content_type == "image/jpeg"
        assert len(result_bytes) > 0

    def test_valid_png(self):
        from PIL import Image
        img = Image.new("RGB", (400, 400), "blue")
        buf = io.BytesIO()
        img.save(buf, format="PNG")
        result_bytes, ct = process_profile_photo(buf.getvalue(), "image/png")
        assert ct == "image/jpeg"  # converted to JPEG

    def test_rgba_converted_to_rgb(self):
        from PIL import Image
        img = Image.new("RGBA", (400, 400), (255, 0, 0, 128))
        buf = io.BytesIO()
        img.save(buf, format="PNG")
        result_bytes, ct = process_profile_photo(buf.getvalue(), "image/png")
        assert ct == "image/jpeg"

    def test_rejects_invalid_content_type(self):
        with pytest.raises(ValueError, match="Invalid image type"):
            process_profile_photo(b"data", "application/pdf")

    def test_rejects_invalid_image_data(self):
        with pytest.raises(ValueError, match="not a valid image"):
            process_profile_photo(b"not an image", "image/jpeg")

    def test_rejects_too_small_image(self):
        raw = _create_test_image(width=100, height=100)
        with pytest.raises(ValueError, match="too small"):
            process_profile_photo(raw, "image/jpeg")

    def test_resizes_large_image(self):
        from PIL import Image
        raw = _create_test_image(width=2000, height=2000)
        result_bytes, _ = process_profile_photo(raw, "image/jpeg", max_dimension=800)
        img = Image.open(io.BytesIO(result_bytes))
        assert img.width <= 800
        assert img.height <= 800

    def test_strips_exif(self):
        # Processed image should have no EXIF data
        raw = _create_test_image()
        result_bytes, _ = process_profile_photo(raw, "image/jpeg")
        from PIL import Image
        img = Image.open(io.BytesIO(result_bytes))
        exif = img.getexif()
        assert len(exif) == 0


# ─────────────────────────────────────────────
# UPLOADS
# ─────────────────────────────────────────────

class TestUploadProfilePhoto:

    @pytest.mark.asyncio
    async def test_rejects_too_large(self):
        huge = b"x" * (MAX_PHOTO_SIZE_MB * 1024 * 1024 + 1)
        with pytest.raises(ValueError, match="too large"):
            await upload_profile_photo("user1", huge, "image/jpeg")

    @pytest.mark.asyncio
    async def test_successful_upload_returns_url(self):
        raw = _create_test_image()
        with patch("app.services.storage.get_s3_client") as mock_s3:
            mock_client = MagicMock()
            mock_s3.return_value = mock_client
            with patch("app.services.storage.settings") as mock_settings:
                mock_settings.S3_BUCKET_PROFILES = "test-bucket"
                mock_settings.CLOUDFRONT_URL = "https://cdn.miskmatch.app"
                mock_settings.AWS_REGION = "us-east-1"
                mock_settings.AWS_ACCESS_KEY_ID = "key"
                mock_settings.AWS_SECRET_ACCESS_KEY = "secret"

                url = await upload_profile_photo("user1", raw, "image/jpeg")
                assert url.startswith("https://cdn.miskmatch.app/")
                mock_client.put_object.assert_called_once()

    @pytest.mark.asyncio
    async def test_fallback_s3_url_without_cloudfront(self):
        raw = _create_test_image()
        with patch("app.services.storage.get_s3_client") as mock_s3:
            mock_client = MagicMock()
            mock_s3.return_value = mock_client
            with patch("app.services.storage.settings") as mock_settings:
                mock_settings.S3_BUCKET_PROFILES = "test-bucket"
                mock_settings.CLOUDFRONT_URL = None
                mock_settings.AWS_REGION = "us-east-1"
                mock_settings.AWS_ACCESS_KEY_ID = "key"
                mock_settings.AWS_SECRET_ACCESS_KEY = "secret"

                url = await upload_profile_photo("user1", raw, "image/jpeg")
                assert "s3.us-east-1.amazonaws.com" in url

    @pytest.mark.asyncio
    async def test_s3_error_raises_runtime(self):
        raw = _create_test_image()
        with patch("app.services.storage.get_s3_client") as mock_s3:
            mock_client = MagicMock()
            mock_client.put_object.side_effect = ClientError(
                {"Error": {"Code": "500", "Message": "Internal"}}, "PutObject"
            )
            mock_s3.return_value = mock_client
            with patch("app.services.storage.settings") as mock_settings:
                mock_settings.S3_BUCKET_PROFILES = "test-bucket"
                mock_settings.AWS_REGION = "us-east-1"
                mock_settings.AWS_ACCESS_KEY_ID = "key"
                mock_settings.AWS_SECRET_ACCESS_KEY = "secret"

                with pytest.raises(RuntimeError, match="upload failed"):
                    await upload_profile_photo("user1", raw, "image/jpeg")


class TestUploadVoiceIntro:

    @pytest.mark.asyncio
    async def test_rejects_invalid_audio_type(self):
        with pytest.raises(ValueError, match="Invalid audio format"):
            await upload_voice_intro("user1", b"data", "video/mp4")

    @pytest.mark.asyncio
    async def test_rejects_too_large(self):
        huge = b"x" * (MAX_AUDIO_SIZE_MB * 1024 * 1024 + 1)
        with pytest.raises(ValueError, match="too large"):
            await upload_voice_intro("user1", huge, "audio/mpeg")


class TestUploadQuranRecitation:

    @pytest.mark.asyncio
    async def test_rejects_invalid_audio_type(self):
        with pytest.raises(ValueError, match="Invalid audio format"):
            await upload_quran_recitation("user1", b"data", "text/plain")


# ─────────────────────────────────────────────
# DELETE
# ─────────────────────────────────────────────

class TestDeleteMedia:

    @pytest.mark.asyncio
    async def test_deletes_successfully(self):
        with patch("app.services.storage.get_s3_client") as mock_s3:
            mock_client = MagicMock()
            mock_s3.return_value = mock_client
            await delete_media("profiles/user1/photo.jpg", "test-bucket")
            mock_client.delete_object.assert_called_once()

    @pytest.mark.asyncio
    async def test_handles_error_gracefully(self):
        with patch("app.services.storage.get_s3_client") as mock_s3:
            mock_client = MagicMock()
            mock_client.delete_object.side_effect = ClientError(
                {"Error": {"Code": "404", "Message": "Not Found"}}, "DeleteObject"
            )
            mock_s3.return_value = mock_client
            # Should not raise — logs warning instead
            await delete_media("nonexistent/key.jpg", "test-bucket")


# ─────────────────────────────────────────────
# SIGNED URLS
# ─────────────────────────────────────────────

class TestSignedUrl:

    def test_generates_signed_url(self):
        with patch("app.services.storage.get_s3_client") as mock_s3:
            mock_client = MagicMock()
            mock_client.generate_presigned_url.return_value = "https://signed.url/photo.jpg"
            mock_s3.return_value = mock_client

            url = generate_signed_url("profiles/user1/photo.jpg", "bucket")
            assert url == "https://signed.url/photo.jpg"

    def test_returns_empty_on_error(self):
        with patch("app.services.storage.get_s3_client") as mock_s3:
            mock_client = MagicMock()
            mock_client.generate_presigned_url.side_effect = ClientError(
                {"Error": {"Code": "500", "Message": "err"}}, "GeneratePresignedUrl"
            )
            mock_s3.return_value = mock_client

            url = generate_signed_url("key", "bucket")
            assert url == ""


# ─────────────────────────────────────────────
# URL EXTRACTION
# ─────────────────────────────────────────────

class TestExtractS3Key:

    def test_extracts_from_cloudfront_url(self):
        with patch("app.services.storage.settings") as mock_settings:
            mock_settings.CLOUDFRONT_URL = "https://cdn.miskmatch.app"
            key = extract_s3_key_from_url("https://cdn.miskmatch.app/profiles/u1/photo.jpg")
            assert key == "profiles/u1/photo.jpg"

    def test_extracts_from_s3_url(self):
        with patch("app.services.storage.settings") as mock_settings:
            mock_settings.CLOUDFRONT_URL = None
            key = extract_s3_key_from_url(
                "https://bucket.s3.us-east-1.amazonaws.com/profiles/u1/photo.jpg"
            )
            assert key == "profiles/u1/photo.jpg"

    def test_returns_none_for_empty(self):
        assert extract_s3_key_from_url("") is None
        assert extract_s3_key_from_url(None) is None
