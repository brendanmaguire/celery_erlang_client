#!/bin/sh

erl -pa ebin/ -pa deps/*/ebin/ -sname celery_rpc_client@localhost -s celery_app
