import os
os.environ['ES_INDEX'] = 'portal'
workers = 4
bind = 'unix:/opt/mars/gunicorn.sock'
daemon = False
disable_redirect_access_to_syslog = True
access_logfile = '/var/log/gunicorn_access.log'
error_logfile = '/var/log/gunicorn_error.log'
log_level = 'info'
timeout = 600

