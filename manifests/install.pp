class marsnat::install (
  $marsnatversion = lookup('marsnatversion'),
  $dqnatversion = lookup('dqnatversion'),
  $personalityversion = lookup('personalityversion'),
  $archive_topdir  = lookup('archive_topdir'),
  $elasticsearch_host = lookup('elasticsearch_host'),
  $localnatica = lookup('localnatica', {
    'default_value' => 'puppet:///modules/dmo_hiera/django_settings_local_natica.py' }),

  $ssl_domain_crt = lookup('ssl_domain_crt'),
  $ssl_domain_key = lookup('ssl_domain_key'),
  $ssl_noirlab_crt = lookup('ssl_noirlab_crt'),
  $ssl_noirlab_key = lookup('ssl_noirlab_key'),
  $noirlab_edu_nginx_config = lookup('noirlab_edu_nginx_conf', {
    'default_value' => 'puppet:///modules/marsnat/nginx/sites-enabled/internal.noirlab'
  }),
  $guconf = lookup('guconf'),

  $fpacktgz    = lookup('fpacktgz', {
    'default_value' => 'puppet:///modules/marsnat/fpack-bin-centos-6.6.tgz'}),
  $rsyncpwd      = lookup('rsyncpwd',  {
    'default_value' => 'puppet:///modules/dmo_hiera/rsync.pwd'}),
  $marsnat_pubkey = lookup('mars_pubkey', {
    'default_value' => 'puppet:///modules/dmo_hiera/spdev1.id_dsa.pub'}),
  $marsnat_privkey = lookup('mars_privkey', {
    'default_value' => 'puppet:///modules/dmo_hiera/spdev1.id_dsa'}),
  $redis_port = lookup('redis_port', {'default_value' => '6379'}),
  $marsnat_replace = lookup('marsnat_replace', {'default_value' => true }),

  ) {
  notify{ 'install versions':
    message => @("EOT")
    Loading marsnat::install.pp
      marsnatversion     = ${marsnatversion}
      dqnatversion       = ${dqnatversion}
      personalityversion = ${personalityversion}
      elasticsearch_host = ${elasticsearch_host}

      archive_topdir     = ${archive_topdir}
      localnatica        = ${localnatica}
    | EOT
  }
  #  notify{"marsnat::install.pp; rsyncpwd=${rsyncpwd}":}

  #include git
  #!include augeas
  ensure_resource('package', ['git', ], {'ensure' => 'present'})
  package{ ['epel-release', 'jemalloc', 'ganglia',
            'nginx', 'supervisor',
            'xinetd'] : }

  group { 'tada':
    ensure => 'present',
  } -> 
  user { 'devops' :
    ensure     => 'present',
    comment    => 'For python virtualenv and running mars.',
    managehome => true,
    # tadapassword/xxxx_||.x.
    password   => '$1$Pk1b6yel$tPE2h9vxYE248CoGKfhR41',  
    system     => true,
    #uid        => 661,  # already taken on marsnat1.pat, causes failures
    groups     => ['tada','cache'],
  } ->
  user { 'tada' :
    ensure     => 'present',
    comment    => 'For dropbox handling',
    managehome => true,
    password   => '$1$Pk1b6yel$tPE2h9vxYE248CoGKfhR41',  # tada"Password"
    system     => true,
    } ->
  user { 'tester' :
    ensure     => 'present',
    comment    => 'For testing NATICA.',
    managehome => true,
    # tadapassword/xxxx_||.x.
    password   => '$1$Pk1b6yel$tPE2h9vxYE248CoGKfhR41',  
    system     => true,
    groups     => 'devops',
  }

  # Install dataq from source in /opt/dqnat
  vcsrepo { '/opt/dqnat' :
    revision => "${dqnatversion}",
    ensure   => 'latest',
    provider => git,
    source   => 'https://github.com/NOAO/dqnat.git',
    owner    => 'devops',
    group    => 'devops',
    require  => User['devops'],
    notify   => Exec['install dataq'],
    } 
  python::requirements  { '/opt/dqnat/requirements.txt':
    virtualenv   => '/opt/mars/venv',
    pip_provider => 'pip3',
    owner        => 'devops',
    group        => 'devops',
    forceupdate  => true,
    require      => [ User['devops'], Vcsrepo['/opt/dqnat']],
  } 

  file { '/etc/mars/dq-mars-install.sh' :
    ensure  => 'file',
    mode    => 'ug=rwx',
    owner        => 'devops',
    group        => 'devops',
    replace => "${marsnat_replace}",
    source  => 'puppet:///modules/marsnat/dq-mars-install.sh',
    notify   => Exec['install dataq'],
  } 
  exec { 'install dataq':
    cwd     => '/opt/dqnat',
    command => "/bin/bash -c  /etc/mars/dq-mars-install.sh",
    refreshonly  => true,
    logoutput    => true,
    notify  => [Service['watchpushd'], Service['dqd'], ],
    subscribe => [
                  Vcsrepo['/opt/dqnat'], 
                  File['/opt/mars/venv',
                       '/etc/mars/dq-mars-install.sh'
                       #'/etc/mars/from-hiera.yaml',
                       ],
      #Python::Requirements['/opt/dqnat/requirements.txt'],
    ],
  }
  file { '/opt/pandoc_install.sh' :
    ensure  => 'file',
    mode    => 'ug=rwx',
    owner        => 'devops',
    group        => 'devops',
    replace => "${marsnat_replace}",
    source  => 'puppet:///modules/marsnat/pandoc_install.sh',
    notify   => Exec['install pandoc'],
  }
  exec { 'install pandoc':
    cwd     => '/opt/',
    command => "/bin/bash -c  /opt/pandoc_install.sh",
    refreshonly  => true,
    logoutput    => true
  }
  file { ['/var/lib/nginx', '/var/lib/nginx/tmp' , '/var/lib/nginx/tmp/client_body', '/var/log/nginx' ] :
    ensure => 'directory',
    owner  => 'nginx',
    group  => 'devops',
    mode   => 'g=rwx',
    }

  class { '::redis':
    protected_mode => 'no',
    #! bind => undef,  # Will cause DEFAULT (127.0.0.1) value to be used
    #! bind => '172.16.1.21', # @@@ mtnnat
    #! bind => '0.0.0.0', # @@@ Listen to ALL interfaces
    #bind => "${ipaddress}", # listen to Local 
    bind => undef,
    } 

  file { '/usr/local/share/applications/fpack.tgz':
    ensure => 'file',
    replace => "${marsnat_replace}",
    source => "$fpacktgz",
    notify => Exec['unpack fpack'],
  } 
  exec { 'unpack fpack':
    command     => '/bin/tar -xf /usr/local/share/applications/fpack.tgz',
    cwd         => '/usr/local/bin',
    refreshonly => true,
  } ->
  file { '/usr/local/bin/fpack' :
    ensure  => 'file',  
    mode    => 'a=rx',
    owner   => 'root',
    group   => 'root',
    replace => true,
    } -> 
  file { '/usr/local/bin/funpack' :
    ensure  => 'file',  
    mode    => 'a=rx',
    owner   => 'root',
    group   => 'root',
    replace => true,
    } 

  file { '/usr/local/bin/fitsverify' :
    ensure  => 'file',
    replace => "${marsnat_replace}",
    source  => 'puppet:///modules/marsnat/fitsverify',
    mode    => 'a=rx',
    owner        => 'root',
    group   => 'root',
  } 
  file { '/usr/local/bin/fitscopy' :
    ensure  => 'file',
    replace => "${marsnat_replace}",
    source  => 'puppet:///modules/marsnat/fitscopy',
    mode    => 'a=rx',
    owner        => 'root',
    group   => 'root',
  }
    
  # just so LOGROTATE doesn't complain if it runs before we rsync
  file { '/var/log/rsyncd.log' :
    ensure  => 'file',
    replace => "${marsnat_replace}",
  }


  file {  '/etc/mars/hiera_settings.yaml': 
    ensure  => 'file',
    replace => "${marsnat_replace}",
    content => "---
# For NATICA from hiera
marsnatversion: '${marsnatversion}'
#archive_topdir: '${archive_topdir}'
redis_port: '${redis_port}'
",
    group   => 'root',
    mode    => '0774',
  }
  
  file { '/etc/mars/django_local_settings.py':
    ensure  => 'file',
    replace => true,
    source  => "${localnatica}",
  } 

  yumrepo { 'ius':
    descr      => 'ius - stable',
    baseurl    => 'http://dl.iuscommunity.org/pub/ius/stable/CentOS/7/x86_64/',
    enabled    => 1,
    gpgcheck   => 0,
    priority   => 1,
    mirrorlist => absent,
  }
  -> Package<| provider == 'yum' |>


  # CONFLICTS with puppet-sdm when using PACKAGE resource Instead:
  #   sudo yum  update -y nss curl libcurl
  #  OR do funny puppet stuff to get around duplicate delcaration
  #   see https://puppet.com/docs/puppet/5.3/lang_resources.html#uniqueness
  #
  # Following will fail unless ALL declarations use ensure_package
  #! ensure_packages(['nss', 'curl', 'libcurl'], {ensure => 'latest'})
  # Following fails with "Could not find declared class package ...
  #! class { 'package':  
  #!   name   => ['nss', 'curl', 'libcurl'],
  #!   ensure => 'latest',
  #!   } ->
  vcsrepo { '/opt/mars' :
    ensure   => latest,
    provider => git,
    source   => 'git@github.com:NOAO/marsnat.git',
    # for https  to work: yum update -y nss curl libcurl
    #source   => 'https://github.com/NOAO/marsnat.git',
    revision => "${marsnatversion}",
    owner    => 'devops',
    group    => 'devops',
    require  => User['devops'],
    #notify   => [Exec['install mars'], Exec['start mars']],
    notify   => [Exec['start mars']],
    } ->
  vcsrepo { '/opt/personality' :
    ensure   => latest,
    provider => git,
    source   => 'https://github.com/NOAO/personality.git',
    revision => "${personalityversion}", 
    owner    => 'devops', 
    group    => 'devops',
    require  => User['devops'],
    notify   => Exec['start mars'],
    } ->
  file { '/opt/mars/marssite/pers' :
    ensure => 'link',
    target => '/opt/personality/pers',
  }
  package{ ['postgresql', 'postgresql-devel', 'expect'] : } ->
  #package{ ['python36u-pip', 'python34-pylint'] : } ->
  package{ ['python36u-pip'] : } ->
    # Will try to install wrong (python3-pip) version of pip under non-SCL.
    # We WANT:
    #   sudo yum -y install python36u-pip
  class { 'python' :
    version    => 'python36u',
    ensure     => 'latest',
    pip        => 'absent', # 'latest' will try to install "python3-pip"
    dev        => 'latest',
    #! virtualenv => 'absent', # 'present', 'latest', 
    gunicorn   => 'absent',
    } ->
  python::pyvenv  { '/opt/mars/venv':
    version  => '3.6',
    owner    => 'devops',
    group    => 'devops',
    require  => [ User['devops'], ],
  } ->
  python::requirements  { '/opt/mars/requirements.txt':
    virtualenv   => '/opt/mars/venv',
    pip_provider => 'pip3',
    owner        => 'devops',
    group        => 'devops',
    forceupdate  => true,
    require      => [ User['devops'], ],
  } -> 
  file { '/etc/mars/search-schema.json':
    replace => "${marsnat_replace}",
    source  => '/opt/mars/marssite/dal/search-schema.json' ,
  }
  file { '/etc/logrotate.d/mars':
    ensure  => 'file',
    replace => "${marsnat_replace}",
    source  => 'puppet:///modules/marsnat/mars.logrotate',
  }
  file { '/etc/logrotate.d/nginx':
    ensure  => 'file',
    replace => "${marsnat_replace}",
    source  => 'puppet:///modules/marsnat/nginx.logrotate',
  }
  file { '/etc/ssl/certs/domain.crt' :
    ensure  => 'file',      
    replace => true,
    source  => "${ssl_domain_crt}",
    }
  file { '/etc/ssl/certs/domain.key' :
    ensure  => 'present',      
    replace => true,
    source  => "${ssl_domain_key}",
    }
  file { '/etc/ssl/certs/ssl-noirlab-edu.crt' :
    ensure  => 'present',
    replace => true,
    source  => "${ssl_noirlab_crt}",
    }
  file { '/etc/ssl/certs/ssl-noirlab-edu.key' :
    ensure  => 'present',
    replace => true,
    source  => "${ssl_noirlab_key}",
    }

  file { [ '/etc/nginx', '/etc/nginx/sites-enabled']:
    ensure => 'directory',
    mode   => '0777',
    } 
  file { '/etc/nginx/sites-enabled/default' :
    ensure  => 'present',      
    replace => true,
    source  => 'puppet:///modules/marsnat/nginx/sites-enabled/default',
    } 
  file { '/etc/nginx/sites-enabled/noirlab' :
    ensure  => 'present',
    replace => true,
    source  => "${noirlab_edu_nginx_conf}",
    }
  file { '/etc/nginx/nginx.conf' :
    ensure  => 'present',      
    replace => true,
    source  => 'puppet:///modules/marsnat/nginx/nginx.conf',
    } 
  file { '/etc/nginx/uwsgi.ini' :
    ensure  => 'present',      
    source  => 'puppet:///modules/marsnat/uwsgi.ini',
    } 
  file { '/etc/nginx/uwsgi_params' :
    ensure  => 'present',      
    source  => 'puppet:///modules/marsnat/uwsgi_params',
  } 
  file { '/etc/supervisord.d' :
    ensure => 'directory',
  }
  file { '/etc/supervisord.d/supervisor-app.conf' :
    ensure  => 'file',
    source  => 'puppet:///modules/marsnat/nginx/supervisor-app.conf',
  }
  file { '/etc/supervisord.conf' :
    ensure  => 'file',
    source  => 'puppet:///modules/marsnat/nginx/supervisord.conf',
  }
  file { '/etc/gunicorn-conf.py' :
    ensure  => 'file',
    source  => "${guconf}" #'puppet:///modules/marsnat/nginx/gunicorn-conf.py',
  }
  # BOUNCE: supervisorctl restart nginx
  # BOUNCE: supervisorctl restart gunicorn
}
