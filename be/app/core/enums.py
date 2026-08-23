"""
Shared enum types used across the API and service layers.

Note: the rest of this codebase deliberately favors plain `String` columns +
Pydantic `Field(pattern=...)` regex validation over Python `Enum` classes (see
AppSettingUpdateRequest's other fields, e.g. `theme`). `Language` is an intentional,
scoped exception to that convention - kept here, in one place, so it stays a
deliberate deviation rather than the start of a drift.
"""
from enum import Enum


class Language(str, Enum):
    """Supported UI/AI-output languages. Exactly these three values are valid."""

    EN = "en"
    UR = "ur"
    ROMAN_UR = "roman_ur"
