#!/usr/bin/env python

from celery import Celery

app = Celery(backend='amqp', broker='amqp://')
app.conf.update(
    CELERY_TASK_SERIALIZER='json',
    CELERY_RESULT_SERIALIZER='json',
)


@app.task(serializer='json')
def add(x,y):
    return x + y
