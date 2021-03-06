# == Class: zuul
#
class zuul (
  $jenkins_server = '',
  $jenkins_user = '',
  $jenkins_apikey = '',
  $gerrit_server = '',
  $gerrit_user = '',
  $url_pattern = '',
  $status_url = "https://${::fqdn}/zuul/status",
  $git_source_repo = 'https://github.com/openstack-ci/zuul.git',
  $push_change_refs = false
) {
  $packages = [
    'python-webob',
    'python-daemon',
    'python-lockfile',
    'python-paste',
  ]

  package { $packages:
    ensure => present,
  }

  # A lot of things need yaml, be conservative requiring this package to avoid
  # conflicts with other modules.
  if ! defined(Package['python-yaml']) {
    package { 'python-yaml':
      ensure => present,
    }
  }

  if ! defined(Package['python-paramiko']) {
    package { 'python-paramiko':
      ensure   => present,
    }
  }

  # Packages that need to be installed from pip
  $pip_packages = [
    'GitPython',
    'extras'
  ]

  package { $pip_packages:
    ensure   => latest,  # we want the latest from these
    provider => pip,
    require  => Class['pip'],
  }

  vcsrepo { '/opt/zuul':
    ensure   => latest,
    provider => git,
    revision => 'master',
    source   => $git_source_repo,
  }

  exec { 'install_zuul' :
    command     => 'python setup.py install',
    cwd         => '/opt/zuul',
    path        => '/bin:/usr/bin',
    refreshonly => true,
    subscribe   => Vcsrepo['/opt/zuul'],
  }

  file { '/etc/zuul':
    ensure => directory,
  }

# TODO: We should put in  notify either Service['zuul'] or Exec['zuul-reload']
#       at some point, but that still has some problems.
  file { '/etc/zuul/zuul.conf':
    ensure  => present,
    owner   => 'jenkins',
    mode    => '0400',
    content => template('zuul/zuul.conf.erb'),
    require => [
      File['/etc/zuul'],
      Package['jenkins'],
    ],
  }

  file { '/var/log/zuul':
    ensure  => directory,
    owner   => 'jenkins',
    require => Package['jenkins'],
  }

  file { '/var/run/zuul':
    ensure  => directory,
    owner   => 'jenkins',
    require => Package['jenkins'],
  }

  file { '/var/lib/zuul':
    ensure  => directory,
    owner   => 'jenkins',
    require => Package['jenkins'],
  }

  file { '/var/lib/zuul/git':
    ensure  => directory,
    owner   => 'jenkins',
    require => Package['jenkins'],
  }

  file { '/etc/init.d/zuul/':
    ensure => present,
    owner  => 'root',
    group  => 'root',
    mode   => '0555',
    source => 'puppet:///modules/zuul/zuul.init',
  }

  exec { 'zuul-reload':
    command     => '/etc/init.d/zuul reload',
    require     => File['/etc/init.d/zuul'],
    refreshonly => true,
  }

  service { 'zuul':
    name       => 'zuul',
    enable     => true,
    hasrestart => true,
    require    => File['/etc/init.d/zuul'],
  }
}
