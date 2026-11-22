# frozen_string_literal: true

require 'spec_helper'

describe 'test::generate_systemd_user' do
  platform 'ubuntu', '24.04'
  step_into :podman_generate_systemd

  let(:chef_run) do
    ChefSpec::SoloRunner.new(
      platform: 'ubuntu',
      version: '24.04',
      step_into: %w(podman_generate_systemd)
    ).converge(described_recipe)
  end

  before do
    allow(Etc).to receive(:getpwnam).with('chef').and_return(double(uid: 1002, dir: '/home/chef'))
    stub_podman
    chef_run
  end

  it 'defaults to the user unit directory and reloads with --user' do
    expect(chef_run).to create_file('/home/chef/.config/systemd/user/container-web.service')
    expect(chef_run.execute('generate-systemd daemon-reload /home/chef/.config/systemd/user').command).to eq('systemctl --user daemon-reload')
  end

  it 'keeps the user manager alive before writing the units' do
    expect(chef_run.execute('enable lingering for chef').command).to eq(%w(loginctl enable-linger chef))
    expect(chef_run.execute('start user manager for chef').command).to eq(%w(systemctl start user@1002.service))
  end

  it 'runs the reload as the user with that user runtime directory' do
    reload = chef_run.execute('generate-systemd daemon-reload /home/chef/.config/systemd/user')
    expect(reload.user).to eq('chef')
    expect(reload.environment).to include('XDG_RUNTIME_DIR' => '/run/user/1002')
  end
end
