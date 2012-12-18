require 'netbat/socket'

module Netbat

#generic description of a protocol procedure
class ProtoProcDesc

	@@procedures = {}

	def self.procedures
		return @@procedures
	end

	def self.register(fname, klass)
		@@procedures[File.basename(fname, ".rb")] = klass
	end
end

#description of a protocol procedure for NAT hole punching
class PunchProcDesc < ProtoProcDesc
	def self.supports?(my_type, peer_type)
		return false
	end

	module PunchProcResult

	end

	#a successfully hole punched UDP socket
	class PunchedUDP < UDPctx
		include PunchProcResult
		alias_method :rcv, :read
		alias_method :snd, :write
	end

	#random token for confirming two way connectivity
	def self.new_token()
		return (0..(7 + rand(9)) ).map do |i| 
			rand(0x100)
		end.pack("C*")
	end

	#repeatedly send the token to peer. peer will
	#send a OOB acknowledgement when it receives the
	#token over hole punched UDP
	def self.confirm_udp(pudp, token, timeout=15)
		begin
			Timeout::timeout(timeout) do 
				loop do 
					pudp.snd(token)
					sleep(0.5)
				end
			end
		rescue Timeout::Error
		end
	end

	#span the token to every port with the destination
	#port embedded in the UDP message
	def self.brute_udp(udpsock, dst_addr, token)
		ports = (1025..(2**16)-1).sort_by {|x| rand }

		ports.each do |port|
			udpsock.send("#{token}#{port}", 0, dst_addr, port)
		end
	end

	#wait to receive a udp message with the given token.
	#return a PunchedUDP socket on success
	#warning this may wait forever, so run it in another thread
	def self.wait_udp(usock, token, timeout=15)
		tlen = token.size
		loop do 
			data, addrinfo = usock.recvfrom(token.size)
			if token == data[0..tlen]
				return PunchedUDP.new(usock, addrinfo[3], addrinfo[1])
			end
		end
	end

	#wait to receive a UDP message with given token that has
	#been brute forced. extract the port number used to get through
	#and return it along with the PunchedUDP object
	def self.wait_brute_udp(usock, token, timeout=120)
		tlen = token.size
		loop do 
			data, addrinfo = usock.recvfrom(512)
			if token == data[0..(tlen-1)]
				return [PunchedUDP.new(usock, addrinfo[3], addrinfo[1]), data[tlen..-1] ]
			end
		end
	end

	#returns after 2 seconds of not receiving 
	#any token messages, or after receiving 
	#non-token data
	def self.clean_pudp(pudp, token)
		loop do
			begin
				Timeout::timeout(2) do
					return if pudp.rcv() != token
				end
			rescue Timeout::Error
				return
			end
		end
	end
end

#protocol procedure state machine
#this is the real meat of OOB communication: 
#procedure files (e.g. INFO.rb, HP0.rb) return
#an instance of ProtoProc with callbacks 
#defined based on the current state. the 
#callbacks return the state to transition to
#(or no transition).
class ProtoProc

	#the state machine has terminated if it has
	#reached one of these states
	TERMINAL_STATES = [
		:failure, 
		:success, 
		:proto_error,
		:std_err,
		:timeout
	]

	#the initial state
	RESERVED_STATES = [
		:init, 
	]

	attr_reader :state

	def initialize(ctx, *args)
		@ctx = ctx
		@state = :start
		@state_mtx = Mutex.new
		
		#callbacks for entry into a state
		@on_entry = {}
		#callbacks for a message recieved while in 
		#a given state.
		@on_recv = {}

		@log = Netbat::LOG
		@history = []
		@peer_timeout = 9 #seconds
		
		args.each do |arg|
			next if !arg.is_a?(Hash)
			arg.each do |k,v|
				case k
				when :peer_timeout
					@peer_timeout = v
				end
			end
		end

		update_last_transition()
	end

	def update_last_transition
		@last_transition = Time.now.to_i
	end

	def on_entry(state, &bloc)
		@on_entry[state] = bloc
	end

	def init(&bloc)
		on_entry(:init, &bloc)
	end

	def on_recv(state, &bloc)
		@on_recv[state] = bloc
	end

	def on_success(&bloc)
		on_recv(:success, &bloc)
	end

	#transition to :next, store some user data as :user
	Transition = Struct.new(:next, :user)
	#on_recv callbacks can return this to 
	#signifiy that no transition should take
	#place
	NullTransition = :null_transition

	def trans_null()
		return NullTransition
	end

	#create a transition to state and save the user data
	def trans(state, user=nil)
		return Transition.new(state, user)
	end

	def success(output)
		return trans(:success, output)
	end

	def failure(msg)
		return trans(:failure, msg)
	end

	def proto_error(msg)
		return trans(:proto_error, msg)
	end

	def std_err(e)
		return trans(:std_err, e)
	end
	
	def timeout(msg)
		return trans(:timeout, Timeout.new(msg))
	end

	#must have a lock on @state in this function
	def terminated?
		return TERMINAL_STATES.include?(@state)
	end

	def on_terminate(&bloc) 
		@on_terminate = bloc
	end

	#lock the state variable
	def state_lock(&bloc)
		@state_mtx.synchronize do 
			bloc.call()
		end
	end

	#dispatch a received message to a 
	#function in the on_recv table
	def recv(msg)
		@state_mtx.synchronize do
			if !terminated? && @on_recv.key?(@state)
				result = instance_exec(msg, &@on_recv[@state])

				if result != NullTransition
					if !result.is_a?(Transition)
						raise "expected a transition object from callback"	
					end

					make_transition(result)
				end
			else
				@log.info "dropped msg: #{msg.inspect}"
			end
		end
	end

	def send_msg(msg)
		@ctx.send_msg(msg)
	end

	#must have a lock on @state while in this function
	def run_on_entry()
		if @on_entry.key?(@state)
			instance_exec(&@on_entry[@state])
		end
	end

	#must have a lock on @state while in this function
	def run_on_terminate()
		if @on_terminate
			instance_exec(&@on_terminate)
		end
	end

	#save tr in the transition history, set the @state
	#variable, run on_entry callbacks, update the 
	#idle timer
	#must have a lock on @state while in this function
	def make_transition(tr)
		return if tr == NullTransition
		@history << tr
		@log.debug "transition: #{@state} => #{tr.next}"
		raise "invalid state: #{@state.inspect}" if !@state.is_a?(Symbol)
		raise "invalid state: #{tr.next.inspect}" if !tr.next.is_a?(Symbol)
		raise "invalid transition from #{@state}" if terminated?
		@state = tr.next
		run_on_entry()
		update_last_transition()
		run_on_terminate() if terminated?
	end

	class ProtoProcException < Exception; end
	class ProtocolFailed < ProtoProcException; end

	class StandardException < ProtoProcException; end
	class ProcedureFailed < StandardException; end
	class Timeout < StandardException; end
	class PeerUnavailable < StandardException; end

	#check the status of the procedure and return the result
	#if the procedure was successful. throw an appropriate
	#exception if the procedure has failed.
	def status()
		#dont need to lock here b.c. if @state is one of these we are terminated
		case @state
		when :success
			return @history.last.user
		when :failure
			raise ProcedureFailed.new, @history.last.user
		when :proto_error
			raise ProtocolFailed.new, @history.last.user
		when :std_err, :timeout
			raise @history.last.user
		end

		if (Time.now.to_i - last_activity()) > @peer_timeout
			@state_mtx.synchronize do 
				#make sure its still true
				if (Time.now.to_i - @last_transition) > @peer_timeout
					make_transition(timeout("peer timeout exceeded"))
				end
			end
		end
		update()

		return nil
	end

	def last_activity()
		return @last_transition
	end

	def update()
		#nothing
	end

	def startup()
		if @state != :start
			raise "current state is not :start"
		end

		@state_mtx.synchronize do
			make_transition(trans(:init))
		end
	end

	def run()
		startup()

		#loop until successful (failure will raise an exception)
		loop do 
			sleep(0.1)

			result = status()
			return result if !result.nil?
		end		
	end

end



end #Netbat