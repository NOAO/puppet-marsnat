users="nobody nginx" # devops nfs www-data
media_dir="/tmp" # /mars/marssite/static
static_dir="/tmp" # /mars/marssite/static
download_zip_dir="/tmp"
download_archive_dir="/tmp" # nfs mount path i.e. /net/archive/mtn
django_root_dir="/django/" # /mars/marssite

export users media_dir static_dir download_zip_dir download_archive_dir django_root_dir

#!yum install -y epel-release   # PUPPET
#!yum install -y nginx          # PUPPET

# this is for substituting the vars
yum install -y gettext

cd nginx-config

#! mkdir /etc/nginx/sites-enabled
#! envsubst < nginx-app.conf > /etc/nginx/sites-enabled/default
#! envsubst < nginx.conf > /etc/nginx/nginx.conf
#! envsubst < uwsgi.ini > /etc/nginx/uwsgi.ini
#! cp uwsgi_params /etc/nginx/

cp __dm_noao_edu.crt /etc/ssl/certs/
cp star-dm-noao-edu.key /etc/ssl/certs/


