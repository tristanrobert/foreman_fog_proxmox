# frozen_string_literal: true

# Copyright 2018 Tristan Robert

# This file is part of ForemanFogProxmox.

# ForemanFogProxmox is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# ForemanFogProxmox is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with ForemanFogProxmox. If not, see <http://www.gnu.org/licenses/>.

require 'test_plugin_helper'
require 'models/compute_resources/compute_resource_test_helpers'
require 'factories/foreman_fog_proxmox/proxmox_node_mock_factory'
require 'factories/foreman_fog_proxmox/proxmox_server_mock_factory'
require 'factories/foreman_fog_proxmox/proxmox_container_mock_factory'
require 'active_support/core_ext/hash/indifferent_access'

module ForemanFogProxmox
  class ProxmoxInterfacesTest < ActiveSupport::TestCase
    include ComputeResourceTestHelpers
    include ProxmoxNodeMockFactory
    include ProxmoxServerMockFactory
    include ProxmoxContainerMockFactory
    include ProxmoxVmHelper

    describe 'host_interfaces_attrs' do
      before do
        @cr = FactoryBot.build_stubbed(:proxmox_cr)
      end

      it 'raises Foreman::Exception when physical identifier does not match net[k] with k integer' do
        physical_nic = FactoryBot.build(:nic_base_empty, :identifier => 'eth0')
        host = FactoryBot.build(:host_empty, :interfaces => [physical_nic])
        err = assert_raises Foreman::Exception do
          @cr.host_interfaces_attrs(host)
        end
        assert err.message.end_with?('Invalid identifier interface[0]. Must be net[n] with n integer >= 0')
      end

      it 'sets server compute id with identifier, ip and ip6 and mac adress' do
        ip = '192.168.56.100'
        mac_address = '36:25:8c:53:0c:50'
        ip6 = Array.new(4) { format('%<x>s', x: rand(16**4)) }.join(':') + '::1'
        physical_nic = FactoryBot.build(:nic_base_empty, :identifier => 'net0', :ip => ip, :ip6 => ip6, :mac => mac_address)
        host = FactoryBot.build(
          :host_empty,
          :interfaces => [physical_nic],
          :compute_attributes => {
            'type' => 'qemu',
            'interfaces_attributes' => {
              '0' => physical_nic
            }
          }
        )
        nic_attributes = @cr.host_interfaces_attrs(host).values.select(&:present?)
        nic_attr = nic_attributes.first
        assert_equal 'net0', nic_attr[:id]
        assert_equal ip, nic_attr[:ip]
        assert_equal ip6, nic_attr[:ip6]
        assert_equal mac_address, nic_attr[:macaddr]
      end

      it 'sets container compute id with identifier, ip/CIDR, gw and ip6' do
        ip = '192.168.56.100'
        cidr = '31'
        ip6 = Array.new(4) { format('%<x>s', x: rand(16**4)) }.join(':') + '::1'
        physical_nic = FactoryBot.build(:nic_base_empty, :identifier => 'net0', :ip => ip, :ip6 => ip6, :compute_attributes => { 'cidr' => cidr, 'gw' => ip, 'ip' => ip, 'dhcp6' => '1' })
        host = FactoryBot.build(
          :host_empty,
          :interfaces => [physical_nic],
          :compute_attributes => {
            'type' => 'lxc',
            'interfaces_attributes' => {
              '0' => physical_nic
            }
          }
        )
        nic_attributes = @cr.host_interfaces_attrs(host).values.select(&:present?)
        nic_attr = nic_attributes.first
        assert_equal 'net0', nic_attr[:id]
        assert_equal Fog::Proxmox::IpHelper.to_cidr(ip, cidr), nic_attr[:ip]
        assert_equal ip, nic_attr['gw']
        assert_equal 'dhcp', nic_attr[:ip6]
      end

      it 'sets container compute id with identifier, ip DHCP, gw6 and ip6' do
        ip = '192.168.56.100'
        cidr6 = '100'
        ip6 = '2001:0:1234::c1c0:abcd:876'
        physical_nic = FactoryBot.build(:nic_base_empty, :identifier => 'net0', :ip => ip, :ip6 => ip6, :compute_attributes => { 'cidr6' => cidr6, 'dhcp' => '1', 'gw6' => ip6 })
        host = FactoryBot.build(
          :host_empty,
          :interfaces => [physical_nic],
          :compute_attributes => {
            'type' => 'lxc',
            'interfaces_attributes' => {
              '0' => physical_nic
            }
          }
        )
        nic_attributes = @cr.host_interfaces_attrs(host).values.select(&:present?)
        nic_attr = nic_attributes.first
        assert_equal 'net0', nic_attr[:id]
        assert_equal 'dhcp', nic_attr[:ip]
        assert_equal Fog::Proxmox::IpHelper.to_cidr6(ip6, cidr6), nic_attr[:ip6]
        assert_equal ip6, nic_attr['gw6']
      end

      it 'sets container compute id with identifier, ip DHCP, mac adress and firewall' do
        ip = '192.168.56.100'
        mac_address = '36:25:8c:53:0c:50'
        ip6 = '2001:0:1234::c1c0:abcd:876'
        firewall = '1'
        compute_attributes = { 'dhcp' => '1', 'ip6' => ip6, 'firewall' => firewall }
        physical_nic = FactoryBot.build(:nic_base_empty, :identifier => 'net0', :ip => ip, :ip6 => ip6, :mac => mac_address, :compute_attributes => compute_attributes)
        host = FactoryBot.build(
          :host_empty,
          :interfaces => [physical_nic],
          :compute_attributes => {
            'type' => 'lxc',
            'interfaces_attributes' => {
              '0' => physical_nic
            }
          }
        )
        nic_attributes = @cr.host_interfaces_attrs(host).values.select(&:present?)
        nic_attr = nic_attributes.first
        assert_equal 'net0', nic_attr[:id]
        assert_equal 'dhcp', nic_attr[:ip]
        assert_equal mac_address, nic_attr[:hwaddr]
        assert_equal ip6, nic_attr[:ip6]
        assert_equal firewall, nic_attr['firewall']
      end
    end
  end
end
