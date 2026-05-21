# Securevaultapi/__init__.py
from Securevaultapi . celery import app as celery_app

__all__ = ('celery_app',)