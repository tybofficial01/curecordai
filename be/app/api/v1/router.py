from fastapi import APIRouter

from app.api.v1.ai_chat import router as ai_chat_router
from app.api.v1.alerts import router as alerts_router
from app.api.v1.app_settings import router as settings_router
from app.api.v1.auth import router as auth_router
from app.api.v1.clinical import router as clinical_router
from app.api.v1.consent import router as consent_router
from app.api.v1.contact import router as contact_router
from app.api.v1.emergency import router as emergency_router
from app.api.v1.family import router as family_router
from app.api.v1.insights import router as insights_router
from app.api.v1.medications import router as medications_router
from app.api.v1.profile import router as profile_router
from app.api.v1.records import router as records_router
from app.api.v1.sharing import router as sharing_router
from app.api.v1.users import router as users_router
from app.api.v1.whatsapp import router as whatsapp_router

api_router = APIRouter()

api_router.include_router(auth_router)
api_router.include_router(users_router)
api_router.include_router(profile_router)
api_router.include_router(family_router)
api_router.include_router(records_router)
api_router.include_router(clinical_router)
api_router.include_router(ai_chat_router)
api_router.include_router(insights_router)
api_router.include_router(sharing_router)
api_router.include_router(emergency_router)
api_router.include_router(alerts_router)
api_router.include_router(medications_router)
api_router.include_router(settings_router)
api_router.include_router(consent_router)
api_router.include_router(contact_router)
api_router.include_router(whatsapp_router)
