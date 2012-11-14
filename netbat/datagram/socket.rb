require 'netbat/log'
require 'netbat/datagram'
require 'uri'

module Netbat::Datagram

class Socket

	class Addr
		attr_reader :val

		def initialize(val)
			@val = val
		end

		def to_s
			raise "not implemented"
		end

		def hash
			hsh = @val.hash
			return hsh
		end

		def eql?(obj)
			return false if !obj.is_a?(self.class)
			return @val.eql?(obj.val)
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

	def send(addr, msg)
		raise "not implemented"
	end
end

end #Datagram
