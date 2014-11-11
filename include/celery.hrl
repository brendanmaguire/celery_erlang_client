
-record(celery_msg, {
    id      = null,
    task    = null,
    args    = [],
    kwargs  = [{}],
    retries = 0,
    eta     = null
}).

-record(celery_res, {
    task_id   = <<>> :: binary(),
    status    = <<>> :: binary(),
    result    = <<>> :: binary() | null,
    traceback = <<>> :: binary() | null
}).
