require 'spec_helper'

describe 'foreman::plugin::katello' do
  let :params do
    {
      :oauth_secret    => 'oauth-secret',
      :post_sync_token => 'post-sync-token',
    }
  end

  include_examples 'basic foreman plugin tests', 'katello'

  it 'should write katello.yaml' do
    should contain_file('/etc/foreman/plugins/katello.yaml')
    verify_exact_contents(catalogue, '/etc/foreman/plugins/katello.yaml', [
      '---',
      ':katello:',
      '  :rest_client_timeout: 3600',
      '  :post_sync_url: https://foo.example.com/katello/api/v2/repositories/sync_complete?token=post-sync-token',
      '  :candlepin:',
      '    :url: https://foo.example.com:8443/candlepin',
      '    :oauth_key: katello',
      '    :oauth_secret: oauth-secret',
      '  :pulp:',
      '    :url: https://foo.example.com/pulp/api/v2/',
      '    :oauth_key: katello',
      '    :oauth_secret: oauth-secret',
      '  :qpid:',
      '    :url: amqp:ssl:localhost:5671',
      '    :subscriptions_queue_address: katello_event_queue',
    ])
  end
end
