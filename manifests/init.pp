# Class: shibboleth
#
# This module manages shibboleth
#
# Parameters:
#
# Actions:
#
# Requires:
#
# Sample Usage:
#

# [Remember: No empty lines between comments and class definition]
class shibboleth (
  $admin              = $::shibboleth::params::admin,
  $hostname           = $::shibboleth::params::hostname,
  $user               = $::shibboleth::params::user,
  $group              = $::shibboleth::params::group,
  $logo_location      = $::shibboleth::params::logo_location,
  $style_sheet        = $::shibboleth::params::style_sheet,
  $conf_dir           = $::shibboleth::params::conf_dir,
  $conf_file          = $::shibboleth::params::conf_file,
  $cache_dir          = $::shibboleth::params::cache_dir,
  $sp_cert            = $::shibboleth::params::sp_cert,
  $bin_dir            = $::shibboleth::params::bin_dir,
  $handlerSSL         = true,
  $cookieProps        = undef,
  $consistent_address = true
) inherits shibboleth::params {

  $config_file = "${conf_dir}/${conf_file}"

  user{$user:
    ensure  => 'present',
    home    => '/var/log/shibboleth',
    shell   => '/bin/false',
    require => Class['apache::mod::shib'],
  }

  # by requiring the apache::mod::shib, these should wait for the package
  # to create the directory.
  file{'shibboleth_conf_dir':
    ensure  => 'directory',
    path    => $conf_dir,
    owner   => 'root',
    group   => 'root',
    recurse => true,
    purge   => true,
    require => Class['apache::mod::shib'],
  }

  file{'shibboleth_config_file':
    ensure  => 'file',
    path    => $config_file,
    replace => false,
    require => [Class['apache::mod::shib'],File['shibboleth_conf_dir']],
  }

  file{'shibboleth_cache_dir':
    ensure  => 'directory',
    path    => $cache_dir,
    owner   => $user,
    group   => $group,
    require => Class['apache::mod::shib'],
  }

  # Prevent these files from being purged
  file { ["${conf_dir}/protocols.xml",
          "${conf_dir}/security-policy.xml",
          "${conf_dir}/attribute-policy.xml",
          "${conf_dir}/shibd.logger",
          "${conf_dir}/metadataError.html",
          "${conf_dir}/sessionError.html",
          "${conf_dir}/sslError.html"]:
    ensure   => present,
    owner    => 'root',
    group    => 'root',
    seluser  => 'system_u',
    selrole  => 'object_r',
    seltype  => 'etc_t',
    selrange => 's0',
  }

# Using augeas is a performance hit, but it works. Fix later.
  augeas{'sp_config_resources':
    lens    => 'Xml.lns',
    incl    => $config_file,
    context => "/files${config_file}/SPConfig/ApplicationDefaults",
    changes => [
      "set Errors/#attribute/supportContact ${admin}",
      "set Errors/#attribute/logoLocation ${logo_location}",
      "set Errors/#attribute/styleSheet ${style_sheet}",
    ],
    notify  => Service['httpd','shibd'],
    require => File['shibboleth_config_file'],
  }

  augeas{'sp_config_consistent_address':
    lens    => 'Xml.lns',
    incl    => $config_file,
    context => "/files${config_file}/SPConfig/ApplicationDefaults",
    changes => [
      "set Sessions/#attribute/consistentAddress ${consistent_address}",
    ],
    notify  => Service['httpd','shibd'],
    require => File['shibboleth_config_file'],
  }

  augeas{'sp_config_hostname':
    lens    => 'Xml.lns',
    incl    => $config_file,
    context => "/files${config_file}/SPConfig/ApplicationDefaults",
    changes => [
      "set #attribute/entityID https://${hostname}/shibboleth",
      "set Sessions/#attribute/handlerURL https://${hostname}/Shibboleth.sso",
    ],
    notify  => Service['httpd','shibd'],
    require => File['shibboleth_config_file'],
  }

  augeas{'sp_config_handlerSSL':
    lens    => 'Xml.lns',
    incl    => $config_file,
    context => "/files${config_file}/SPConfig/ApplicationDefaults",
    changes => [
      "set Sessions/#attribute/handlerSSL ${handlerSSL}",
    ],
    notify  => Service['httpd','shibd'],
    require => File['shibboleth_config_file'],
  }

  # If cookieProps is undef,
  # default cookieProps to https if handlerSSL = true, http otherwise.
  if $cookieProps == undef {
    $_cookieProps = $handlerSSL ? {
      true    => 'https',
      default => 'http',
    }
  } else {
    $_cookieProps = $cookieProps
  }
  augeas{'sp_config_cookieProps':
    lens    => 'Xml.lns',
    incl    => $config_file,
    context => "/files${config_file}/SPConfig/ApplicationDefaults",
    changes => [
      "set Sessions/#attribute/cookieProps ${_cookieProps}",
    ],
    notify  => Service['httpd','shibd'],
    require => File['shibboleth_config_file'],
  }

  augeas{'sp_config_metadata':
    lens    => 'Xml.lns',
    incl    => $config_file,
    context => "/files${config_file}",
    changes => [
      'set SPConfig/#attribute/xmlns:md urn:oasis:names:tc:SAML:2.0:metadata',
    ],
    notify  => Service['httpd','shibd'],
    require => File['shibboleth_config_file'],
  }

  service{'shibd':
    ensure     => 'running',
    enable     => true,
    hasrestart => true,
    hasstatus  => true,
    require    => [Class['apache::mod::shib'],User[$user]],
  }

}
