class cd4pe::db::postgres(
  String $db_host                         = $trusted['certname'],
  String $db_name                         = 'cd4pe',
  Integer $db_port                        = 5432,
  String $db_prefix                       = '',
  String $db_user                         = 'cd4pe',
  String $listen_address                  = '*',
) {

  cd4pe::db::app_db_env { 'app_db_env file':
    db_host     => $db_host,
    db_port     => $db_port,
    db_prefix   => $db_prefix,
    db_provider => 'postgres',
    db_name     => $db_name,
    db_user     => $db_user,
  }

  include puppet_enterprise::packages

  $certname = $trusted['certname']
  $pg_version  = '9.6'
  $pg_bin_dir  = '/opt/puppetlabs/server/bin'
  $pg_sql_path = '/opt/puppetlabs/server/bin/psql'
  $pgsqldir    = '/opt/puppetlabs/server/data/postgresql'
  $pgsql_data_dir = "${pgsqldir}/${pg_version}/data"
  $pg_ident_conf_path = "${pgsql_data_dir}/pg_ident.conf"
  $postgres_cert_dir = "${pgsql_data_dir}/certs"
  $pg_user = 'pe-postgres'
  $pg_group = 'pe-postgres'

  $ssl_dir = $puppet_enterprise::params::ssl_dir
  $client_pem_key = "${ssl_dir}/private_keys/${certname}.pem"
  $client_cert    = "${ssl_dir}/certs/${certname}.pem"
  $client_ca_cert    = "${ssl_dir}/certs/ca.pem"

  class { 'cd4pe::db::postgres::certs': 
    pg_user            => $pg_user,
    pg_group           => $pg_group,
    pg_cert_dir        => $postgres_cert_dir,
    client_cert        => $client_cert,
    client_private_key => $client_pem_key,
  }

  File {
    ensure  => file,
    owner   => $pg_user,
    group   => $pg_group,
    mode    => '0400',
  }

  # set our parameters for the params for to inherit
  class { '::pe_postgresql::globals':
    user                 => $pg_user,
    group                => $pg_group,
    client_package_name  => 'pe-postgresql96',
    contrib_package_name => 'pe-postgresql96-contrib',
    server_package_name  => 'pe-postgresql96-server',
    service_name         => 'pe-postgresql',
    default_database     => 'postgres',
    version              => $pg_version,
    bindir               => $pg_bin_dir,
    datadir              => $pgsql_data_dir,
    confdir              => $pgsql_data_dir,
    psql_path            => $pg_sql_path,
    needs_initdb         => true,
    pg_hba_conf_defaults => false,
  }

  # manage the directories the pgsql server will use
  file {[$pgsqldir, "${pgsqldir}/${pg_version}" ]:
    ensure  => directory,
    mode    => '0755',
    owner   => $pg_user,
    group   => $pg_group,
    require => Class['pe_postgresql::server::install'],
    before  => Class['pe_postgresql::server::initdb'],
  }
  # Ensure /etc/sysconfig/pgsql exists so the module can create and manage
  # pgsql/postgresql
  -> file { '/etc/sysconfig/pgsql':
    ensure => directory,
  }

  # get the pg server up and running
  class { 'pe_postgresql::server':
    listen_addresses        => $listen_address,
    ip_mask_allow_all_users => '0.0.0.0/0',
    package_ensure          => 'latest',
  }

  # The contrib package provides pg_upgrade, which is necessary for migrations
  # form one version of postgres (9.4 -> 9.6, for example)
  class { 'pe_postgresql::server::contrib':
    package_ensure => 'latest',
  }

  # The client package is a dependency of pe-postgresql-server, but upgrading
  # pe-postgresql-server to latest does not in all cases ensure that pe-postgresql
  # is upgrading to the same version. This resource makes it explicit.
  class { 'pe_postgresql::client':
    package_ensure => 'latest',
  }

  pe_postgresql::server::database { 'postgres':
      owner   => 'pe-postgres',
      require => Class['pe_postgresql::server']
  }

  pe_postgresql::server::database { 'pe-postgres':
      owner   => 'pe-postgres',
      require => Class['pe_postgresql::server']
  }

  # create the razor tablespace
  # create the razor database
  pe_postgresql::server::tablespace { $db_name:
    location => "${pgsqldir}/${pg_version}/${db_name}",
    require  => Class['pe_postgresql::server'],
  }

  # create our database
  pe_postgresql::server::db { $db_name:
    user       => 'cd4pe',
    password   => undef,
    tablespace => $db_name,
    require    => Pe_postgresql::Server::Tablespace[$db_name],
  }

  pe_concat { $pg_ident_conf_path:
    owner          => $pg_user,
    group          => $pg_group,
    force          => true, # do not crash if there is no pg_ident_rules
    mode           => '0640',
    warn           => true,
    require        => [Package['postgresql-server'], Class['pe_postgresql::server::initdb']],
    notify         => Class['pe_postgresql::server::reload'],
    ensure_newline => true,
  }

  pe_postgresql::server::pg_hba_rule { "local access as pe-postgres user":
    database    => 'all',
    user        => 'pe-postgres',
    type        => 'local',
    auth_method => 'peer',
    order       => '001',
  }

  $localhost = {
    'ipv4' => '127.0.0.1/32',
    'ipv6' => '::1/128',
  }
  $localhost.each |$protocol, $ip| {
    pe_postgresql::server::pg_hba_rule { "cert auth for localhost (${protocol})":
      type        => 'hostssl',
      user        => 'all',
      database    => 'all',
      address     => $ip,
      auth_method => 'cert',
      auth_option => 'clientcert=1',
    }
  }

  pe_postgresql::server::config_entry { 'ssl' :
    value => 'on',
  }

  pe_postgresql::server::config_entry { 'ssl_ca_file' :
    value => $client_ca_cert,
  }
  pe_postgresql::server::config_entry { 'ssl_cert_file' :
    value => "${postgres_cert_dir}/${certname}.cert.pem",
  }
  pe_postgresql::server::config_entry { 'ssl_key_file' :
    value => "${postgres_cert_dir}/${certname}.private_key.pem",
  }

  puppet_enterprise::pg::cert_whitelist_entry { 'cd4pe_whitelist': 
    user                          => $db_user,
    database                      => $db_name,
    allowed_client_certname       => $certname,
    pg_ident_conf_path            => $pg_ident_conf_path,
    ip_mask_allow_all_users_ssl   => '0.0.0.0/0',
    ipv6_mask_allow_all_users_ssl => '0.0.0.0/0',
  }

  pe_concat::fragment { "${title} ident rule fragment":
    target  => $pg_ident_conf_path,
    content => "test distelli cd4pe",
  }
}
