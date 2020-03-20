require "socket"
require "option_parser"

def exchange_bytes(io1, io2)
  puts " exchange_byte #{io1} #{io2} entered"
  io1.read_timeout = 1
  io2.write_timeout = 1
  io2.sync = true
  until io1.closed? || io2.closed?
    begin
      b = io1.read_byte
      if b.nil?
        #puts "-> read failed on #{io1}"
        io1.close
        io2.close
        return
      end
      #puts "-> read byte from #{io1}"
      io2.write_byte b
      #puts "-> write byte to  #{io2}"
    rescue e: IO::Timeout | IO::Error
    rescue e: Errno
      io1.close
      io2.close
    end
  end
  puts " exchange_byte #{io1} #{io2} done"
end

upstream_host = "localhost"
upstream_port = 10080
listen_host = "localhost"
listen_port = 10081

OptionParser.parse do |parser|
  parser.banner = "Usage: tcp-single-proxy [arguments]"
  parser.on("--upstream-host HOST", "Upstream server host to connect to") {|uh| upstream_host = uh}
  parser.on("--upstream-port PORT", "Upstream server port to connect to") {|up| upstream_port = up.to_i}
  parser.on("--listen-host HOST", "Address to listen on") {|lh| listen_host = lh}
  parser.on("--listen-port PORT", "Port to listen on") {|lp| listen_port = lp.to_i}
  parser.invalid_option do |flag|
    STDERR.puts "Error: #{flag} is not a valid option"
    exit 1
  end
end

puts "tcp-single-proxy"
puts "Upstream at #{upstream_host}:#{upstream_port}"
puts "Listening on #{listen_host}:#{listen_port}"

server = TCPServer.new listen_host, listen_port

loop do
  server.accept do |client|
    puts "accepting new #{client}"
    begin
      upstream = TCPSocket.new upstream_host, upstream_port
      puts "opened upstream connection #{upstream}"

      spawn exchange_bytes(client, upstream)
      spawn exchange_bytes(upstream, client)
      until client.closed? || upstream.closed?
        sleep 0.1
      end
    rescue e: Errno
      puts e
    end
    puts "done with #{client}"
  end
end
