# Currently this only creates a _single_ metadata provider
# it will need to be modified to permit multiple metadata providers
define shibboleth::metadata(
  $provider_url,
  $cert_url,
  $backing_file_dir         = $::shibboleth::cache_dir,
  $backing_file_name        = $provider_url.split('/')[-1],
  $cert_dir                 = $::shibboleth::conf_dir,
  $cert_file_name           = $cert_url.split('/')[-1],
  $provider_type            = 'XML',
  $provider_reload_interval = '7200',
  $metadata_filter_max_validity_interval  = '2419200'
){

  $backing_file = "${backing_file_dir}/${backing_file_name}"
  $cert_file    = "${cert_dir}/${cert_file_name}"

  # Get the Metadata signing certificate
  file { $cert_file:
    ensure   => present,
    source   => $cert_url,
    path     => $conf_dir,
    owner    => 'root',
    group    => 'root',
    seluser  => 'system_u',
    selrole  => 'object_r',
    seltype  => 'cert_t',
    selrange => 's0',
    notify   => Service['httpd','shibd'],
  }

  # This puts the MetadataProvider entry in the 'right' place
  augeas{"shib_${name}_create_metadata_provider":
    lens    => 'Xml.lns',
    incl    => $::shibboleth::config_file,
    context => "/files${::shibboleth::config_file}/SPConfig/ApplicationDefaults",
    changes => [
      'ins MetadataProvider after Errors',
    ],
    onlyif  => 'match MetadataProvider/#attribute/url size == 0',
    notify  => Service['httpd','shibd'],
    require => File[$cert_file],
  }

  # This will update the attributes and child nodes if they change
  augeas{"shib_${name}_metadata_provider":
    lens    => 'Xml.lns',
    incl    => $::shibboleth::config_file,
    context => "/files${::shibboleth::config_file}/SPConfig/ApplicationDefaults",
    changes => [
      "set MetadataProvider/#attribute/type ${provider_type}",
      "set MetadataProvider/#attribute/url ${provider_url}",
      "set MetadataProvider/#attribute/backingFilePath ${backing_file}",
      "set MetadataProvider/#attribute/reloadInterval ${provider_reload_interval}",
      'set MetadataProvider/MetadataFilter[1]/#attribute/type RequireValidUntil',
      "set MetadataProvider/MetadataFilter[1]/#attribute/maxValidityInterval ${metadata_filter_max_validity_interval}",
      'set MetadataProvider/MetadataFilter[2]/#attribute/type Signature',
      "set MetadataProvider/MetadataFilter[2]/#attribute/certificate ${cert_file}",
    ],
    notify  => Service['httpd','shibd'],
    require => [File[$cert_file],Augeas["shib_${name}_create_metadata_provider"]],
  }

}
