class marsnat::service  (
  $djangoserver = lookup('djangoserver',  {
    'default_value' => '/opt/mars/start-mars-production.sh'}),
  ) {
  notify{'service':
    message => @("EOT")
    Loading marsnat::service.pp
      djangoserver=${djangoserver}
    | EOT
  }

  #./manage.py collectstatic --noinput 
  exec { 'collect static':
    command => "/bin/bash -c 'source /opt/mars/venv/bin/activate; /opt/mars/marssite/manage.py collectstatic --noinput'",
    #creates => '/opt/mars/marssite/audit/static/audit/screen.css',
    refreshonly => true,
    cwd       => '/opt/mars/marssite',
    subscribe => [
      Vcsrepo['/opt/mars'],
      Exec[ 'start mars'],
      File['/opt/mars/venv'],
      Python::Requirements['/opt/mars/requirements.txt'],
      ],
    } 
  #!class { 'firewall': } ->
  #!firewall { 'disable firewall':
  #!  ensure => 'stopped',
  #!}
  #!class { selinux:
  #!  mode => 'permissive',
    #!}
  file { '/etc/patch.sh':
    replace => true,
    source  => lookup('patch_marsnat', {
      'default_value' => 'puppet:///modules/marsnat/patch.sh'}),
    mode    => 'a=rx',
    } ->
  file { '/etc/patch-for-testing.sh':
    replace => true,
    source  => 'puppet:///modules/dmo_hiera/patch-for-testing.sh',
    mode    => 'a=rx',
    } ->
#!  exec { 'patch mars':
#!    command => "/etc/patch.sh > /etc/patch.log",
#!    creates => "/etc/patch.log",
#!    } ->

  exec { 'start mars':
    cwd     => '/opt/mars',
    command => "/bin/bash -c ${djangoserver}",
    unless  => '/usr/bin/pgrep -f "manage.py runserver"',
    user    => 'devops',
    subscribe => [
      Vcsrepo['/opt/mars'], 
      File['/opt/mars/venv', '/etc/mars/hiera_settings.yaml'],
      Python::Requirements['/opt/mars/requirements.txt'],
      ],
  } ->
  exec { 'bounce gunicorn':
    command => '/bin/bash -c supervisorctl restart gunicorn',
    refreshonly => true,
    }

  exec { 'start nginx':
    command => '/bin/bash -c supervisord -c /etc/supervisord.conf',
    unless => ['/usr/bin/test -f /run/supervisord.pid'],
  }


  # For exec, use something like:
    #   unless  => '/usr/bin/pgrep -f "manage.py runserver"',
    # to prevent running duplicate.  Puppet is supposed to check process table
    # so duplicate should never happen UNLESS done manually.
  service {'dqd':
    ensure   => 'running',
    subscribe => [File[#'/etc/mars/dqd.conf',
                       #'/etc/mars/from-hiera.yaml',
                       #'/etc/mars/tada.conf',
                       '/etc/init.d/dqd',
                       ],
                  Class['redis'],
                  #Python::Requirements[ '/opt/dqnat/requirements.txt'],
                  Exec['install dataq'],
                  ],
    enable   => true,
    provider => 'redhat',
    path     => '/etc/init.d',
  }
  # WATCH only needed for MOUNTAIN (so far)
  service { 'watchpushd':
    ensure    => 'running',
    subscribe => [File['/etc/mars/watchpushd.conf',
                       '/etc/init.d/watchpushd'
                       ],
                  #Python::Requirements['/opt/dqnat/requirements.txt'],
                  Exec['install dataq'],
                  ],
    enable    => true,
    provider  => 'redhat',
    path      => '/etc/init.d',
  }
  
  service { 'xinetd':
    ensure  => 'running',
    enable  => true,
    require => Package['xinetd'],
    }
  exec { 'bootrsyncd':
    command   => '/bin/systemctl enable rsyncd',
    creates   => '/etc/systemd/system/multi-user.target.wants/rsyncd.service',
  }
  exec { 'rsyncd':
    command   => '/bin/systemctl start rsyncd',
    subscribe => File['/etc/rsyncd.conf'],
    unless    => '/bin/systemctl status rsyncd.service | grep "Active: active"',
  }

}

