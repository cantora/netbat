require 'netbat/proto_proc'
require 'netbat/msg'

require 'timeout'
require 'socket'
require 'ipaddr'

module Netbat

#simplest firewall hole punch with no TCP state trickery
#does not require super user privs on either side
class BF0 < PunchProcDesc
	
	def self.supports?(my_type, peer_type)
		if my_type == Msg::HostType::FILTER \
				&& peer_type == Msg::HostType::FILTER
			return true
		end

		return false
	end

	register(self)

	OPCODE = Msg::OpCode::BF0

	def self.next_port
		offset = 1024
		return rand(2**16 - offset) + offset
	end

	def self.client(ctx, local_info)
		pproc = ProtoProc.new(ctx)

		pdesc = self
		pproc.init do
			@src_port = pdesc.next_port()
			send_msg(Msg.new(
				:op_code =>	OPCODE,
				:addr => Addr.new(
					:ip => local_info.ipv4.to_i,
					:port => @src_port
				)
			))

			trans_null()
		end

		pproc.on_recv :init do |msg|
			if msg.check(:op_code => OPCODE)
				if msg.addr.ip == 0 || !(1025..(2**16-1)).include?(msg.addr.port)
					proto_error("invalid ip or port: #{msg.inspect}")
				else
					begin
						addr = IPAddr::ipv4_from_int(msg.addr.ip).to_s
						tcpsock = Timeout.timeout(15) {TCPSocket.new(
							addr, 
							msg.addr.port, 
							"0.0.0.0",
							@src_port
						)}
						success(tcpsock)
					rescue Errno::ECONNREFUSED, Timeout::Error => e
						failure(e.inspect)
					end
				end
			else
				proto_error("unexpected response: #{msg.inspect}")
			end
		end

		return pproc
	end


	def self.server(ctx, local_info)
		pproc = ProtoProc.new(ctx)
		
		pdesc = self
		pproc.on_recv :init do |msg|
			@log.debug "BF0 msg: #{msg.inspect}"
			if msg.error?
				proto_error("error: (#{msg.err_type.inspect}) #{msg.err.inspect}")
			elsif msg.check(:op_code => OPCODE)
				src_port = pdesc.next_port()

				cx_thr = Thread.new do
					Thread.current.abort_on_exception = true

					begin
						addr = IPAddr::ipv4_from_int(msg.addr.ip).to_s
						TCPSocket.new(
							addr,
							msg.addr.port, 
							"0.0.0.0",
							src_port
						)
					rescue Errno::ECONNREFUSED, Timeout::Error => e
						#this is expected
					end

					Thread.stop
					raise "shouldnt get here"
				end

				send_msg(Msg.new(
					:op_code => OPCODE,
					:addr => Addr.new(
						:ip => local_info.ipv4.to_i,
						:port => src_port
					)
				))

				sleep(0.2)
				cx_thr.terminate()
				result = begin 
					tcp_cx = Timeout::timeout(15) { TCPServer.new(src_port).accept }
					@log.info("success: #{server.inspect}")
					success(tcp_cx)
				rescue Timeout::Error => e
					failure("failure: never got connection")
				end

				result
			else
				proto_error("ignoring unexpected message: #{msg.inspect}")
			end
		end
				
		return pproc
	end

end

end