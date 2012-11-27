require 'netbat/msg'
require 'netbat/public'

module Netbat

class LocalInfo

	def initialize(host_type, supported_ops)
		@host_type = host_type
		@supported_ops = supported_ops
		@ipv4 = self.class::find_public_addr()
	end

	def host_type()
		return Msg::HostType.const_get(@host_type)
	end

	def supported_ops()
		return @supported_ops.map do |opname|
			Msg::OpCode.const_get(opname)
		end
	end

	def self.find_public_addr
		return Public::ipv4()
	end
end

end #Netbat
