require 'netbat/datagram'
require 'base64'

['peer_info'].each do |fname|
	require File.join('netbat', 'proto_proc', fname)
end


module Netbat

class ClientCtx < Datagram::Connection

	def initialize(dg_socket, peer_addr, local_info)
		super(dg_socket, peer_addr)

		@local_info = local_info
		@current_proc = nil
		@current_proc_mtx = Mutex.new
		@log = Netbat::LOG
	end

	def loop()
		
		@current_proc = PeerInfo::client(self, @local_info)
		peer_info = @current_proc.run()

		raise "peer_info: #{peer_info.inspect}"

	end

	def log_str(s)
		return "ClientCtx: #{s}"	
	end

	def send_msg(msg)
		#"msg: #{msg.inspect}\n#{msg.methods.sort.inspect}"
		super(Base64::encode64(msg.to_s))
	end

	def recv(msg)
		@current_proc_mtx.synchronize do 
			if @current_proc.nil?
				@log.debug log_str("dropped msg: #{msg.inspect}")
			else
				@current_proc.recv(Msg::parse(Base64::decode64(msg)))
			end
		end
	end
end

end