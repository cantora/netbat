require 'netbat/log'
require 'netbat/datagram'
require 'uri'

module Netbat::Datagram

def assert_uri(uri)
	if !uri.is_a?(URI)
		raise ArgumentError.new, "expected URI class, got: #{uri.inspect}"
	end
end

def assert_str(str)
	if !str.is_a?(String) && !str.empty?
		raise ArgumentError.new, "expected non-empty string, got: #{uri.inspect}"
	end
end

class Socket

	class Addr
		attr_reader :val

		def initialize(val)
			@val = val
		end

		def hash
			@val.hash
		end

		def eql?(obj)
			return true if obj.equal(self)
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
end

end #Datagram
