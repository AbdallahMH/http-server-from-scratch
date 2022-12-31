require "socket"
require "active_support/all"
require_relative "request"
require_relative "response"

require "rack"
require "rack/lobster"

APP = Rack::Lobster.new

port = ENV.fetch("PORT", 2000).to_i
server = TCPServer.new 2000

puts "listening on port #{port}..."

def render(file:)
  body = File.binread(file)
  Response.new(
    code: 200,
    body: body,
    headers: {
      "Content-Length" => body.bytesize,
      "Content-Type" => "text/html",
    })
end

def template_exists?(path)
  File.exists?(path)
end

def route(request)
  path = (request.path == "/") ? "index.html" : request.path
  full_path = File.join(__dir__, "views", path)

  if template_exists?(full_path)
    render file: full_path
  else
    status, headers, body = APP.call({
                                       "REQUEST_METHOD" => request.method,
                                       "PATH_INFO" => request.path,
                                       "QUERY_STRING" => request.query,
                                     })

    Response.new(code: status, body: body.join, headers: headers)
  end
rescue => e
  puts e.full_message
  Response.new(code: 500)
end

loop do
  Thread.start(server.accept) do |client|
    request = Request.new client.readpartial(2048)
    response = route(request)
    response.send(client)
    client.close
  end
end