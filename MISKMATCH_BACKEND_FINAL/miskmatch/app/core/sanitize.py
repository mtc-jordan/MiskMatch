"""
MiskMatch — Input Sanitization
Strips HTML tags and dangerous patterns from user-generated text.
"""

import re
from markupsafe import escape


# Matches any HTML tag (opening, closing, self-closing)
_HTML_TAG_RE = re.compile(r"<[^>]+>")

# Matches common XSS patterns: javascript:, data:, on* event handlers
_XSS_PATTERNS_RE = re.compile(
    r"(javascript\s*:|data\s*:|vbscript\s*:|on\w+\s*=)",
    re.IGNORECASE,
)


def sanitize_text(value: str) -> str:
    """
    Sanitize user-generated text:
    1. Strip all HTML tags
    2. Remove XSS patterns (javascript:, onerror=, etc.)
    3. Collapse excessive whitespace
    4. Preserves Arabic/Unicode text safely
    """
    if not value:
        return value

    # Strip HTML tags
    cleaned = _HTML_TAG_RE.sub("", value)

    # Remove dangerous URL schemes and event handlers
    cleaned = _XSS_PATTERNS_RE.sub("", cleaned)

    # Collapse multiple spaces (but keep newlines)
    cleaned = re.sub(r"[^\S\n]+", " ", cleaned)

    # Strip leading/trailing whitespace per line
    cleaned = "\n".join(line.strip() for line in cleaned.splitlines())

    return cleaned.strip()


def sanitize_dict_values(d: dict) -> dict:
    """Recursively sanitize all string values in a dict."""
    if not isinstance(d, dict):
        return d
    result = {}
    for k, v in d.items():
        if isinstance(v, str):
            result[k] = sanitize_text(v)
        elif isinstance(v, dict):
            result[k] = sanitize_dict_values(v)
        elif isinstance(v, list):
            result[k] = [
                sanitize_text(item) if isinstance(item, str) else item
                for item in v
            ]
        else:
            result[k] = v
    return result
