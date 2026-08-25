"""Shared HTML email layout + per-email templates.

All emails render through `render_email()` so every message the app sends
shares one brand-consistent, table-based layout that renders correctly
across major email clients (Outlook, Gmail, Apple Mail).
"""

import html
from datetime import datetime, timezone

from app.config import settings
from app.core.enums import Language

# lang/dir attributes per language, for render_email()'s <html> tag.
_HTML_LANG_DIR: dict[Language, tuple[str, str]] = {
    Language.EN: ("en", "ltr"),
    Language.UR: ("ur", "rtl"),
    Language.ROMAN_UR: ("ur-Latn", "ltr"),
}

BRAND_NAME = settings.SES_FROM_NAME or "CurecordAI"
BRAND_COLOR = "#0f9b8e"
BRAND_COLOR_DARK = "#0b6d63"
TEXT_COLOR = "#1f2937"
MUTED_COLOR = "#6b7280"
BORDER_COLOR = "#e5e7eb"
BG_COLOR = "#f4f6f7"
LOGO_URL = f"{settings.WEB_APP_BASE_URL.rstrip('/')}/logo.png"

FONT_STACK = (
    "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif"
)


# Boilerplate that every email carries regardless of which template produced it.
_LAYOUT_TEXT: dict[Language, dict[str, str]] = {
    Language.EN: {
        "automated_note": (
            "This is an automated message from {brand}. Please do not reply directly to this email."
        ),
        "rights_reserved": "All rights reserved.",
    },
    Language.UR: {
        "automated_note": (
            "یہ {brand} کی طرف سے ایک خودکار پیغام ہے۔ براہِ کرم اس ای میل کا براہِ راست جواب نہ دیں۔"
        ),
        "rights_reserved": "جملہ حقوق محفوظ ہیں۔",
    },
    Language.ROMAN_UR: {
        "automated_note": (
            "Yeh {brand} ki taraf se ek automated message hai. Baraye meherbani is email ka "
            "direct jawab na dein."
        ),
        "rights_reserved": "Tamam huqooq mehfooz hain.",
    },
}


def render_email(
    *, preheader: str, heading: str, body_html: str, footer_note: str = "", language: Language = Language.EN
) -> str:
    """Wrap `body_html` in the shared branded layout. `body_html` must already be escaped/safe.

    `language` sets the document's `lang`/`dir` attributes and localizes the shared
    footer boilerplate; it does not translate the caller's content - callers pass
    already-localized `heading`/`body_html`/`footer_note`.
    """
    year = datetime.now(timezone.utc).year
    footer_note_html = f'<p style="margin:8px 0 0;">{footer_note}</p>' if footer_note else ""
    lang_attr, dir_attr = _HTML_LANG_DIR[language]
    layout = _LAYOUT_TEXT[language]
    automated_note = layout["automated_note"].format(brand=html.escape(BRAND_NAME))
    rights_reserved = layout["rights_reserved"]

    return f"""\
<!DOCTYPE html>
<html lang="{lang_attr}" dir="{dir_attr}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{html.escape(heading)}</title>
</head>
<body style="margin:0; padding:0; background-color:{BG_COLOR}; font-family:{FONT_STACK};">
  <div style="display:none; max-height:0; overflow:hidden; opacity:0; font-size:1px; line-height:1px; color:{BG_COLOR};">
    {html.escape(preheader)}
  </div>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:{BG_COLOR}; padding:24px 0;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px; background-color:#ffffff; border-radius:12px; overflow:hidden; border:1px solid {BORDER_COLOR};">
          <tr>
            <td style="background-color:{BRAND_COLOR_DARK}; padding:24px 32px;">
              <img src="{LOGO_URL}" alt="{html.escape(BRAND_NAME)}" height="28" style="display:block; height:28px; width:auto; border:0;">
            </td>
          </tr>
          <tr>
            <td style="padding:36px 32px 8px;">
              <h1 style="margin:0 0 16px; font-size:20px; line-height:1.3; color:{TEXT_COLOR};">{html.escape(heading)}</h1>
              <div style="font-size:15px; line-height:1.6; color:{TEXT_COLOR};">
                {body_html}
              </div>
            </td>
          </tr>
          <tr>
            <td style="padding:24px 32px 32px;">
              <hr style="border:none; border-top:1px solid {BORDER_COLOR}; margin:0 0 20px;">
              <p style="margin:0; font-size:12px; line-height:1.6; color:{MUTED_COLOR};">
                {automated_note}
                {footer_note_html}
              </p>
            </td>
          </tr>
        </table>
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;">
          <tr>
            <td style="padding:20px 32px; text-align:center; font-size:12px; color:{MUTED_COLOR};">
              &copy; {year} {html.escape(BRAND_NAME)}. {rights_reserved}
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
"""


def _otp_badge(otp: str) -> str:
    return f"""\
<div style="margin:20px 0; text-align:center;">
  <span style="display:inline-block; padding:14px 28px; background-color:{BG_COLOR}; border:1px solid {BORDER_COLOR}; border-radius:8px; font-size:28px; font-weight:700; letter-spacing:6px; color:{BRAND_COLOR_DARK};">
    {html.escape(otp)}
  </span>
</div>"""


_OTP_EMAIL_TEXT: dict[Language, dict[str, str]] = {
    Language.EN: {
        "subject": "Your {brand} verification code",
        "heading": "Verify your identity",
        "intro": "Use the code below to {purpose}:",
        "expiry": "This code expires in <strong>{minutes} minutes</strong>.",
        "ignore": "If you didn't request this code, you can safely ignore this email.",
        "footer_note": "Never share this code - our team will never ask you for it.",
        "preheader": "Your verification code is {otp}",
        "plain": (
            "Your {brand} verification code is: {otp}\n\n"
            "Use this code to {purpose}. It expires in {minutes} minutes.\n"
            "Do not share this code with anyone."
        ),
    },
    Language.UR: {
        "subject": "آپ کا {brand} تصدیقی کوڈ",
        "heading": "اپنی شناخت کی تصدیق کریں",
        "intro": "{purpose} کے لیے نیچے دیا گیا کوڈ استعمال کریں:",
        "expiry": "یہ کوڈ <strong>{minutes} منٹ</strong> میں ختم ہو جائے گا۔",
        "ignore": "اگر آپ نے یہ کوڈ درخواست نہیں کیا تو آپ اس ای میل کو نظر انداز کر سکتے ہیں۔",
        "footer_note": "یہ کوڈ کسی سے شیئر نہ کریں - ہماری ٹیم کبھی بھی آپ سے یہ نہیں مانگے گی۔",
        "preheader": "آپ کا تصدیقی کوڈ ہے {otp}",
        "plain": (
            "آپ کا {brand} تصدیقی کوڈ ہے: {otp}\n\n"
            "{purpose} کے لیے یہ کوڈ استعمال کریں۔ یہ {minutes} منٹ میں ختم ہو جائے گا۔\n"
            "یہ کوڈ کسی سے شیئر نہ کریں۔"
        ),
    },
    Language.ROMAN_UR: {
        "subject": "Aap ka {brand} verification code",
        "heading": "Apni identity verify karein",
        "intro": "{purpose} ke liye neeche diya gaya code istemal karein:",
        "expiry": "Yeh code <strong>{minutes} minute</strong> mein expire ho jayega.",
        "ignore": "Agar aap ne yeh code request nahi kiya to aap is email ko ignore kar sakte hain.",
        "footer_note": "Yeh code kisi ke saath share na karein - hamari team kabhi bhi yeh nahi mangegi.",
        "preheader": "Aap ka verification code hai {otp}",
        "plain": (
            "Aap ka {brand} verification code hai: {otp}\n\n"
            "{purpose} ke liye yeh code istemal karein. Yeh {minutes} minute mein expire ho jayega.\n"
            "Yeh code kisi ke saath share na karein."
        ),
    },
}


# The reason an OTP was issued, as a stable key the callers pass instead of an English
# phrase - the phrase itself has to change per language to fit each sentence's grammar.
OTP_PURPOSE_VERIFY_EMAIL = "verify_email"
OTP_PURPOSE_RESET_PASSWORD = "reset_password"

_OTP_PURPOSE_TEXT: dict[Language, dict[str, str]] = {
    Language.EN: {
        OTP_PURPOSE_VERIFY_EMAIL: "verify your email address",
        OTP_PURPOSE_RESET_PASSWORD: "reset your password",
    },
    Language.UR: {
        OTP_PURPOSE_VERIFY_EMAIL: "اپنے ای میل ایڈریس کی تصدیق کرنے",
        OTP_PURPOSE_RESET_PASSWORD: "اپنا پاس ورڈ دوبارہ ترتیب دینے",
    },
    Language.ROMAN_UR: {
        OTP_PURPOSE_VERIFY_EMAIL: "apna email address verify karne",
        OTP_PURPOSE_RESET_PASSWORD: "apna password reset karne",
    },
}


def otp_email(
    otp: str,
    expire_minutes: int,
    purpose: str = OTP_PURPOSE_VERIFY_EMAIL,
    language: Language = Language.EN,
) -> tuple[str, str, str]:
    """Returns (subject, plain_text_body, html_body) for an OTP email, in `language`.

    `purpose` is one of the OTP_PURPOSE_* keys; an unknown key falls back to
    "verify email" rather than leaking a raw key into the message body. The OTP
    itself is never translated.
    """
    text = _OTP_EMAIL_TEXT[language]
    purposes = _OTP_PURPOSE_TEXT[language]
    purpose_text = purposes.get(purpose, purposes[OTP_PURPOSE_VERIFY_EMAIL])
    purpose_safe = html.escape(purpose_text)
    subject = text["subject"].format(brand=BRAND_NAME)

    plain = text["plain"].format(
        brand=BRAND_NAME, otp=otp, purpose=purpose_text, minutes=expire_minutes
    )

    body_html = f"""\
<p style="margin:0 0 4px;">{text["intro"].format(purpose=purpose_safe)}</p>
{_otp_badge(otp)}
<p style="margin:0;">{text["expiry"].format(minutes=expire_minutes)}</p>
<p style="margin:16px 0 0; color:{MUTED_COLOR};">{text["ignore"]}</p>"""

    html_body = render_email(
        preheader=text["preheader"].format(otp=otp),
        heading=text["heading"],
        body_html=body_html,
        footer_note=text["footer_note"],
        language=language,
    )
    return subject, plain, html_body


_MEDICATION_REMINDER_TEXT: dict[Language, dict[str, str]] = {
    Language.EN: {
        # Used when the reminder is for the account owner themselves rather than a
        # named family member - family member names are never translated.
        "self_label": "you",
        "subject": "Medication reminder: {medication} at {time}",
        "heading": "Medication reminder",
        "intro": "It's time for <strong>{recipient}</strong> to take:",
        "scheduled_for": "Scheduled for {time}",
        "cta": "Open {brand}",
        "note": "Mark this dose as taken or manage medication reminders anytime in the app.",
        "preheader": "Time for {recipient} to take {dose}",
        "plain": (
            "It's time for {recipient} to take {dose}, scheduled for {time}.\n\n"
            "Open {brand} to mark this dose as taken or to manage medication reminders."
        ),
    },
    Language.UR: {
        "self_label": "آپ",
        "subject": "دوا کی یاد دہانی: {medication} - {time}",
        "heading": "دوا کی یاد دہانی",
        "intro": "<strong>{recipient}</strong> کے لیے یہ دوا لینے کا وقت ہو گیا ہے:",
        "scheduled_for": "مقررہ وقت: {time}",
        "cta": "{brand} کھولیں",
        "note": "ایپ میں کسی بھی وقت اس خوراک کو لی گئی کے طور پر نشان زد کریں یا دوا کی یاد دہانیاں ترتیب دیں۔",
        "preheader": "{recipient} کے لیے {dose} لینے کا وقت",
        "plain": (
            "{recipient} کے لیے {dose} لینے کا وقت ہو گیا ہے، مقررہ وقت {time}۔\n\n"
            "اس خوراک کو لی گئی کے طور پر نشان زد کرنے یا دوا کی یاد دہانیاں ترتیب دینے کے لیے {brand} کھولیں۔"
        ),
    },
    Language.ROMAN_UR: {
        "self_label": "aap",
        "subject": "Dawa ki reminder: {medication} - {time}",
        "heading": "Dawa ki reminder",
        "intro": "<strong>{recipient}</strong> ke liye yeh dawa lene ka waqt ho gaya hai:",
        "scheduled_for": "Muqarrara waqt: {time}",
        "cta": "{brand} kholein",
        "note": "App mein kisi bhi waqt is dose ko li gayi mark karein ya dawa ki reminders manage karein.",
        "preheader": "{recipient} ke liye {dose} lene ka waqt",
        "plain": (
            "{recipient} ke liye {dose} lene ka waqt ho gaya hai, muqarrara waqt {time}.\n\n"
            "Is dose ko li gayi mark karne ya dawa ki reminders manage karne ke liye {brand} kholein."
        ),
    },
}


def medication_reminder_email(
    recipient_label: str | None,
    medication_name: str,
    dosage: str | None,
    scheduled_local_time: str,
    language: Language = Language.EN,
) -> tuple[str, str, str]:
    """Returns (subject, plain_text_body, html_body) for a medication reminder email, in `language`.

    `recipient_label` is a family member's name, or None when the dose is the account
    owner's own - only the None case gets a localized stand-in ("you"/"آپ"/"aap"); a real
    name is never translated, and neither are the medication name or dosage.
    """
    text = _MEDICATION_REMINDER_TEXT[language]
    recipient = recipient_label or text["self_label"]
    dose_desc = f"{medication_name} ({dosage})" if dosage else medication_name
    subject = text["subject"].format(medication=medication_name, time=scheduled_local_time)

    plain = text["plain"].format(
        recipient=recipient, dose=dose_desc, time=scheduled_local_time, brand=BRAND_NAME
    )

    recipient_safe = html.escape(recipient)
    dose_safe = html.escape(dose_desc)
    time_safe = html.escape(scheduled_local_time)

    body_html = f"""\
<p style="margin:0 0 16px;">{text["intro"].format(recipient=recipient_safe)}</p>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:{BG_COLOR}; border:1px solid {BORDER_COLOR}; border-radius:8px; margin:0 0 16px;">
  <tr>
    <td style="padding:16px 20px;">
      <p style="margin:0; font-size:16px; font-weight:700; color:{TEXT_COLOR};">{dose_safe}</p>
      <p style="margin:4px 0 0; font-size:14px; color:{MUTED_COLOR};">{text["scheduled_for"].format(time=time_safe)}</p>
    </td>
  </tr>
</table>
<p style="margin:0;">
  <a href="{html.escape(settings.WEB_APP_BASE_URL)}" style="display:inline-block; padding:12px 24px; background-color:{BRAND_COLOR}; color:#ffffff; text-decoration:none; border-radius:8px; font-weight:600;">
    {text["cta"].format(brand=html.escape(BRAND_NAME))}
  </a>
</p>
<p style="margin:16px 0 0; color:{MUTED_COLOR};">{text["note"]}</p>"""

    html_body = render_email(
        preheader=text["preheader"].format(recipient=recipient, dose=dose_desc),
        heading=text["heading"],
        body_html=body_html,
        language=language,
    )
    return subject, plain, html_body


def contact_form_forward_email(name: str, email: str, message_body: str) -> tuple[str, str, str]:
    """Returns (subject, plain_text_body, html_body) for an internal contact-form forward.

    Deliberately English-only and NOT language-parameterized: the sole recipient is
    settings.CONTACT_INBOX_EMAIL (the internal support inbox), never the person who
    submitted the form, so the submitter's language preference is irrelevant here.
    The submitter's own name/email/message are passed through verbatim.
    """
    subject = f"{BRAND_NAME} contact form - {name}"
    plain = f"From: {name} <{email}>\n\n{message_body}"

    name_safe = html.escape(name)
    email_safe = html.escape(email)
    message_safe = html.escape(message_body).replace("\n", "<br>")

    body_html = f"""\
<p style="margin:0 0 16px;">New contact form submission:</p>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 16px;">
  <tr><td style="padding:4px 0; font-size:13px; color:{MUTED_COLOR}; width:80px;">From</td><td style="padding:4px 0; font-size:14px;">{name_safe} &lt;{email_safe}&gt;</td></tr>
</table>
<div style="padding:16px 20px; background-color:{BG_COLOR}; border:1px solid {BORDER_COLOR}; border-radius:8px; font-size:14px; line-height:1.6;">
  {message_safe}
</div>"""

    html_body = render_email(
        preheader=f"New contact form message from {name}",
        heading="New contact form submission",
        body_html=body_html,
        language=Language.EN,
    )
    return subject, plain, html_body
