class marsnat::service  (
  $djangoserver = hiera('djangoserver', '/opt/mars/start-mars-production.sh'),
  ) {
  notify{ "Loading marsnat::service.pp; ${djangoserver}": } # output to puppet client
  exec { 'collect status':
    command => "/bin/bash -c 'source /opt/mars/venv/bin/activate; /opt/mars/marssite/manage.py collectstatic'",
    creates => '/opt/mars/marssite/audit/static/audit/screen.css',
    subscribe => [
      Vcsrepo['/opt/mars'], 
      File['/opt/mars/venv'],
      Python::Requirements['/opt/mars/requirements.txt'],
      ],
    } 
  exec { 'start mars':
    cwd     => '/opt/mars',
    command => "/bin/bash -c ${djangoserver}",
    unless  => '/usr/bin/pgrep -f "manage.py runserver"',
    user    => 'devops',
    subscribe => [
      Vcsrepo['/opt/mars'], 
      File['/opt/mars/venv', '/etc/mars/hiera_settings.py'],
      Python::Requirements['/opt/mars/requirements.txt'],
      ],
  }
}
