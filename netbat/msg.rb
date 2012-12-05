require 'netbat/protobuf/netbat.pb'
require 'netbat/peer_info'

require 'ipaddr'

class IPAddr
	
	def self.ipv4_from_int(n)
		if n < 0
			raise ArgumentError.new, "cant convert negative integer into IP address"
		elsif n > (2**32-1)
			raise ArgumentError.new, "number too large to represent ipv4 address"
		else
			return IPAddr.new_ntoh([n].pack("N"))
		end
	end

end

module Netbat

class Msg

	def error?
		return send(:err_type) != ErrType::NONE
	end

	def check(*args)
		args.each do |arg|
			next if !arg.is_a?(Hash)

			arg.each do |k,v|
				return false if self.send(k) != v
			end
		end

		return true
	end

end

end