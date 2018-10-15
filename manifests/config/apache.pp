# Configure the foreman service using passenger
#
# === Parameters:
#
# $app_root::                 Root of the application.
#
# $listen_on_interface::      Specify which interface to bind passenger to.
#                             Defaults to all interfaces.
#
# $passenger_ruby::           Path to Ruby interpreter
#
# $priority::                 Apache vhost priority
#
# $servername::               Servername for the vhost.
#
# $serveraliases::            Serveraliases for the vhost.
#
# $server_port::              Port for Apache to listen on HTTP requests
#
# $server_ssl_port::          Port for Apache to listen on HTTPS requests
#
# $ssl::                      Whether to enable SSL.
#
# $ssl_cert::                 Location of the SSL certificate file.
#
# $ssl_certs_dir::            Location of additional certificates for SSL client authentication.
#
# $ssl_key::                  Location of the SSL key file.
#
# $ssl_ca::                   Location of the SSL CA file
#
# $ssl_chain::                Location of the SSL chain file
#
# $ssl_crl::                  Location of the SSL certificate revocation list file
#
# $ssl_protocol::             SSLProtocol configuration to use
#
# $user::                     The user under which the application runs.
#
# $passenger_prestart::       Pre-start the first passenger worker instance process during httpd start.
#
# $passenger_min_instances::  Minimum passenger worker instances to keep when application is idle.
#
# $passenger_start_timeout::  Amount of seconds to wait for Ruby application boot.
#
# $foreman_url::              The URL Foreman should be reachable under. Used for loading the application
#                             on startup rather than on demand.
#
# $keepalive::                Enable KeepAlive setting of Apache?
#
# $max_keepalive_requests::   MaxKeepAliveRequests setting of Apache
#                             (Number of requests allowed on a persistent connection)
#
# $keepalive_timeout::        KeepAliveTimeout setting of Apache
#                             (Seconds the server will wait for subsequent requests on a persistent connection)
#
# $access_log_format::        Apache log format to use
#
# $ipa_authentication::       Whether to install support for IPA authentication
#
class foreman::config::apache(
  Boolean $passenger = $::foreman::passenger,
  Stdlib::Absolutepath $app_root = $::foreman::app_root,
  Optional[String] $listen_on_interface = $::foreman::passenger_interface,
  Optional[String] $passenger_ruby = $::foreman::passenger_ruby,
  String $priority = $::foreman::vhost_priority,
  Stdlib::Fqdn $servername = $::foreman::servername,
  Array[Stdlib::Fqdn] $serveraliases = $::foreman::serveraliases,
  Stdlib::Port $server_port = $::foreman::server_port,
  Stdlib::Port $server_ssl_port = $::foreman::server_ssl_port,
  Boolean $ssl = $::foreman::ssl,
  Stdlib::Absolutepath $ssl_ca = $::foreman::server_ssl_ca,
  Stdlib::Absolutepath $ssl_chain = $::foreman::server_ssl_chain,
  Stdlib::Absolutepath $ssl_cert = $::foreman::server_ssl_cert,
  Variant[Enum[''], Stdlib::Absolutepath] $ssl_certs_dir = $::foreman::server_ssl_certs_dir,
  Stdlib::Absolutepath $ssl_key = $::foreman::server_ssl_key,
  Variant[Enum[''], Stdlib::Absolutepath] $ssl_crl = $::foreman::server_ssl_crl,
  Optional[String] $ssl_protocol = $::foreman::server_ssl_protocol,
  String $user = $::foreman::user,
  Boolean $passenger_prestart = $::foreman::passenger_prestart,
  Integer[0] $passenger_min_instances = $::foreman::passenger_min_instances,
  Integer[0] $passenger_start_timeout = $::foreman::passenger_start_timeout,
  Stdlib::HTTPUrl $foreman_url = $::foreman::foreman_url,
  Boolean $keepalive = $::foreman::keepalive,
  Integer[0] $max_keepalive_requests = $::foreman::max_keepalive_requests,
  Integer[0] $keepalive_timeout = $::foreman::keepalive_timeout,
  Optional[String] $access_log_format = undef,
  Boolean $ipa_authentication = $::foreman::ipa_authentication,
) {
  $docroot = "${app_root}/public"
  $suburi_parts = split($foreman_url, '/')
  $suburi_parts_count = size($suburi_parts) - 1
  if $suburi_parts_count >= 3 {
    $suburi_without_slash = join(values_at($suburi_parts, ["3-${suburi_parts_count}"]), '/')
    if $suburi_without_slash {
      $suburi = "/${suburi_without_slash}"
    } else {
      $suburi = undef
    }
  } else {
    $suburi = undef
  }

  if $passenger {
    $passenger_options = {
      'passenger_app_root' => $app_root,
      'passenger_min_instances' => $passenger_min_instances,
      'passenger_start_timeout' => $passenger_start_timeout,
      'passenger_ruby' => $passenger_ruby,
    }
    $passenger_http_prestart = $passenger_prestart ? {
      true  => "http://${servername}:${server_port}",
      false => undef,
    }
    $passenger_https_prestart = $passenger_prestart ? {
      true  => "https://${servername}:${server_ssl_port}",
      false => undef,
    }

    if $suburi {
      $custom_fragment = template('foreman/_suburi.conf.erb')
    } else {
      $custom_fragment = template('foreman/_assets.conf.erb')
    }

    $proxy_http_options = {}
    $proxy_https_options = {}

    if $app_root {
      file { ["${app_root}/config.ru", "${app_root}/config/environment.rb"]:
        owner => $user,
      }
    }
  } else {
    $passenger_options = {}
    $passenger_http_prestart = undef
    $passenger_https_prestart = undef

    if $suburi {
      $custom_fragment = undef
    } else {
      $custom_fragment = template('foreman/_assets.conf.erb')
    }

    $backend = 'http://localhost:3000/'

    $proxy_http_options = {
      'proxy_preserve_host' => true,
      'request_headers'     => ['set X_FORWARDED_PROTO "http"'],
      'proxy_pass'          => {
        'no_proxy_uris' => ['/pulp', '/streamer', '/pub'],
        'path'          => '/',
        'url'           => $backend,
        'params'        => {'retry' => '0'},
      },
    }
    $proxy_https_options = {
      'ssl_proxyengine'     => true,
      'proxy_preserve_host' => true,
      'request_headers'     => ['set X_FORWARDED_PROTO "https"'],
      'proxy_pass'          => {
        'no_proxy_uris' => ['/pulp', '/streamer', '/pub'],
        'path'          => '/',
        'url'           => $backend,
        'params'        => {'retry' => '0'},
      },
    }
  }

  include ::apache
  include ::apache::mod::headers

  if $ipa_authentication {
    include ::apache::mod::authnz_pam
    include ::apache::mod::intercept_form_submit
    include ::apache::mod::lookup_identity
    include ::apache::mod::auth_kerb
  }

  # Check the value in case the interface doesn't exist, otherwise listen on all interfaces
  if $listen_on_interface and $listen_on_interface in split($::interfaces, ',') {
    $listen_interface = fact("ipaddress_${listen_on_interface}")
  } else {
    $listen_interface = undef
  }

  file { "${apache::confd_dir}/${priority}-foreman.d":
    ensure  => 'directory',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    purge   => true,
    recurse => true,
  }

  $keepalive_onoff = $keepalive ? {
    true    => 'on',
    default => 'off',
  }

  apache::vhost { 'foreman':
    add_default_charset    => 'UTF-8',
    docroot                => $docroot,
    manage_docroot         => false,
    ip                     => $listen_interface,
    options                => ['SymLinksIfOwnerMatch'],
    port                   => $server_port,
    priority               => $priority,
    servername             => $servername,
    serveraliases          => $serveraliases,
    keepalive              => $keepalive_onoff,
    max_keepalive_requests => $max_keepalive_requests,
    keepalive_timeout      => $keepalive_timeout,
    access_log_format      => $access_log_format,
    additional_includes    => ["${::apache::confd_dir}/${priority}-foreman.d/*.conf"],
    use_optional_includes  => true,
    custom_fragment        => $custom_fragment,
    *                      => $passenger_options + $proxy_http_options,
    passenger_pre_start    => $passenger_http_prestart,
  }

  if $ssl {
    if $ssl_crl and $ssl_crl != '' {
      $ssl_crl_real = $ssl_crl
      $ssl_crl_check = 'chain'
    } else {
      $ssl_crl_real = undef
      $ssl_crl_check = undef
    }

    file { "${apache::confd_dir}/${priority}-foreman-ssl.d":
      ensure  => 'directory',
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      purge   => true,
      recurse => true,
    }

    apache::vhost { 'foreman-ssl':
      add_default_charset    => 'UTF-8',
      docroot                => $docroot,
      manage_docroot         => false,
      ip                     => $listen_interface,
      options                => ['SymLinksIfOwnerMatch'],
      port                   => $server_ssl_port,
      priority               => $priority,
      servername             => $servername,
      serveraliases          => $serveraliases,
      ssl                    => true,
      ssl_cert               => $ssl_cert,
      ssl_certs_dir          => $ssl_certs_dir,
      ssl_key                => $ssl_key,
      ssl_chain              => $ssl_chain,
      ssl_ca                 => $ssl_ca,
      ssl_crl                => $ssl_crl_real,
      ssl_crl_check          => $ssl_crl_check,
      ssl_protocol           => $ssl_protocol,
      ssl_verify_client      => 'optional',
      ssl_options            => '+StdEnvVars +ExportCertData',
      ssl_verify_depth       => '3',
      keepalive              => $keepalive_onoff,
      max_keepalive_requests => $max_keepalive_requests,
      keepalive_timeout      => $keepalive_timeout,
      access_log_format      => $access_log_format,
      additional_includes    => ["${::apache::confd_dir}/${priority}-foreman-ssl.d/*.conf"],
      use_optional_includes  => true,
      custom_fragment        => $custom_fragment,
      *                      => $passenger_options + $proxy_https_options,
      passenger_pre_start    => $passenger_https_prestart,
    }
  }
}
