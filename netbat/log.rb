require 'logger'

module Netbat

	def self.ansi_color(str, code)
		return "\e[#{code}m#{str}\e[0m"
	end

	def self.ansi_yellow(str)
		return ansi_color(str, 33)
	end

	LOG = Logger.new($stdout)
	LOG.formatter = proc do |sev, t, pname, msg|
		sprintf "#{sev[0..0]}#{ansi_yellow("[%s]::")} %s\n", t.strftime("%y-%m-%d %H:%M:%S"), msg
	end

end