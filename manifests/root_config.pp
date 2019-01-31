class cd4pe::root_config(
  String[1] $root_email,
  Sensitive[String[1]] $root_password,
  String[1] $resolvable_hostname                           = $cd4pe::resolvable_hostname,
  String[1] $web_ui_endpoint                               = "${resolvable_hostname}:${cd4pe::web_ui_port}",
  String[1] $backend_service_endpoint                      = "${resolvable_hostname}:${cd4pe::backend_service_port}",
  String[1] $agent_service_endpoint                        = "${resolvable_hostname}:${cd4pe::agent_service_port}",
  Enum['DISK', 'ARTIFACTORY', 'S3'] $storage_provider      = 'DISK',
  String[1] $storage_disk_root                             = '/disk',
  String[1] $storage_bucket                                = 'cd4pe',
  Optional[String[1]] $storage_endpoint                    = undef,
  Optional[String[1]] $storage_prefix                      = undef,
  Optional[String[1]] $s3_access_key                       = undef,
  Optional[Sensitive[String[1]]] $s3_secret_key            = undef,
  Optional[Sensitive[String[1]]] $artifactory_access_token = undef,
) {

  cd4pe_root_config { $web_ui_endpoint:
    root_email               => $root_email,
    root_password            => $root_password,
    web_ui_endpoint          => $web_ui_endpoint,
    backend_service_endpoint => $backend_service_endpoint,
    agent_service_endpoint   => $agent_service_endpoint,
    storage_provider         => $storage_provider,
    storage_endpoint         => $storage_endpoint,
    storage_disk_root        => $storage_disk_root,
    storage_bucket           => $storage_bucket,
    storage_prefix           => $storage_prefix,
    s3_access_key            => $s3_access_key,
    s3_secret_key            => $s3_secret_key,
    artifactory_access_token => $artifactory_access_token
  }
}
