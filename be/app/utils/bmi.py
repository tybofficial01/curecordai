def calculate_bmi(weight_kg: float | None, height_cm: float | None) -> float | None:
    """BMI = weight(kg) / height(m)^2. None if either measurement is missing."""
    if not weight_kg or not height_cm:
        return None
    return round(weight_kg / ((height_cm / 100) ** 2), 1)
