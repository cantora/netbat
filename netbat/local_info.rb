require 'netbat/msg'

module Netbat

class LocalInfo
	def initialize(host_type, supported_ops)
		@host_type = host_type
		@supported_ops = supported_ops
	end

	def host_type()
		return Msg::HostType.const_get(@host_type)
	end

	def supported_ops()
		return @supported_ops.map do |opname|
			Msg::OpCode.const_get(opname)
		end
	end
end

end #Netbat
