class marsnat::config (

  $secrets        = '/etc/rsyncd.scr',
  $rsyncdscr      = lookup('rsyncdscr', {
    'default_value' => 'puppet:///modules/dmo_hiera/rsyncd.scr'}),
  $rsyncdconf     = lookup('rsyncdconf', {
    'default_value' => 'puppet:///modules/dmo_hiera/rsyncd.conf'}),
  $rsyncpwd       = lookup('rsyncpwd', {
    'default_value' => 'puppet:///modules/dmo_hiera/rsync.pwd'}),
  $test_user      = lookup('test_user', { 'default_value' => 'vagrant'}),
  $watcher_logging_conf   = lookup('tada_logging_conf', {
    'default_value' => 'puppet:///modules/dmo_hiera/watcher-logging.yaml'}),
  $dqcli_log_conf = lookup('dqcli_logging_conf', {
    'default_value' => 'puppet:///modules/dmo_hiera/dqcli-logging.yaml'}),
  $watch_log_conf = lookup('watch_logging_conf'),
  $dq_conf     = lookup('dq_conf', {
    'default_value' => 'puppet:///modules/dmo_hiera/dq-config.json'}),
  $dq_loglevel    = lookup('dq_loglevel', {'default_value' => 'DEBUG'}),
  $qname          = lookup('qname', {'default_value' => 'ingest'}),

  $inotify_instances  = lookup('inotify_instances', {'default_value' => '512'}),
  $inotify_watches    = lookup('inotify_watches',{'default_value' => '1048576'}),
  ) {
  notice("Loading marsnat::config; rsyncpwd=${rsyncpwd}")
  
  file { [ '/var/run/mars', '/var/log/mars']:
    ensure => 'directory',
    mode   => '0777',
    } ->
  file { [ '/etc/mars', '/var/mars']:
    ensure => 'directory',
    owner  => 'devops',
    group  => 'devops',
    mode   => '0774',
  }
  file { '/var/tada/data':
    ensure => 'directory',
    owner  => 'devops',
    group  => 'devops',
    mode   => '0774',
  }
  file { ['/var/tada/data/cache',
          '/var/tada/data/anticache',
          '/var/tada/data/dropbox',
          '/var/tada/data/nowatch',
          '/var/tada/data/statusbox']:
    ensure => 'directory',
    owner  => 'tada',
    group  => 'tada',
    mode   => '0744',
  }
  file { '/var/tada/cache' :
    ensure  => 'link',
    replace => false,
    target  => '/var/tada/data/cache',
  }
  file { '/var/tada/anticache' :
    ensure  => 'link',
    replace => false,
    target  => '/var/tada/data/anticache',
  }
  file { '/var/tada/dropbox' :
    ensure  => 'link',
    replace => false,
    target  => '/var/tada/data/dropbox',
    owner  => 'tada',
    group  => 'tada',
    mode   => '0744',
  }
  file { '/var/tada/nowatch' :
    ensure  => 'link',
    replace => false,
    target  => '/var/tada/data/nowatch',
  }
  file { '/var/tada/statusbox' :
    ensure  => 'link',
    replace => false,
    target  => '/var/tada/data/statusbox',
  }
  file { '/usr/local':
    ensure => 'directory',
  }
  file { '/usr/local/bin':
    ensure => 'directory',
  }
  file { ['/var/log/mars/pop.log', '/var/log/mars/pop-detail.log']:
    ensure  => 'present',
    replace => false,
    owner   => 'devops',
    group   => 'devops',
    mode    => '0774',
  }
  file { ['/var/log/mars/dqcli.log', '/var/log/mars/dqcli-detail.log']:
    ensure  => 'present',
    replace => false,
    owner   => 'devops',
    group   => 'devops',
    mode    => '0777',
  }
  file {  '/etc/mars/dq-config.json':
    ensure  => 'present',
    replace => true,
    source  => "${dq_conf}",
    group   => 'root',
    mode    => '0774',
  }

  file { '/etc/mars/pop.yaml':
    ensure  => 'present',
    replace => true,
    source  => "${watcher_logging_conf}",
    mode    => '0774',
  }
  file { '/etc/mars/dataq_cli_logconf.yaml':
    ensure  => 'present',
    replace => true,
    source  => "${dqcli_log_conf}",
    mode    => '0774',
  }
  file { '/etc/mars/watch.yaml':
    ensure  => 'present',
    replace => true,
    source  => "${watch_log_conf}",
    mode    => '0774',
  }
  file { '/var/log/mars/submit.manifest':
    ensure  => 'file',
    replace => true,
    owner   => 'devops',
    mode    => '0766',
  }
  file { '/etc/init.d/dqd':
    ensure => 'present',
    replace => true,
    source => 'puppet:///modules/marsnat/dqd',
    owner  => 'devops',
    mode   => '0777',
  }
  file {  '/etc/mars/dqd.conf':
    ensure  => 'present',
    replace => true,
    content => "
qname=${qname}
dqlevel=${dq_loglevel}
",
  }
  file {  '/etc/mars/watchpushd.conf':
    ensure  => 'present',
    replace => true,
    source  => 'puppet:///modules/marsnat/watchpushd.conf',
  }
  file { '/etc/init.d/watchpushd':
    ensure  => 'present',
    replace => true,
    source  => 'puppet:///modules/marsnat/watchpushd',
    owner   => 'devops',
    mode    => '0777',
  }
#!  # Not sure if firewall mods needed for dqsvcpop???
#!  firewall { '000 allow dqsvcpop':
#!    chain   => 'INPUT',
#!    state   => ['NEW'],
#!    dport   => '6379',
#!    proto   => 'tcp',
#!    action  => 'accept',
#!  }

  file_line { 'config_inotify_instances':
    ensure => present,
    path   => '/etc/sysctl.conf',
    match  => '^fs.inotify.max_user_instances\ \=',
    line   => "fs.inotify.max_user_instances = $inotify_instances",
  }
  file_line { 'config_inotify_watches':
    ensure => present,
    path   => '/etc/sysctl.conf',
    match  => '^fs.inotify.max_user_watches\ \=',
    line   => "fs.inotify.max_user_watches = $inotify_watches",
  }


  ##############################################################################
  ### rsync
  ###
  # for testing via dropox.  Lets devops@marsnat be client to dropbox.
  # To allow other user to be client, change owner here or copy file into
  # test user dir and correct owner and permissions for rsync.pwd there.
  # Client will use something like:
  # rsync -az --password-file=~/rsync.pwd ~/dropcache/ tada@marsnat.vagrant.noao.edu::dropbox
  file { '/etc/mars/rsync.pwd':  
    ensure => 'present',
    replace => true,
    source => "${rsyncpwd}",
    mode   => '0400',
    owner  => "${test_user}",
  }
  file {  $secrets:
    ensure  => 'present',
    replace => true,
    source  => "${rsyncdscr}",
    owner   => 'root',
    mode    => '0400',
  }
 file {  '/etc/rsyncd.conf':
    ensure  => 'present',
    replace => true,
    source  => "${rsyncdconf}",
    owner   => 'root',
    mode    => '0400',
  }
  #!class { 'firewall': } ->
  #!firewall { '999 disable firewall':
  #!  ensure => 'stopped',
  #!}
  #!class { selinux:
  #!  mode => 'permissive',
  #!}
#!  class { 'firewall': } ->
#!  firewall { '000 allow rsync':
#!    chain   => 'INPUT',
#!    state   => ['NEW'],
#!    dport   => '873',
#!    proto   => 'tcp',
#!    action  => 'accept',
  #!  }

  file { '/home/tester/.ssh/':
    ensure => 'directory',
    owner  => 'tester',
    mode   => '0700',
  } 
  file { '/home/tester/.ssh/authorized_keys':
    owner  => 'tester',
    mode   => '0600',
  }
  }

