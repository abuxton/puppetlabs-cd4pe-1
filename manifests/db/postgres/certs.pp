class cd4pe::db::postgres::certs(
  String $pg_user,
  String $pg_group,
  String $pg_cert_dir,
  String $client_cert,
  String $client_private_key,
){

  $cert_dir = "${cd4pe::db::data_root_dir}/certs"
  $certname = $trusted['certname']

  # Copy the local agent certs for the container to use, and mount them
  Docker::Run <| title == 'cd4pe' |> {
    volumes +> ["${cert_dir}:/certs"]
  }

  file { $cert_dir:
    ensure =>  directory,
    owner  =>  'root',
    group  =>  'root',
    mode   =>  '0600',
  }

  file { "${cert_dir}/${certname}.cert.pem":
    ensure => file,
    source => $client_cert,
    owner  => 'root',
    group  => 'root',
    mode   => '0400',
  }

  $pk8_file = "${cert_dir}/${certname}.private_key.pk8"

  exec { $pk8_file:
    path    => [ '/opt/puppetlabs/puppet/bin', $::facts['path'] ],
    command => "openssl pkcs8 -topk8 -inform PEM -outform DER -in ${client_private_key} -out ${pk8_file} -nocrypt",
    onlyif => "test ! -e '${pk8_file}' -o '${pk8_file}' -ot '${client_private_key}'",
  }

  file { $pk8_file:
    ensure => present,
    owner  => 'root',
    group  => 'root',
    mode   => '0400',
  }

  # Copy the client certs to postgres
  file { $pg_cert_dir:
    ensure => directory,
    owner  => $pg_user,
    group  => $pg_group,
    mode   => '0600',
  }

  file { "${pg_cert_dir}/${certname}.cert.pem":
    ensure => file,
    source => $client_cert,
    owner  => $pg_user,
    group  => $pg_group,
    mode   => '0400',
  }

  file { "${pg_cert_dir}/${certname}.private_key.pem":
    ensure => file,
    source => $client_private_key,
    owner  => $pg_user,
    group  => $pg_group,
    mode   => '0400',
  }
}
