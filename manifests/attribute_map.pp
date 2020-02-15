# parameter setup allows an attribute_map to bedownloaded with one name
# and saved locally by another.
define shibboleth::attribute_map(
  $map_url,
  $map_dir  = $::shibboleth::cache_dir,
  $max_age  = '21'
){

  $attribute_map = "${map_dir}/${name}.xml"

  # Make sure the shibboleth config is pointing at the attribute map
  augeas{"shib_${name}_attribute_map":
    lens    => 'Xml.lns',
    incl    => $::shibboleth::config_file,
    context => "/files${::shibboleth::config_file}/SPConfig/ApplicationDefaults",
    changes => [
      "set AttributeExtractor/#attribute/url ${map_url}",
      "set AttributeExtractor/#attribute/backingFilePath ${attribute_map}",
      "set AttributeExtractor/#attribute/maxRefreshDelay ${max_age}",
    ],
    notify  => Service['httpd','shibd'],
  }

}
