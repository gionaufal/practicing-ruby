# TODO:
# According to the HTTP 1.1 specification, a server must minimally respond to GET and HEAD to be compliant. Implement the HEAD response.
# Add error handling that returns a 500 response to the client if something goes wrong with the request.
# Make the web root directory and port configurable.
# Add support for POST requests. You could implement CGI by executing a script when it matches the path, or implement the Rack spec to let the server serve Rack apps with call.
# Reimplement the request loop using GServer (Ruby’s generic threaded server) to handle multiple connections.


require 'socket'
require 'uri'

WEB_ROOT = './public'

CONTENT_TYPE_MAPING = {
  'html' => 'text/html',
  'txt' => 'text/txt',
  'png' => 'image/png',
  'jpg' => 'image/jpeg'
}

DEFAULT_CONTENT_TYPE = 'application/octet-stream'

def content_type(path)
  ext = File.extname(path).split(".").last
  CONTENT_TYPE_MAPING.fetch(ext, DEFAULT_CONTENT_TYPE)
end

def requested_file(request_line)
  request_uri = request_line.split(" ")[1]
  path        = URI.unescape(URI(request_uri).path)

  clean = []

  parts = path.split("/")

  parts.each do |part|
    next if part.empty? || part == '.'

    part == '..' ? clean.pop : clean << part
  end

  File.join(WEB_ROOT, *clean)
end

server = TCPServer.new('localhost', 2345)

loop do
  socket       = server.accept
  request_line = socket.gets

  STDERR.puts request_line

  path = requested_file(request_line)
  path = File.join(path, 'index.html') if File.directory?(path)

  if File.exist?(path) && !File.directory?(path)
    File.open(path, "rb") do |file|
      socket.print "HTTP/1.1 200 OK\r\n" +
                   "Content-Type: #{content_type(file)}\r\n" +
                   "Content-Length: #{file.size}\r\n" +
                   "Connection: close\r\n"

      socket.print "\r\n"

      IO.copy_stream(file, socket)
    end
  else
    message = "File not found\n"

    socket.print "HTTP/1.1 404 Not Found\r\n" +
      "Content-Type: text/plain\r\n" +
      "Content-Length: #{message.size}\r\n" +
      "Connection: close\r\n"

    socket.print "\r\n"

    socket.print message
  end

  socket.close
end
