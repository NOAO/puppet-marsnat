class marsnat::install (
  $marsnatversion = lookup('marsnatversion'),
  $rsyncpwd      = lookup('rsyncpwd',  {
    'default_value' => 'puppet:///modules/dmo_hiera/rsync.pwd'}),
  $archive_topdir  = lookup('archive_topdir', {
    'default_value' => '/archive_data'}),
  $hdrfunclibversion = lookup('hdrfunclibversion', {
    'default_value' => 'master'}),
  $marsnat_pubkey = lookup('mars_pubkey', {
    'default_value' => 'puppet:///modules/dmo_hiera/spdev1.id_dsa.pub'}),
  $marsnat_privkey = lookup('mars_privkey', {
    'default_value' => 'puppet:///modules/dmo_hiera/spdev1.id_dsa'}),
  $test_mtn_host= lookup('test_mtn_host'),
  $test_val_host= lookup('test_val_host'),
  #!dq_host: ${lookup('dq_host')}
  #!dq_port: ${lookup('dq_port')}
  #!dq_loglevel: ${lookup('dq_loglevel')}
  #!natica_host: ${lookup('natica_host')}
  #!valley_host: ${lookup('valley_host')}
  #!mars_host: ${lookup('mars_host')}
  #!mars_port: ${lookup('mars_port')}
  #!tadaversion: ${lookup('tadaversion')}
  #!dataqversion: ${lookup('dataqversion')}
  #!marsversion: ${lookup('marsversion')}
  ) {
  notify{"Loading marsnat::install.pp; marsnatversion=${marsnatversion}":}
  notify{"marsnat::install.pp; rsyncpwd=${rsyncpwd}":}

  #include git
  #!include augeas
  ensure_resource('package', ['git', ], {'ensure' => 'present'})
  package{ ['epel-release', 'jemalloc', 'ganglia', 'nginx'] : }

  user { 'devops' :
    ensure     => 'present',
    comment    => 'For python virtualenv and running mars.',
    managehome => true,
    # tadapassword/xxxx_||.x.
    password   => '$1$Pk1b6yel$tPE2h9vxYE248CoGKfhR41',  
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

  file {  '/etc/mars/hiera_settings.yaml': 
    ensure  => 'present',
    replace => true,
    content => "---
# For NATICA from hiera
marsnatversion: '${marsnatversion}'
archive_topdir: '${archive_topdir}'
test_mtn_host: '${test_mtn_host}'
test_val_host: '${test_val_host}'
",
    group   => 'root',
    mode    => '0774',
  }
  
  file { '/etc/mars/django_local_settings.py':
    replace => true,
    source  => lookup('localnatica'),
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

  file { [ '/var/run/mars', '/var/log/mars', '/etc/mars', '/var/mars']:
    ensure => 'directory',
    mode   => '0777',
    } ->
  #! exec { 'allow slow git clone' :
  #!   # lowSpeedLimit is in bytes/seconds
  #!   # lowSpeedTime is in seconds
  #!   command =>  '/usr/bin/git config --system http.lowSpeedLimit 1000; /usr/bin/git config --system http.lowSpeedTime 20'
  #! } ->

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
    #source   => 'git@github.com:NOAO/marsnat.git',
    # for https  to work: yum update -y nss curl libcurl
    source   => 'https://github.com/NOAO/marsnat.git',
    revision => "${marsnatversion}",
    owner    => 'devops',
    group    => 'devops',
    require  => User['devops'],
    notify   => Exec['start mars'],
    } ->
  #!vcsrepo { '/opt/mars/marssite/hdrfunclib' :
  #!  ensure   => latest,
  #!  #!ensure   => bare,
  #!  provider => git,
  #!  source   => 'https://github.com/NOAO/hdrfunclib.git',
  #!  revision => "${hdrfunclibversion}", 
  #!  owner    => 'devops', 
  #!  group    => 'devops',
  #!  require  => User['devops'],
  #!  notify   => Exec['start mars'],
  #!  } ->
  vcsrepo { '/opt/mars/marssite/personality' :
    ensure   => latest,
    #!ensure   => bare,
    provider => git,
    source   => 'https://github.com/NOAO/personality.git',
    revision => "${hdrfunclibversion}", 
    owner    => 'devops', 
    group    => 'devops',
    require  => User['devops'],
    notify   => Exec['start mars'],
    } ->
  package{ ['postgresql', 'postgresql-devel', 'expect'] : } ->
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
#!  file { '/usr/bin/python3':  #@@@ ok to remove???
#!    ensure => 'link',
#!    target => '/usr/bin/python3.6',
#!   } ->
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
    replace => true,
    source  => '/opt/mars/marssite/dal/search-schema.json' ,
  }

  file { '/etc/logrotate.d/mars':
    ensure  => 'present',
    replace => true,
    source  => 'puppet:///modules/marsnat/mars.logrotate',
  }
  
  # Only included to support testing
  file { '/etc/mars/rsync.pwd':
    ensure  => 'present',
    replace => true,
    mode    => '0400',
    source  => "${rsyncpwd}",
  }
  #!file { '/home/vagrant/.ssh/id_dsa.pub':
  #!  replace => true,
  #!  mode    => '0400',
  #!  source  => "${marsnat_pubkey}",
  #!  owner   => "vagrant",
  #!  }
  #!file { '/home/vagrant/.ssh/id_dsa':
  #!  replace => true,
  #!  mode    => '0400',
  #!  source  => "${marsnat_privkey}",
  #!  owner   => "vagrant",
  #!  }

#!  vcsrepo { '/opt/test-fits' :
#!    ensure   => latest,
#!    provider => git,
#!    source   => 'https://bitbucket.org/noao/test-fits.git',
#!    revision => "master",
#!    owner    => 'devops',
#!    group    => 'devops',
#!    require  => User['devops'],
#!    }
  
  file { [ '/etc/nginx', '/etc/nginx/sites-enabled']:
    ensure => 'directory',
    mode   => '0777',
    } ->
  file { '/etc/nginx/sites-enabled/default' :
    ensure  => 'present',      
    source  => 'puppet:///modules/marsnat/nginx-app.conf',
    } ->
  file { '/etc/nginx/nginx.conf' :
    ensure  => 'present',      
    source  => 'puppet:///modules/marsnat/nginx.conf',
    } ->
  file { '/etc/nginx/uwsgi.ini' :
    ensure  => 'present',      
    source  => 'puppet:///modules/marsnat/uwsgi.ini',
    } ->
  file { '/etc/nginx/uwsgi_params' :
    ensure  => 'present',      
    source  => 'puppet:///modules/marsnat/uwsgi_params',
    } 

}
