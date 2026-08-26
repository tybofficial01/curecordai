"""
Smallest possible check on the disclaimer logic shared by the webapp streaming chat endpoint
and the WhatsApp agent reply (app.services.chat_context.compute_disclaimer) - both now call
this one function, so a regression here would silently affect both channels at once.
"""
from app.services.chat_context import compute_disclaimer
from app.services.openrouter import AI_DISCLAIMER, AI_DISCLAIMER_UR


def test_compute_disclaimer_english():
    is_urdu, disclaimer = compute_disclaimer("Take two tablets daily with water.")
    assert is_urdu is False
    assert disclaimer == AI_DISCLAIMER


def test_compute_disclaimer_urdu_script():
    is_urdu, disclaimer = compute_disclaimer("دن میں دو گولیاں پانی کے ساتھ لیں۔")
    assert is_urdu is True
    assert disclaimer == AI_DISCLAIMER_UR
