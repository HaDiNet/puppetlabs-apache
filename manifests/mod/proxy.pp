# @summary
#   Installs and configures `mod_proxy`.
#
# @param proxy_requests
#   Enables forward (standard) proxy requests.
#
# @param allow_from
#   List of IPs allowed to access proxy.
#
# @param package_name
#   Name of the proxy package to install.
#
# @param proxy_via
#   Set local IP address for outgoing proxy connections.
#
# @param proxy_timeout
#   Network timeout for proxied requests.
#
# @param proxy_iobuffersize
#   Set the size of internal data throughput buffer
#
# @see https://httpd.apache.org/docs/current/mod/mod_proxy.html for additional documentation.
#
class apache::mod::proxy (
  String $proxy_requests                    = 'Off',
  Optional[Stdlib::IP::Address] $allow_from = undef,
  Optional[String] $package_name            = undef,
  String $proxy_via                         = 'On',
  Optional[Integer[0]] $proxy_timeout       = undef,
  Optional[String] $proxy_iobuffersize      = undef,
) {
  include apache
  $_proxy_timeout = $apache::timeout
  ::apache::mod { 'proxy':
    package => $package_name,
  }
  # Template uses $proxy_requests
  file { 'proxy.conf':
    ensure  => file,
    path    => "${apache::mod_dir}/proxy.conf",
    mode    => $apache::file_mode,
    content => template('apache/mod/proxy.conf.erb'),
    require => Exec["mkdir ${apache::mod_dir}"],
    before  => File[$apache::mod_dir],
    notify  => Class['apache::service'],
  }
}
