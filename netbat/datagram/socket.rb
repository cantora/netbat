require 'netbat/log'
require 'netbat/datagram'
require 'netbat/msg'

require 'uri'

module Netbat::Datagram

#abstraction for a OOB datagram socket
class Socket

	class Error
		
		attr_accessor :msg

		def initialize(msg)
			@msg = msg
		end

		def err_type
			return Netbat::Msg::ErrType::UNSPECIFIED
		end
	end

	class PeerUnavailable < Error
		def err_type
			return Netbat::Msg::ErrType::PEER_UNAVAILABLE
		end
	end
	
	class Addr

		def to_s
			raise "not implemented"
		end

		def hash
			hsh = self.to_s().hash
			return hsh
		end

		def eql?(obj)
			return false if !obj.is_a?(self.class)
			return self.to_s() == obj.to_s()
		end

		def ==(obj)
			return self.eql?(obj)
		end
	end

	def addr
		raise "not implemented"
	end

	def bound?
		raise "not implemented"
	end

	def bind()
		raise "not implemented"
	end

	def on_recv(&bloc)
		raise "not implemented"
	end

	def on_bind(&bloc)
		raise "not implemented"
	end

	def on_close(&bloc)
		raise "not implemented"
	end

	def close
		raise "not implemented"
	end

	def send_msg(addr, msg)
		raise "not implemented"
	end
end

end #Datagram
