"""
Pure schedule computation for medication reminders. A reminder stores its dosing times as
wall-clock HH:MM strings in an IANA timezone (not UTC instants) so a recurring 8am dose stays
at 8am local time across DST transitions - every occurrence is resolved to a UTC instant here,
on demand, rather than being precomputed and stored.
"""
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

import structlog

logger = structlog.get_logger()


def safe_zoneinfo(tz_name: str) -> ZoneInfo:
    try:
        return ZoneInfo(tz_name)
    except (ZoneInfoNotFoundError, ValueError):
        logger.warning("Unknown reminder timezone - falling back to UTC", tz_name=tz_name)
        return ZoneInfo("UTC")


def _is_dose_day(reminder, day: date) -> bool:
    if reminder.frequency_type == "as_needed":
        return False
    if reminder.frequency_type == "daily":
        return True
    if reminder.frequency_type == "specific_days":
        weekday = day.weekday()  # 0=Mon .. 6=Sun, matches our stored convention
        return bool(reminder.days_of_week) and weekday in reminder.days_of_week
    if reminder.frequency_type == "interval":
        step = reminder.interval_days or 1
        return (day - reminder.start_date).days % step == 0
    return False


def occurrences_between(reminder, window_start_utc: datetime, window_end_utc: datetime) -> list[datetime]:
    """
    Returns every scheduled dose instant (UTC, tz-aware) for `reminder` that falls within
    [window_start_utc, window_end_utc). Iterates local calendar days covering the UTC window
    (with a 1-day pad on each side to catch instants that shift across the UTC boundary) so
    callers never need to reason about the reminder's own timezone.
    """
    tz = safe_zoneinfo(reminder.timezone)
    local_start_day = (window_start_utc.astimezone(tz) - timedelta(days=1)).date()
    local_end_day = (window_end_utc.astimezone(tz) + timedelta(days=1)).date()

    results: list[datetime] = []
    day = max(local_start_day, reminder.start_date)
    last_day = local_end_day if reminder.end_date is None else min(local_end_day, reminder.end_date)

    while day <= last_day:
        if _is_dose_day(reminder, day):
            for time_str in reminder.times_of_day:
                hour, minute = (int(p) for p in time_str.split(":"))
                local_dt = datetime(day.year, day.month, day.day, hour, minute, tzinfo=tz)
                instant = local_dt.astimezone(ZoneInfo("UTC"))
                if window_start_utc <= instant < window_end_utc:
                    results.append(instant)
        day += timedelta(days=1)

    results.sort()
    return results
