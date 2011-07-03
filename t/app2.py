def application(environ, start_response):
    start_response('200 OK', [("X-Script-Name", environ["SCRIPT_NAME"])])
    return ["OK\n"]
