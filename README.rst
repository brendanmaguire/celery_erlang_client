Celery Erlang Client
====================
This is an Erlang library for interfacing with `Celery <http://www.celeryproject.org/>`_ workers using the AMQP Broker.

Build
-----
``` make ```

Usage
-----
Check out demo.erl

::
    $ erl

    Eshell V5.9.3.1  (abort with ^G)
    1>  c(demo).
    {ok,demo}
    2> demo:start_celery_app().
    ok
    3> demo:add(5,5).
    {celery_res,<<"celery_rpc_1cd61e09ea5c49149e2f6b792f71a5fd">>,<<"SUCCESS">>,10,null}

License
_______
Licensed under `MPL 1.1 <http://www.mozilla.org/MPL/1.1/>`_.

**N.B.**: This code base has been forked from https://code.google.com/p/celery-erlang-client/
