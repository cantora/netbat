require 'netbat/datagram'

require 'base64'

['peer_info'].each do |fname|
	require File.join('netbat', 'proto_proc', fname)
end


module Netbat

class ClientCtx < Datagram::ConnectionCtx

	def loop()
		
		@current_proc = PeerInfo::client(self, @local_info)
		peer_info = @current_proc.run()

		raise "peer_info: #{peer_info.inspect}"

	end

end

end