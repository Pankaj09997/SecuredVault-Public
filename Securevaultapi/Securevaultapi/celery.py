# Securevaultapi/celery.py
import os
from celery import Celery

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'Securevaultapi.settings')

app = Celery('Securevaultapi')
app.config_from_object('django.conf:settings', namespace='CELERY')
app.autodiscover_tasks(['api'])  # Discover tasks in the 'api' app

@app.task(bind=True, ignore_result=True)
def debug_task(self):
    print(f'Request: {self.request!r}')