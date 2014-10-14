Celery Erlang Client
====================
This is an Erlang library for interfacing with `Celery <http://www.celeryproject.org/>`_ workers using the AMQP Broker.

Build
-----
Run make from the root folder to build the library and its dependencies.

::

    $ make

Usage
-----
Check out demo.erl which sends tasks to a local RabbitMQ instance.

Start the Celery workers:

::

    $ celery worker --app tasks --loglevel info

Run the application and send requests:

::

    $ ./start.sh

    Eshell V5.9.3.1  (abort with ^G)
    1> c(demo).
    {ok, demo}
    2> demo:add(5,5).
    {celery_res,<<"celery_rpc_1cd61e09ea5c49149e2f6b792f71a5fd">>,<<"SUCCESS">>,10,null}

Troubleshooting
---------------

Celery Versions
~~~~~~~~~~~~~~~
Different versions of Celery define the result queues in different ways. If you get an a timeout in your Erlang application and an error in your celery logs which looks likes this:

::

    PreconditionFailed: Queue.declare: (406) PRECONDITION_FAILED - parameters for queue '<task_name>' in vhost '<vhost_name>' not equivalent

then it is likely that the reply queue is been declared by Celery with a different durable flag than the one specified by your application.

reply_queue_durable can be set by adding the erl command line flag like so:

::

    -celery reply_queue_durable false

**OR**

by puttting a configuration file in place called myconf.config with the following content:

::

    [{celery, [{reply_queue_durable, false}]}].

and modifying start.sh to specify that config by adding the following erl command line option:

::

    -config local


License
_______
Licensed under `MPL 1.1 <http://www.mozilla.org/MPL/1.1/>`_.

**N.B.**: This code base has been forked from https://code.google.com/p/celery-erlang-client/
