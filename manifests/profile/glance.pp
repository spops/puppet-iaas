class iaas::profile::glance (
  $keystone_password = undef,
  $public_ipaddress = undef,
  $admin_ipaddress = undef,

  $region = hiera('iaas::region', undef),
  $endpoint = hiera('iaas::role::endpoint::main_address', undef),
  $rabbitmq_user = hiera('iaas::profile::rabbitmq::user', undef),
  $rabbitmq_password = hiera('iaas::profile::rabbitmq::password', undef),
) {
  include iaas::resources::connectors

  class { 'ceph::profile::client': } ->
  class { 'ceph::keys': } ->

  class { '::glance::api':
    keystone_password => $keystone_password,
    auth_host => $endpoint,
    keystone_tenant => 'services',
    keystone_user => 'glance',
    database_connection => $iaas::resources::connectors::glance,
    registry_host => 'localhost',
    mysql_module => '2.3',
    os_region_name => $region,
    known_stores => ['rbd'],
    database_idle_timeout => 50, # Important to avoid facing "MySQL server has gone away" while using HAProxy+Galera. Should be < HAProxy server timeout (default: 60s)
  }

  class { '::glance::backend::rbd':
    rbd_store_user => 'glance',
    rbd_store_ceph_conf => '/etc/ceph/ceph.conf',
    rbd_store_pool => 'images',
  }

  class { '::glance::registry':
    keystone_password => $keystone_password,
    database_connection => $iaas::resources::connectors::glance,
    auth_host => $endpoint,
    keystone_tenant => 'services',
    keystone_user => 'glance',
    mysql_module => '2.3',
    database_idle_timeout => 50, # Important to avoid facing "MySQL server has gone away" while using HAProxy+Galera. Should be < HAProxy server timeout (default: 60s)
  }

  class { '::glance::notify::rabbitmq':
    rabbit_userid => $rabbitmq_user,
    rabbit_password => $rabbitmq_password,
    rabbit_host => $endpoint,
  }

  iaas::resources::database { 'glance': }

  class  { '::glance::keystone::auth':
    password => $keystone_password,
    public_address => $public_ipaddress,
    admin_address => $admin_ipaddress,
    internal_address => $admin_ipaddress,
    region => $region,
  }

  @@haproxy::balancermember { "glance_registry_${::fqdn}":
    listening_service => 'glance_registry_cluster',
    server_names => $::hostname,
    ipaddresses => $::ipaddress,
    ports => '9191',
    options => 'check inter 2000 rise 2 fall 5',
  }
  @@haproxy::balancermember { "glance_api_${::fqdn}":
    listening_service => 'glance_api_cluster',
    server_names => $::hostname,
    ipaddresses => $public_ipaddress,
    ports => '9292',
    options => 'check inter 2000 rise 2 fall 5',
  }
}
