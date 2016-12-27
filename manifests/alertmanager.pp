# Class: prometheus::alertmanager
#
# This module manages prometheus alertmanager
#
# Parameters:
#  [*arch*]
#  Architecture (amd64 or i386)
#
#  [*bin_dir*]
#  Directory where binaries are located
#
#  [*config_file*]
#  The path to put the configuration file
#
#  [*config_mode*]
#  The permissions of the configuration files
#
#  [*download_extension*]
#  Extension for the release binary archive
#
#  [*download_url*]
#  Complete URL corresponding to the where the release binary archive can be downloaded
#
#  [*download_url_base*]
#  Base URL for the binary archive
#
#  [*extra_groups*]
#  Extra groups to add the binary user to
#
#  [*extra_options*]
#  Extra options added to the startup command
#
#  [*global*]
#  The global alertmanager configuration.
#  Example (also default):
#
#  prometheus::alertmanager::global:
#    smtp_smarthost: 'localhost:25'
#    smtp_from: 'alertmanager@localhost'
#
#  [*group*]
#  Group under which the binary is running
#
#  [*inhibit_rules*]
#  An array of inhibit rules.
#  Example (also default):
#
#  prometheus::alertmanager::inhibit_rules:
#  - source_match:
#      severity: 'critical'
#      target_match:
#        severity: 'warning'
#      equal:
#      - 'alertname'
#      - 'cluster'
#      - 'service'
#
#  [*init_style*]
#  Service startup scripts style (e.g. rc, upstart or systemd)
#
#  [*install_method*]
#  Installation method: url or package (only url is supported currently)
#
#  [*manage_group*]
#  Whether to create a group for or rely on external code for that
#
#  [*manage_service*]
#  Should puppet manage the service? (default true)
#
#  [*manage_user*]
#  Whether to create user or rely on external code for that
#
#  [*os*]
#  Operating system (linux is the only one supported)
#
#  [*package_ensure*]
#  If package, then use this for package ensure default 'latest'
#
#  [*package_name*]
#  The binary package name - not available yet
#
#  [*purge_config_dir*]
#  Purge config files no longer generated by Puppet
#
#  [*receivers*]
#  An array of receivers.
#  Example (also default):
#
#  prometheus::alertmanager::receivers:
#  - name: 'Admin'
#    email_configs:
#      - to: 'root@localhost'
#
#  [*restart_on_change*]
#  Should puppet restart the service on configuration change? (default true)
#
#  [*route*]
#  The top level route.
#  Example (also default):
#
#  prometheus::alertmanager::route:
#    group_by:
#      - 'alertname'
#      - 'cluster'
#      - 'service'
#    group_wait: '30s'
#    group_interval: '5m'
#    repeat_interval: '3h'
#    receiver: 'Admin'
#
#  [*service_enable*]
#  Whether to enable the service from puppet (default true)
#
#  [*service_ensure*]
#  State ensured for the service (default 'running')
#
#  [*storage_path*]
#  The storage path to pass to the alertmanager. Defaults to '/var/lib/alertmanager'
#
#  [*templates*]
#  The array of template files. Defaults to [ "${config_dir}/*.tmpl" ]
#
#  [*user*]
#  User which runs the service
#
#  [*version*]
#  The binary release version
class prometheus::alertmanager (
  $arch                 = $::prometheus::params::arch,
  $bin_dir              = $::prometheus::params::bin_dir,
  $config_dir           = $::prometheus::params::alertmanager_config_dir,
  $config_file          = $::prometheus::params::alertmanager_config_file,
  $config_mode          = $::prometheus::params::config_mode,
  $download_extension   = $::prometheus::params::alertmanager_download_extension,
  $download_url         = undef,
  $download_url_base    = $::prometheus::params::alertmanager_download_url_base,
  $extra_groups         = $::prometheus::params::alertmanager_extra_groups,
  $extra_options        = '',
  $global               = $::prometheus::params::alertmanager_global,
  $group                = $::prometheus::params::alertmanager_group,
  $inhibit_rules        = $::prometheus::params::alertmanager_inhibit_rules,
  $init_style           = $::prometheus::params::init_style,
  $install_method       = $::prometheus::params::install_method,
  $manage_group         = true,
  $manage_service       = true,
  $manage_user          = true,
  $os                   = $::prometheus::params::os,
  $package_ensure       = $::prometheus::params::alertmanager_package_ensure,
  $package_name         = $::prometheus::params::alertmanager_package_name,
  $purge_config_dir     = true,
  $receivers            = $::prometheus::params::alertmanager_receivers,
  $restart_on_change    = true,
  $route                = $::prometheus::params::alertmanager_route,
  $service_enable       = true,
  $service_ensure       = 'running',
  $storage_path         = $::prometheus::params::alertmanager_storage_path,
  $templates            = $::prometheus::params::alertmanager_templates,
  $user                 = $::prometheus::params::alertmanager_user,
  $version              = $::prometheus::params::alertmanager_version,
) inherits prometheus::params {
  if( versioncmp($::prometheus::alertmanager::version, '0.3.0') == -1 ){
    $real_download_url    = pick($download_url,
      "${download_url_base}/download/${version}/${package_name}-${version}.${os}-${arch}.${download_extension}")
  } else {
    $real_download_url    = pick($download_url,
      "${download_url_base}/download/v${version}/${package_name}-${version}.${os}-${arch}.${download_extension}")
  }
  validate_bool($purge_config_dir)
  validate_bool($manage_user)
  validate_bool($manage_service)
  validate_bool($restart_on_change)
  validate_array($templates)
  validate_array($receivers)
  validate_array($inhibit_rules)
  validate_hash($global)
  validate_hash($route)
  $notify_service = $restart_on_change ? {
    true    => Service['alertmanager'],
    default => undef,
  }

  file { $config_dir:
    ensure  => 'directory',
    owner   => $user,
    group   => $group,
    purge   => $purge_config_dir,
    recurse => $purge_config_dir,
  }

  file { $config_file:
    ensure  => present,
    owner   => $user,
    group   => $group,
    mode    => $config_mode,
    content => template('prometheus/alertmanager.yaml.erb'),
    require => File[$config_dir],
  }

  # This is here to stop the previous alertmanager that was installed in version 0.1.14
  service { 'alert_manager':
    ensure => 'stopped',
  }

  if $storage_path {
    file { $storage_path:
      ensure => 'directory',
      owner  => $user,
      group  =>  $group,
      mode   => '0755',
    }

    $options = "-config.file=${prometheus::alertmanager::config_file} -storage.path=${prometheus::alertmanager::storage_path} ${prometheus::alertmanager::extra_options}"
  } else {
    $options = "-config.file=${prometheus::alertmanager::config_file} ${prometheus::alertmanager::extra_options}"
  }

  prometheus::daemon { 'alertmanager':
    install_method     => $install_method,
    version            => $version,
    download_extension => $download_extension,
    os                 => $os,
    arch               => $arch,
    real_download_url  => $real_download_url,
    bin_dir            => $bin_dir,
    notify_service     => $notify_service,
    package_name       => $package_name,
    package_ensure     => $package_ensure,
    manage_user        => $manage_user,
    user               => $user,
    extra_groups       => $extra_groups,
    group              => $group,
    manage_group       => $manage_group,
    purge              => $purge_config_dir,
    options            => $options,
    init_style         => $init_style,
    service_ensure     => $service_ensure,
    service_enable     => $service_enable,
    manage_service     => $manage_service,
  }
}