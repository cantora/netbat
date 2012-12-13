

module Netbat

module Netif
	#/usr/include/linux/sockios.h
	#/usr/include/linux/if.h
	IF_NAMESIZE 	= 16
	SIZEOF_SOCKADDR	= 16
	IFREQ_PACK_FMT 	= 'a16a16'

	SIOCGIFNAME		= 0x8910
	SIOCSIFNAME		= 0x8923
	SIOCGIFFLAGS	= 0x8913
	SIOCSIFFLAGS	= 0x8914
	SIOCGIFADDR		= 0x8915
	SIOCSIFADDR		= 0x8916
	SIOCGIFNETMASK	= 0x891b
	SIOCSIFNETMASK	= 0x891c
	SIOCGIFMTU		= 0x8921
	SIOCSIFMTU		= 0x8922

	IFF_UP			= 0x1	
	IFF_RUNNING 	= 0x40
	
	def self.pack(ifname, arg="")
		#puts [ifname, arg].inspect
		result = [ifname, arg].pack(IFREQ_PACK_FMT)
		#puts result.inspect
		return result
	end

	def self.result_arg(buf)
		#puts buf.inspect
		return buf[16..31]
	end

	def self.get_name(fd)
		buf = pack("")
		fd.ioctl(SIOCGIFNAME, buf )

		return buf[0..16].gsub(/\x00/, "")
	end

	def self.set_name(ifname, fd, new_name)
		fd.ioctl(SIOCSIFNAME, pack(ifname, new_name) )
	end

	def self.get_addr(ifname, fd)
		buf = pack(ifname) 
		fd.ioctl(SIOCGIFADDR, buf)
		
		return result_arg(buf)
	end

	def self.set_addr(ifname, fd, sin)
		fd.ioctl(SIOCSIFADDR, pack(ifname, sin) )
	end

	def self.get_mtu(ifname, fd)
		buf = pack(ifname) 
		fd.ioctl(SIOCGIFMTU, buf)
		
		return result_arg(buf[0..3])
	end

	def self.set_mtu(ifname, fd, mtu)
		fd.ioctl(SIOCSIFMTU, pack(ifname, [mtu].pack("L") ) )
	end

	def self.get_mask(ifname, fd)
		buf = pack(ifname) 
		fd.ioctl(SIOCGIFNETMASK, buf)
		
		return result_arg(buf)
	end

	def self.set_mask(ifname, fd, mask)
		sin = Socket.sockaddr_in(0, [~((2**32-1) >> mask)].pack("N").unpack("CCCC").join(".") )
		fd.ioctl(SIOCSIFNETMASK, pack(ifname, sin) )
	end

	def self.get_flags(ifname, fd)
		buf = pack(ifname)
		fd.ioctl(SIOCGIFFLAGS, buf)
		result_arg(buf)[0..1].unpack("S").first
	end

	def self.set_flags(ifname, fd, flags)
		uint16 = [flags].pack("S")
		fd.ioctl(SIOCSIFFLAGS, pack(ifname, uint16) )
	end

	def self.or_flags(ifname, fd, flags)
		set_flags(ifname, fd, get_flags(ifname, fd) | flags)
	end

	def self.get_up(ifname, fd)
		return get_flags(ifname, fd) & IFF_UP
	end

	def self.set_up(ifname, fd)
		return or_flags(ifname, fd, IFF_UP)
	end

	class Base
		def initialize(fd, name)
			@fd = UDPSocket.new
			@name = name
		end

		def describe
			s = "#{@name}(\n"
			attrs = ["addr", "mask"].each do |attr|
				s << "\t#{attr}: #{self.send("get_#{attr}".to_sym).inspect}\n"
			end
			
			s << "\tflags: #{self.get_flags().to_s(2)}\n"
			s << ")"
			return s
		end
	
		def method_missing(m, *args, &bloc)
			case m.to_s
			when /^get_/
				return Netif::send(m, @name, @fd)
			when /^set_/
				return Netif::send(m, @name, @fd, *args)
			else
				super(m, *args, &bloc)
			end
		end
	end

end

end #Netbat