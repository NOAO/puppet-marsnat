class marsnat::install (
  $naticaversion = hiera('marsnatversion', 'master'),
  $rsyncpwd      = hiera('rsyncpwd',  'puppet:///modules/dmo-hiera/rsync.pwd'),
  $archive_topdir      = hiera('archive_topdir'),
  $marsnat_pubkey = hiera('mars_pubkey', 'puppet:///modules/dmo-hiera/spdev1.id_dsa.pub'),
  $marsnat_privkey = hiera('mars_privkey', 'puppet:///modules/dmo-hiera/spdev1.id_dsa'),
  ) {
  notify{"Loading marsnat::install.pp; naticaversion=${naticaversion}":}
  notify{"marsnat::install.pp; rsyncpwd=${rsyncpwd}":}

  #include git
  include augeas
 ensure_resource('package', ['git', ], {'ensure' => 'present'})

  user { 'devops' :
    ensure     => 'present',
    comment    => 'For python virtualenv and running mars.',
    managehome => true,
    password   => '$1$Pk1b6yel$tPE2h9vxYE248CoGKfhR41',  # tada"Password"
    system     => true,
  }

#!dq_host: ${hiera('dq_host')}
#!dq_port: ${hiera('dq_port')}
#!dq_loglevel: ${hiera('dq_loglevel')}
#!natica_host: ${hiera('natica_host')}
#!valley_host: ${hiera('valley_host')}
#!mars_host: ${hiera('mars_host')}
#!mars_port: ${hiera('mars_port')}
#!tadaversion: ${hiera('tadaversion')}
#!dataqversion: ${hiera('dataqversion')}
#!marsversion: ${hiera('marsversion')}
  file {  '/etc/mars/hiera_settings.py': 
    ensure  => 'present',
    replace => true,
    content => "# For NATICA from hiera
naticaversion = '${naticaversion}'
archive_topdir = '${archive_topdir}'
",
    group   => 'root',
    mode    => '0774',
  }
  
  file { '/etc/mars/django_local_settings.py':
    replace => true,
    source  => hiera('localnatica'),
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

  # CONFLICTS with puppet-sdm.  Instead:
  #   sudo yum -y update nss curl libcurl
  #!package{ ['nss', 'curl', 'libcurl'] :
  #!    ensure => 'latest',
  #!  } ->
  vcsrepo { '/opt/mars' :
    ensure   => latest,
    provider => git,
    #source   => 'git@github.com:NOAO/marsnat.git',
    # for https  to work: yum update -y nss curl libcurl
    source   => 'https://github.com/NOAO/marsnat.git',
    revision => "${naticaversion}",
    owner    => 'devops',
    group    => 'devops',
    require  => User['devops'],
    notify   => Exec['start mars'],
    } ->
  package{ ['postgresql', 'postgresql-devel', 'expect'] : } ->
  class { 'python' :
    version    => 'python36u',
    pip        => 'present',
    dev        => 'present',
    virtualenv => 'absent',  # 'present',
    gunicorn   => 'absent',
    } ->
  file { '/usr/bin/python3':
    ensure => 'link',
    target => '/usr/bin/python3.6',
    } ->
  python::pyvenv  { '/opt/mars/venv':
    version  => '3.6',
    owner    => 'devops',
    group    => 'devops',
    require  => [ User['devops'], ],
  } ->
  python::requirements  { '/opt/mars/requirements.txt':
    virtualenv => '/opt/mars/venv',
    owner    => 'devops',
    group    => 'devops',
    require  => [ User['devops'], ],
  } -> 
  file { '/etc/mars/search-schema.json':
    replace => true,
    source  => '/opt/mars/marssite/dal/search-schema.json' ,
  }

  # Only included to support testing
  file { '/etc/mars/rsync.pwd':
    ensure  => 'present',
    replace => true,
    mode    => '0400',
    source  => "${rsyncpwd}",
  }
  file { '/home/vagrant/.ssh/id_dsa.pub':
    replace => true,
    mode    => '0400',
    source  => "${marsnat_pubkey}",
    owner   => "vagrant",
    }
  file { '/home/vagrant/.ssh/id_dsa':
    replace => true,
    mode    => '0400',
    source  => "${marsnat_privkey}",
    owner   => "vagrant",
    }



  
}
