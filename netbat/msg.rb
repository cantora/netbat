require 'netbat/protobuf/netbat.pb'

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