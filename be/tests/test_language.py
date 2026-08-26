"""
Real, minimal tests for the multi-language (en / ur / roman_ur) backend slice.

Deliberately scoped to pure-Python / Pydantic-validation checks that need no database -
see conftest.py for the DB/client fixtures available to future endpoint-level tests.
"""
import asyncio
import inspect
import json
import re
from pathlib import Path

import pytest
from pydantic import ValidationError

from app.api.v1.app_settings import AppSettingUpdateRequest
from app.core.enums import Language
from app.core.errors import ApiError, ErrorCode, api_error_handler
from app.services import auth_service
from app.services.email_templates import (
    _HTML_LANG_DIR,
    _LAYOUT_TEXT,
    OTP_PURPOSE_RESET_PASSWORD,
    OTP_PURPOSE_VERIFY_EMAIL,
    contact_form_forward_email,
    medication_reminder_email,
    otp_email,
    render_email,
)
from app.services.prompts import language_instruction
from app.services.twilio_service import _OTP_SMS_BODIES
from scripts.check_translations import main as check_translations_main

_ARABIC_SCRIPT_RE = re.compile(r"[؀-ۿ]")


def test_language_enum_has_exactly_three_expected_values():
    values = {member.value for member in Language}
    assert values == {"en", "ur", "roman_ur"}


@pytest.mark.parametrize("value", ["en", "ur", "roman_ur"])
def test_app_setting_update_request_accepts_valid_languages(value):
    req = AppSettingUpdateRequest(language=value)
    assert req.language == Language(value)


@pytest.mark.parametrize("value", ["ar", "fr", "EN", "", "urdu", "roman-ur"])
def test_app_setting_update_request_rejects_invalid_languages(value):
    with pytest.raises(ValidationError):
        AppSettingUpdateRequest(language=value)


def test_language_instructions_are_non_empty_and_distinct():
    instructions = {lang: language_instruction(lang) for lang in Language}
    assert all(isinstance(text, str) and text.strip() for text in instructions.values())
    assert len(set(instructions.values())) == len(instructions)


def test_roman_ur_instruction_has_no_urdu_script_but_ur_does():
    roman_ur_instruction = language_instruction(Language.ROMAN_UR)
    ur_instruction = language_instruction(Language.UR)

    assert not _ARABIC_SCRIPT_RE.search(roman_ur_instruction)
    assert _ARABIC_SCRIPT_RE.search(ur_instruction)


# ── Localized notification templates (email + SMS) ──────────────────────────────

@pytest.mark.parametrize("language", list(Language))
def test_otp_email_localized_and_preserves_the_code_verbatim(language):
    subject, plain, html_body = otp_email("482913", 5, language=language)

    assert subject.strip() and plain.strip() and html_body.strip()
    # The code, and only the code, must survive translation untouched.
    assert "482913" in subject or "482913" in plain
    assert "482913" in plain and "482913" in html_body
    assert "5" in plain


@pytest.mark.parametrize("language", list(Language))
def test_otp_email_purposes_differ_and_never_leak_the_raw_purpose_key(language):
    _, verify_plain, _ = otp_email("111111", 5, OTP_PURPOSE_VERIFY_EMAIL, language)
    _, reset_plain, _ = otp_email("111111", 5, OTP_PURPOSE_RESET_PASSWORD, language)

    assert verify_plain != reset_plain
    for body in (verify_plain, reset_plain):
        assert OTP_PURPOSE_VERIFY_EMAIL not in body
        assert OTP_PURPOSE_RESET_PASSWORD not in body


def test_otp_email_unknown_purpose_key_falls_back_instead_of_leaking_it():
    _, plain, _ = otp_email("111111", 5, "not_a_real_purpose", Language.EN)
    assert "not_a_real_purpose" not in plain
    assert "verify your email address" in plain


@pytest.mark.parametrize("language", list(Language))
def test_medication_reminder_email_preserves_untranslatable_data(language):
    subject, plain, html_body = medication_reminder_email(
        "Ayesha Khan", "Metformin", "500mg", "08:00 AM PKT", language=language
    )

    for text in (subject, plain, html_body):
        assert text.strip()
    for token in ("Metformin", "08:00 AM PKT"):
        assert token in subject or token in plain
        assert token in plain and token in html_body
    assert "500mg" in plain
    # A family member's real name is never translated.
    assert "Ayesha Khan" in plain and "Ayesha Khan" in html_body


@pytest.mark.parametrize("language", list(Language))
def test_medication_reminder_email_uses_a_localized_self_label(language):
    _, plain, _ = medication_reminder_email(
        None, "Metformin", None, "08:00 AM PKT", language=language
    )
    assert plain.strip()
    assert "None" not in plain


@pytest.mark.parametrize(
    "render",
    [
        lambda lang: otp_email("482913", 5, language=lang)[1],
        lambda lang: medication_reminder_email(
            "Ali", "Metformin", "500mg", "08:00 AM", language=lang
        )[1],
    ],
)
def test_templates_use_urdu_script_only_for_ur(render):
    assert _ARABIC_SCRIPT_RE.search(render(Language.UR))
    assert not _ARABIC_SCRIPT_RE.search(render(Language.ROMAN_UR))
    assert not _ARABIC_SCRIPT_RE.search(render(Language.EN))


@pytest.mark.parametrize("language", list(Language))
def test_render_email_sets_lang_dir_and_localizes_shared_footer(language):
    html_body = render_email(
        preheader="p", heading="h", body_html="<p>b</p>", language=language
    )
    expected_lang, expected_dir = _HTML_LANG_DIR[language]
    assert f'lang="{expected_lang}"' in html_body
    assert f'dir="{expected_dir}"' in html_body
    assert _LAYOUT_TEXT[language]["rights_reserved"] in html_body


@pytest.mark.parametrize("language", list(Language))
def test_otp_sms_body_localized_and_preserves_the_code(language):
    body = _OTP_SMS_BODIES[language].format(otp="482913", minutes=5)
    assert body.strip()
    assert "482913" in body
    assert ("5" in body)


def test_contact_form_forward_email_is_deliberately_english_only():
    # Internal support-inbox forward - not a recipient-facing message, so it takes
    # no language parameter. Guards against someone "helpfully" localizing it.
    assert "language" not in inspect.signature(contact_form_forward_email).parameters


# ── Language-dict consistency script ───────────────────────────────────────────

def test_check_translations_script_passes():
    assert check_translations_main() == 0


# ── Client-mappable error codes ────────────────────────────────────────────────

def test_api_error_response_keeps_detail_string_and_adds_error_code():
    exc = ApiError(status_code=400, detail="Invalid OTP", error_code=ErrorCode.OTP_INVALID)
    response = asyncio.run(api_error_handler(None, exc))

    payload = json.loads(response.body)
    assert response.status_code == 400
    # `detail` must stay exactly the plain string existing clients already read.
    assert payload["detail"] == "Invalid OTP"
    assert payload["error_code"] == "otp_invalid"


def test_error_codes_are_unique_and_snake_case():
    codes = [
        value
        for name, value in vars(ErrorCode).items()
        if not name.startswith("_") and isinstance(value, str)
    ]
    assert codes
    assert len(codes) == len(set(codes))
    assert all(re.fullmatch(r"[a-z][a-z0-9_]*", code) for code in codes)


def test_auth_service_raises_no_plain_httpexception_with_leaked_exception_text():
    source = Path(auth_service.__file__).read_text(encoding="utf-8")
    # Every client-facing auth error carries an error_code, and none echo str(exc).
    assert "raise HTTPException(" not in source
    assert "detail=str(exc)" not in source
    assert "detail=f\"Invalid Google token" not in source
    assert "detail=f\"Invalid Apple token" not in source
