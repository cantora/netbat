require 'netbat/log'
require 'netbat/datagram/socket'

require 'blather/client/client'
require 'uri'

module Netbat::Datagram

class XMPPSocket < Socket
	attr_reader :password

	def initialize(uri)
		assert_uri(uri)

		@user = uri.user
		@password = uri.password
		@domain = uri.host
		@resource = uri.path
		{:user => @user, :password => @password, :domain => @domain}.each do |k,v|
			raise ArgumentError.new, "invalid #{k} in uri: #{v.inspect}" if v.nil? || v.empty?
		end

		@client = nil
		@thr = nil
		@log = Netbat::LOG

	end

	def client_handler(*args, &bloc)
		#blather doesnt handle the case where 
		#we clear a handler when it doesnt exist yet, and i 
		#dont see a way to test for existence of a handler in the API.
		#thus we have to create one, then delete all, then create one
		@client.register_handler(*args, &bloc)

		@client.clear_handlers(*args)
		@client.register_handler(*args, &bloc)
	end

	def init_client
		@client = Blather::Client.setup(self.xmpp_id, @password)
		client_handler :subscription, :request? do |s|
			@log.debug("subsc(#{self.xmpp_id}):#{s.inspect}")
			s.approve!
		end

		on_recv {}
		on_bind {}
		on_close {}
	end

	def xmpp_id
		return File.join("#{@user}@#{@domain}", @resource)
	end

	def on_recv(&bloc)
		client_handler(:message, :chat?, :body) do |m|
			@log.debug("recv(#{self.xmpp_id}):#{m.from.inspect}, #{m.body.inspect}")
			bloc.call(
				m.body, 
				Socket::Addr.new(m.from)
			)
		end
	end

	def on_subscription(&bloc)
		raise "not implemented"
	end

	def bound?
		return !@thr.nil?
	end

	def bind
		raise "endpoint is already bound!" if !@thr.nil?

		init_client()
		@thr = Thread.new do
			Thread.current.abort_on_exception = true
			EventMachine.run { 
				@client.run
			}
		end
	end

	def on_bind(&bloc)
		client_handler(:ready) do
			@log.debug("bound(#{self.xmpp_id})")
			@client.status = :available
			bloc.call()
		end
	end

	def close
		raise "endpoint not bound" if @thr.nil?
		
		@log.debug "unbind"
		if @client.connected?
			@log.debug "close client (status = #{@client.status.inspect})"
			@client.close 
		else
			@log.debug "client not setup, kill thread"
			@thr.kill
		end

		@log.debug "join thread"
		@thr.join
		@log.debug "thread dead"
		@client = nil
		@thr = nil
	end

	def on_close(&bloc)
		client_handler(:disconnected) do
			@log.debug("closed(#{self.xmpp_id})")
			bloc.call()
		end
	end
end

end #Netbat::Datagram