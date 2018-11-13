require 'spec_helper_acceptance'

describe 'Scenario: install foreman' do
  before(:context) do
    case os[:family]
    when /redhat|fedora/
      on default, 'yum -y remove foreman* tfm-* && rm -rf /etc/yum.repos.d/foreman*.repo'
    when /debian|ubuntu/
      on default, 'apt-get purge -y foreman*', { :acceptable_exit_codes => [0, 100] }
      on default, 'apt-get purge -y ruby-hammer-cli-*', { :acceptable_exit_codes => [0, 100] }
      on default, 'rm -rf /etc/apt/sources.list.d/foreman*'
    end
  end

  let(:pp) do
    configure = os[:family] == 'redhat' && os[:family] != 'fedora'
    <<-EOS
    # Workarounds

    ## Ensure repos are present before installing
    Yumrepo <| |> -> Package <| |>

    # Get a certificate from puppet
    exec { 'puppet_server_config-generate_ca_cert':
      creates => '/etc/puppetlabs/puppet/ssl/certs/#{host_inventory['fqdn']}.pem',
      command => '/opt/puppetlabs/bin/puppet ca generate #{host_inventory['fqdn']}',
      umask   => '0022',
    }

    # Actual test
    class { '::foreman':
      custom_repo         => false,
      repo                => 'nightly',
      passenger           => false,
      configure_epel_repo => #{configure},
      configure_scl_repo  => #{configure},
      user_groups         => [],
      admin_username      => 'admin',
      admin_password      => 'changeme',
    }
    EOS
  end

  it_behaves_like 'a idempotent resource'

  describe service(os[:family] == 'debian' ? 'apache2' : 'httpd') do
    it { is_expected.to be_enabled }
    it { is_expected.to be_running }
  end

  describe service('dynflowd') do
    it { is_expected.to be_enabled }
    it { is_expected.to be_running }
  end

  describe service('foreman') do
    it { is_expected.to be_enabled }
    it { is_expected.to be_running }
  end

  describe port(80) do
    it { is_expected.to be_listening }
  end

  describe port(443) do
    it { is_expected.to be_listening }
  end

  describe port(3000) do
    it { is_expected.to be_listening }
  end

  describe command("curl -sk https://#{host_inventory['fqdn']}/users/login") do
    its(:stdout) { is_expected.to match(/login-form/) }
    its(:exit_status) { is_expected.to eq 0 }
  end
end
