# @summary
#   Installs packages for an Apache module that doesn't have a corresponding 
#   `apache::mod::<MODULE NAME>` class.
#
# Checks for or places the module's default configuration files in the Apache server's 
# `module` and `enable` directories. The default locations depend on your operating system.
#
# @param package
#   **Required**.<br />
#   Names the package Puppet uses to install the Apache module.
#
# @param package_ensure
#   Determines whether Puppet ensures the Apache module should be installed.
#
# @param lib
#   Defines the module's shared object name. Do not configure manually without special reason.
#
# @param lib_path
#   Specifies a path to the module's libraries. Do not manually set this parameter 
#   without special reason. The `path` parameter overrides this value.
#
# @param loadfile_name
#   Sets the filename for the module's `LoadFile` directive, which can also set 
#   the module load order as Apache processes them in alphanumeric order.
#
# @param id
#   Specifies the package id
#
# @param loadfiles
#   Specifies an array of `LoadFile` directives.
#
# @param path
#   Specifies a path to the module. Do not manually set this parameter without a special reason.
#
define apache::mod (
  Optional[String] $package       = undef,
  String $package_ensure          = 'present',
  Optional[String] $lib           = undef,
  String $lib_path                = $apache::lib_path,
  Optional[String] $id            = undef,
  Optional[String] $path          = undef,
  Optional[String] $loadfile_name = undef,
  Optional[Array] $loadfiles      = undef,
) {
  if ! defined(Class['apache']) {
    fail('You must include the apache base class before using any apache defined resources')
  }

  $mod = $name
  #include apache #This creates duplicate resources in rspec-puppet
  $mod_dir = $apache::mod_dir

  # Determine if we have special lib
  $mod_libs = $apache::mod_libs
  if $lib {
    $_lib = $lib
  } elsif has_key($mod_libs, $mod) { # 2.6 compatibility hack
    $_lib = $mod_libs[$mod]
  } else {
    $_lib = "mod_${mod}.so"
  }

  # Determine if declaration specified a path to the module
  if $path {
    $_path = $path
  } else {
    $_path = "${lib_path}/${_lib}"
  }

  if $id {
    $_id = $id
  } else {
    $_id = "${mod}_module"
  }

  if $loadfile_name {
    $_loadfile_name = $loadfile_name
  } else {
    $_loadfile_name = "${mod}.load"
  }

  # Determine if we have a package
  $mod_packages = $apache::mod_packages
  if $package {
    $_package = $package
  } elsif has_key($mod_packages, $mod) { # 2.6 compatibility hack
    $_package = $mod_packages[$mod]
  } else {
    $_package = undef
  }
  if $_package and ! defined(Package[$_package]) {
    # note: FreeBSD/ports uses apxs tool to activate modules; apxs clutters
    # httpd.conf with 'LoadModule' directives; here, by proper resource
    # ordering, we ensure that our version of httpd.conf is reverted after
    # the module gets installed.
    $package_before = $facts['os']['family'] ? {
      'freebsd' => [
        File[$_loadfile_name],
        File["${apache::conf_dir}/${apache::params::conf_file}"]
      ],
      default => [
        File[$_loadfile_name],
        File[$apache::confd_dir],
      ],
    }
    # if there are any packages, they should be installed before the associated conf file
    Package[$_package] -> File<| title == "${mod}.conf" |>
    # $_package may be an array
    package { $_package:
      ensure  => $package_ensure,
      require => Package['httpd'],
      before  => $package_before,
      notify  => Class['apache::service'],
    }
  }

  file { $_loadfile_name:
    ensure  => file,
    path    => "${mod_dir}/${_loadfile_name}",
    owner   => 'root',
    group   => $apache::params::root_group,
    mode    => $apache::file_mode,
    content => template('apache/mod/load.erb'),
    require => [
      Package['httpd'],
      Exec["mkdir ${mod_dir}"],
    ],
    before  => File[$mod_dir],
    notify  => Class['apache::service'],
  }

  if $facts['os']['family'] == 'Debian' {
    $enable_dir = $apache::mod_enable_dir
    file { "${_loadfile_name} symlink":
      ensure  => link,
      path    => "${enable_dir}/${_loadfile_name}",
      target  => "${mod_dir}/${_loadfile_name}",
      owner   => 'root',
      group   => $apache::params::root_group,
      mode    => $apache::file_mode,
      require => [
        File[$_loadfile_name],
        Exec["mkdir ${enable_dir}"],
      ],
      before  => File[$enable_dir],
      notify  => Class['apache::service'],
    }
    # Each module may have a .conf file as well, which should be
    # defined in the class apache::mod::module
    # Some modules do not require this file.
    if defined(File["${mod}.conf"]) {
      file { "${mod}.conf symlink":
        ensure  => link,
        path    => "${enable_dir}/${mod}.conf",
        target  => "${mod_dir}/${mod}.conf",
        owner   => 'root',
        group   => $apache::params::root_group,
        mode    => $apache::file_mode,
        require => [
          File["${mod}.conf"],
          Exec["mkdir ${enable_dir}"],
        ],
        before  => File[$enable_dir],
        notify  => Class['apache::service'],
      }
    }
  } elsif $facts['os']['family'] == 'Suse' {
    $enable_dir = $apache::mod_enable_dir
    file { "${_loadfile_name} symlink":
      ensure  => link,
      path    => "${enable_dir}/${_loadfile_name}",
      target  => "${mod_dir}/${_loadfile_name}",
      owner   => 'root',
      group   => $apache::params::root_group,
      mode    => $apache::file_mode,
      require => [
        File[$_loadfile_name],
        Exec["mkdir ${enable_dir}"],
      ],
      before  => File[$enable_dir],
      notify  => Class['apache::service'],
    }
    # Each module may have a .conf file as well, which should be
    # defined in the class apache::mod::module
    # Some modules do not require this file.
    if defined(File["${mod}.conf"]) {
      file { "${mod}.conf symlink":
        ensure  => link,
        path    => "${enable_dir}/${mod}.conf",
        target  => "${mod_dir}/${mod}.conf",
        owner   => 'root',
        group   => $apache::params::root_group,
        mode    => $apache::file_mode,
        require => [
          File["${mod}.conf"],
          Exec["mkdir ${enable_dir}"],
        ],
        before  => File[$enable_dir],
        notify  => Class['apache::service'],
      }
    }
  }

  Apache::Mod[$name] -> Anchor['::apache::modules_set_up']
}
