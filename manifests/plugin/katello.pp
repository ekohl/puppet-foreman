class foreman::plugin::katello (
  Boolean $enable_ostree = false,
  Boolean $enable_yum = true,
  Boolean $enable_file = true,
  Boolean $enable_puppet = true,
  Boolean $enable_docker = true,
  Boolean $enable_deb = true,
  Stdlib::HTTPSUrl $pulp_url = 'https://localhost/pulp/api/v2',
  Optional[Stdlib::Absolutepath] $pulp_ca_cert = undef,
  Optional[Stdlib::Absolutepath] $pulp_client_cert = undef,
  Optional[Stdlib::Absolutepath] $pulp_client_key = undef,
  Stdlib::HTTPSUrl $candlepin_url = 'https://localhost:8443/candlepin',
  String[1] $candlepin_oauth_key = 'katello',
  String[1] $candlepin_oauth_secret = 'secret',
  Optional[Stdlib::Absolutepath] $candlepin_ca_cert = undef,
  String[1] $qpid_url = "amqp:ssl:localhost:5671",
  String[1] $candlepin_event_queue = 'katello_event_queue',
  Stdlib::HTTPSurl $crane_url = 'https://localhost:5000',
  Optional[Stdlib::Absolutepath] $crane_ca_cert = undef,
  Boolean $use_pulp_2_for_file = false,
  Boolean $use_pulp_2_for_docker = false,
) {
  include foreman::plugin::tasks

  foreman::plugin { 'katello':
    package     => $foreman::plugin_prefix.regsubst(/foreman_/, 'katello'),
    config      => template('foreman/katello.yaml.erb'),
    config_file => "${foreman::plugin_config_dir}/katello.yaml",
  }

  foreman_config_entry { 'pulp_client_cert':
    value          => $pulp_client_cert,
    ignore_missing => false,
    require        => Foreman::Rake['db:seed'],
  }

  foreman_config_entry { 'pulp_client_key':
    value          => $pulp_client_key,
    ignore_missing => false,
    require        => Foreman::Rake['db:seed'],
  }

  if $foreman::jobs_manage_service {
    foreman::dynflow::worker { 'worker-hosts-queue':
      queues => ['hosts_queue'],
    }
  }
}
