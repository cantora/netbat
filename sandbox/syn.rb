#!/usr/bin/env ruby
require 'racket'
require 'socket'
require 'system/getifaddrs'

eth0 = System.get_ifaddrs[:eth0]

n = Racket::Racket.new
n.iface = "eth0"

n.l3 = Racket::L3::IPv4.new
n.l3.src_ip = eth0[:inet_addr]
n.l3.dst_ip = "74.125.142.101"
n.l3.protocol = 0x6
n.l3.ttl = 255
n.l4 = Racket::L4::TCP.new
n.l4.src_port = 48484
n.l4.seq = 0
n.l4.flag_syn = 1
n.l4.dst_port = 80
n.l4.window = 4445

n.l4.fix!(n.l3.src_ip, n.l3.dst_ip, "")

f = n.sendpacket
n.layers.compact.each do |l|
  puts l.pretty
end
puts "Sent #{f}"
