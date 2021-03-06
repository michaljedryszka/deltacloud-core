# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.  The
# ASF licenses this file to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance with the
# License.  You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
# License for the specific language governing permissions and limitations
# under the License.
#

require 'nokogiri'

module CondorCloud

  class IPAgent

    attr_accessor :address

    def find_mac_by_ip(ip); end
    def find_ip_by_mac(mac); end
    def find_free_mac
      return nil
    end

    # This method must return an Array of 'CondorAddress' objects
    # [ CondorAddress.new, CondorAddress.new ]
    def addresses; end
  end


  # Default IP agent will lookup addresses from XML
  # files stored in config directory.
  # You can overide default directory using { :file => 'path' }
  #
  class DefaultIPAgent < IPAgent

    def initialize(opts={})
      @mappings = Nokogiri::XML(File.open(opts[:file] || File.join('config', 'addresses.xml')))
    end

    def find_free_mac
      addr_hash = {}
      DefaultExecutor::new do |executor|
        addresses = (@mappings/'/addresses/address').collect { |a| CondorAddress.new(:ip => a.text.strip, :mac => a[:mac]) }

        # Make an address hash to speed up the inner loop.
        addresses.each do |address|
          addr_hash[address.mac] = address.ip
        end

        executor.instances.each do |instance|
          instance.public_addresses.each do |public_address|
            if addr_hash.key?(public_address.mac)
              addr_hash.delete(public_address.mac)
            end
          end
        end
      end

      raise "No available MACs to assign to instance." if addr_hash.empty?

      return addr_hash.keys.first
    end

    def find_ip_by_mac(mac)
      t = (@mappings/"/addresses/address[@mac='#{mac}']").text
      t.empty? ? nil : t
    end

    def find_mac_by_ip(ip)
      (@mappings/"/addresses/address[.='#{ip}']").first[:mac] rescue nil
    end

    def addresses
      (@mappings/'/addresses/address').collect { |a| CondorAddress.new(:ip => a.text.strip, :mac => a[:mac]) }
    end
  end
end
