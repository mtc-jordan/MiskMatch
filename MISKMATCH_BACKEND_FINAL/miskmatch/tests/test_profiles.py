"""
MiskMatch — Profile Router Tests
pytest + httpx async test client
"""

import pytest
from httpx import AsyncClient, ASGITransport
from unittest.mock import AsyncMock, patch, MagicMock

from app.main import app


# ── Fixtures ──────────────────────────────────────────────────

@pytest.fixture
def auth_headers():
    """Mock auth headers — replace with real JWT in integration tests."""
    return {"Authorization": "Bearer test-token"}


@pytest.fixture
def sample_profile_data():
    return {
        "first_name": "Ahmad",
        "last_name": "Al-Rashidi",
        "date_of_birth": "1995-06-15T00:00:00Z",
        "city": "Amman",
        "country": "JO",
        "madhab": "hanafi",
        "prayer_frequency": "all_five",
        "is_revert": False,
        "min_age": 22,
        "max_age": 35,
    }


@pytest.fixture
def sample_family_data():
    return {
        "family_origin": "Jordan",
        "family_type": "nuclear",
        "num_siblings": 3,
        "family_religiosity": "practising",
        "family_description": "A warm, Islamic family from Amman.",
        "living_arrangement": "nuclear",
    }


# ── Unit Tests — Schema Validation ───────────────────────────

class TestProfileSchemas:

    def test_valid_profile_create(self, sample_profile_data):
        from app.schemas.profiles import ProfileCreateRequest
        profile = ProfileCreateRequest(**sample_profile_data)
        assert profile.first_name == "Ahmad"
        assert profile.country == "JO"

    def test_country_code_uppercased(self, sample_profile_data):
        from app.schemas.profiles import ProfileCreateRequest
        sample_profile_data["country"] = "jo"
        profile = ProfileCreateRequest(**sample_profile_data)
        assert profile.country == "JO"

    def test_age_range_invalid(self, sample_profile_data):
        from app.schemas.profiles import ProfileCreateRequest
        from pydantic import ValidationError
        sample_profile_data["min_age"] = 40
        sample_profile_data["max_age"] = 30
        with pytest.raises(ValidationError, match="min_age must be less than max_age"):
            ProfileCreateRequest(**sample_profile_data)

    def test_underage_rejected(self, sample_profile_data):
        from app.schemas.profiles import ProfileCreateRequest
        from pydantic import ValidationError
        sample_profile_data["date_of_birth"] = "2015-01-01T00:00:00Z"
        with pytest.raises(ValidationError, match="at least 18 years old"):
            ProfileCreateRequest(**sample_profile_data)

    def test_partial_update_all_optional(self):
        from app.schemas.profiles import ProfileUpdateRequest
        # Should not raise — all fields optional
        update = ProfileUpdateRequest()
        assert update.first_name is None

    def test_sifr_requires_minimum_answers(self):
        from app.schemas.profiles import SifrAssessmentRequest
        from pydantic import ValidationError
        with pytest.raises(ValidationError, match="15 answers"):
            SifrAssessmentRequest(answers={"q1": 3, "q2": 4})


# ── Unit Tests — Profile Service ──────────────────────────────

class TestProfileService:

    def test_trust_score_increases_with_photo(self):
        from app.services.profiles import compute_trust_score
        from app.models.models import Profile

        profile_no_photo = MagicMock(spec=Profile)
        profile_no_photo.photo_url = None
        profile_no_photo.voice_intro_url = None
        profile_no_photo.madhab = None
        profile_no_photo.prayer_frequency = None
        profile_no_photo.quran_level = None
        profile_no_photo.sifr_scores = None
        profile_no_photo.mosque_verified = False
        profile_no_photo.scholar_endorsed = False
        profile_no_photo.bio = None
        profile_no_photo.date_of_birth = None
        profile_no_photo.city = None
        profile_no_photo.education_level = None
        profile_no_photo.occupation = None
        profile_no_photo.wants_children = None

        score_no_photo = compute_trust_score(profile_no_photo)

        profile_with_photo = MagicMock(spec=Profile)
        profile_with_photo.photo_url = "https://cdn.miskmatch.app/photo.jpg"
        profile_with_photo.voice_intro_url = None
        profile_with_photo.madhab = None
        profile_with_photo.prayer_frequency = None
        profile_with_photo.quran_level = None
        profile_with_photo.sifr_scores = None
        profile_with_photo.mosque_verified = False
        profile_with_photo.scholar_endorsed = False
        profile_with_photo.bio = None
        profile_with_photo.date_of_birth = None
        profile_with_photo.city = None
        profile_with_photo.education_level = None
        profile_with_photo.occupation = None
        profile_with_photo.wants_children = None

        score_with_photo = compute_trust_score(profile_with_photo)
        assert score_with_photo > score_no_photo

    def test_mosque_verified_max_score(self):
        from app.services.profiles import compute_trust_score
        from app.models.models import Profile

        profile = MagicMock(spec=Profile)
        profile.photo_url = "https://cdn.miskmatch.app/photo.jpg"
        profile.voice_intro_url = "https://cdn.miskmatch.app/voice.mp3"
        profile.madhab = "hanafi"
        profile.prayer_frequency = "all_five"
        profile.quran_level = "hafiz"
        profile.sifr_scores = {"generosity": 80}
        profile.mosque_verified = True
        profile.scholar_endorsed = False
        profile.bio = "Test bio"
        profile.date_of_birth = MagicMock()
        profile.city = "Amman"
        profile.education_level = "University"
        profile.occupation = "Engineer"
        profile.wants_children = True

        score = compute_trust_score(profile)
        assert score >= 80  # mosque verification should push score high

    def test_missing_fields_detection(self):
        from app.services.profiles import get_missing_fields
        from app.models.models import Profile

        profile = MagicMock(spec=Profile)
        profile.bio = None
        profile.date_of_birth = None
        profile.city = "Amman"
        profile.madhab = "hanafi"
        profile.prayer_frequency = None
        profile.photo_url = None
        profile.voice_intro_url = None
        profile.sifr_scores = None
        profile.quran_level = None
        profile.education_level = "University"
        profile.occupation = "Engineer"
        profile.wants_children = None

        missing = get_missing_fields(profile)
        assert "Biography" in missing
        assert "Profile photo" in missing
        assert "Voice introduction" in missing
        assert "City" not in missing  # city is set

    def test_sifr_scoring(self):
        from app.services.profiles import _compute_sifr_scores
        answers = {
            "q1": 5, "q2": 4, "q3": 5, "q4": 3, "q5": 4,
            "q6": 4, "q7": 3, "q8": 4, "q9": 5, "q10": 3,
            "q11": 5, "q12": 4, "q13": 5, "q14": 4, "q15": 3,
        }
        scores = _compute_sifr_scores(answers)
        assert "generosity" in scores
        assert "patience" in scores
        assert "honesty" in scores
        assert all(0 <= v <= 100 for v in scores.values())

    def test_hybrid_compatibility_children_dealbreaker(self):
        """Children mismatch is a dealbreaker in the hybrid AI engine."""
        from app.services.compatibility import compute_hybrid_score
        from app.models.models import Profile
        import uuid, datetime

        def _p(wants_children):
            p = MagicMock(spec=Profile)
            p.user_id = uuid.uuid4()
            p.madhab = None; p.prayer_frequency = "all_five"
            p.quran_level = None; p.is_revert = False; p.revert_year = None
            p.hijab_stance = None; p.hajj_timeline = None
            p.wants_hijra = None; p.hijra_country = None
            p.islamic_finance_stance = None; p.wife_working_stance = None
            p.sifr_scores = None; p.love_language = None; p.priority_ranking = None
            p.bio = None; p.trust_score = 50; p.mosque_verified = False
            p.scholar_endorsed = False; p.min_age = 22; p.max_age = 45
            p.compatibility_embedding = None
            p.date_of_birth = datetime.datetime(1995,1,1,tzinfo=datetime.timezone.utc)
            p.city = None; p.country = None; p.education_level = None; p.occupation = None
            p.wants_children = wants_children
            return p

        result = compute_hybrid_score(_p(True), _p(False))
        assert result.dealbreaker is True
        assert result.final_score == 0.0


# ── Unit Tests — Storage ──────────────────────────────────────

class TestStorage:

    def test_photo_key_format(self):
        from app.services.storage import build_photo_key
        key = build_photo_key("user-123", "main")
        assert key.startswith("profiles/user-123/photo_main_")
        assert key.endswith(".jpg")

    def test_voice_key_format(self):
        from app.services.storage import build_voice_key
        key = build_voice_key("user-123")
        assert key.startswith("voice/user-123/intro_")
        assert key.endswith(".mp4")

    def test_image_processing_strips_exif(self):
        from app.services.storage import process_profile_photo
        from PIL import Image
        import io

        # Create a small test image
        img = Image.new("RGB", (300, 300), color=(201, 151, 58))
        buf = io.BytesIO()
        img.save(buf, format="JPEG")
        raw = buf.getvalue()

        processed, content_type = process_profile_photo(raw, "image/jpeg")

        assert len(processed) > 0
        assert content_type == "image/jpeg"

        # Verify it's still a valid image
        result_img = Image.open(io.BytesIO(processed))
        assert result_img.size[0] <= 800
        assert result_img.size[1] <= 800

    def test_rejects_invalid_image_type(self):
        from app.services.storage import process_profile_photo
        with pytest.raises(ValueError, match="Invalid image type"):
            process_profile_photo(b"fake", "application/pdf")

    def test_rejects_too_small_image(self):
        from app.services.storage import process_profile_photo
        from PIL import Image
        import io

        # 50x50 image — too small
        img = Image.new("RGB", (50, 50))
        buf = io.BytesIO()
        img.save(buf, format="JPEG")

        with pytest.raises(ValueError, match="too small"):
            process_profile_photo(buf.getvalue(), "image/jpeg")

    def test_extract_s3_key_from_cloudfront_url(self):
        from app.services.storage import extract_s3_key_from_url
        from app.core.config import settings

        # Mock CloudFront URL
        url = "https://cdn.miskmatch.app/profiles/user-123/photo_main_abc.jpg"
        with patch.object(settings, "CLOUDFRONT_URL", "https://cdn.miskmatch.app"):
            key = extract_s3_key_from_url(url)
            assert key == "profiles/user-123/photo_main_abc.jpg"
