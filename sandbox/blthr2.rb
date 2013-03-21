require 'rubygems'
require 'blather/client/client'
require 'blather/client/dsl/pubsub'
require 'blather'

EventMachine.run {
  host = 'jabber.org'
  user = 'ulyuly@jabber.org'
  pass = 'pass'

  jid = Blather::JID.new(user)
  client = Blather::Client.setup(jid, pass)
  client.register_handler(:ready) {
    puts "Connected. Send messages to #{client.jid.inspect}."
    pub = Blather::DSL::PubSub.new(client, host)
  }

  client.register_handler(:pubsub_event) { |event|
    puts event
  }

  client.connect
}

