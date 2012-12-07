require 'netbat/msg'
require 'netbat/public'
require 'system/getifaddrs'

module Netbat

class PeerInfo

	attr_reader :host_type, :supported_ops

	def initialize(host_type, supported_ops)
		@host_type = host_type
		@supported_ops = supported_ops
	end

	def self.make(host_type, supported_ops)
		sops = supported_ops.map do |opname|
			Msg::OpCode.const_get(opname)
		end

		return self.new(Msg::HostType.const_get(host_type), sops)
	end

end

class LocalInfo

	attr_reader :ipv4  #, :ifc, :ifc_ipv4

	def initialize(host_type, supported_ops, *args)
		@my_info = PeerInfo.make(host_type, supported_ops)

		args.each do |arg|
			if arg.is_a?(Hash)
				arg.each do |k,v|
					@ipv4 = Public::str_to_ipv4_addr(v) if !v.nil? && !v.empty?
				end
			end
		end

		@ipv4 = self.class::find_public_addr() if @ipv4.nil?
		#@ifc = :eth0
		#@ifc_ipv4 = System.get_ifaddrs[@ifc][:inet_addr]
	end
	
	def host_type
		@my_info.host_type
	end

	def supported_ops
		@my_info.supported_ops
	end

	def self.find_public_addr
		return Public::ipv4()
	end
end

end #Netbat
