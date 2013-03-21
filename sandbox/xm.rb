require 'xmpp4r/client'
include Jabber

puts "asdfasdfasdfasdf"
client = Client.new(JID::new("ujijigo@jabber-0-1.virt.iitsp.net"))
client.connect
client.auth("pass")
puts "auth done"
client.send(Presence.new.set_type(:available))


client.close
