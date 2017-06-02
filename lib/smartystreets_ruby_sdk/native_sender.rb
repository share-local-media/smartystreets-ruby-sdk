require 'net/http'
require_relative 'version'
require_relative 'response'

class NativeSender
  def initialize(max_timeout = 10_000, proxy = nil)
    @max_timeout = max_timeout
    @proxy = proxy
  end

  def send(smarty_request)
    request = self.class.build_request(smarty_request)

    begin
      http = build_http(request)
      http.use_ssl = true
      http.ssl_version = :TLSv1_2
      http.read_timeout = @max_timeout

      response = http.request(request)

      http.finish if http.started?
    rescue StandardError => err
      return Response.new(nil, nil, err)
    end

    build_smarty_response(response)
  end

  def self.build_request(smarty_request)
    query = create_query(smarty_request)

    if smarty_request.payload.nil?
      request = Net::HTTP::Get.new(URI.parse("#{smarty_request.url_prefix}?#{query}"))
    else
      request = Net::HTTP::Post.new(URI.parse("#{smarty_request.url_prefix}?#{query}"))
    end

    request.content_type = 'application/json'
    request.body = smarty_request.payload
    request['User-Agent'] = "smartystreets (sdk:ruby@#{SmartystreetsRubySdk::VERSION})"
    request['Referer'] = smarty_request.referer unless smarty_request.referer.nil?
    set_custom_headers(smarty_request.headers, request)
    request
  end

  def build_smarty_response(native_response)
    Response.new(native_response.body, native_response.code)
  end

  def build_http(request)
    uri = request.uri

    if @proxy.nil?
      http = Net::HTTP.new(uri.hostname, uri.port)
    else
      http = Net::HTTP.new(uri.hostname, uri.port, @proxy.host,
                           @proxy.port, @proxy.username, @proxy.password)
    end

    http
  end

  def self.create_query(smarty_request)
    query_string = ''

    smarty_request.parameters.each do |key, value|
      query_string.concat("&#{key}=#{value}")
    end

    query_string[0] = ''
    query_string
  end

  def self.set_custom_headers(smarty_headers, request)
    smarty_headers.each do |key, values|
      values.each do |value|
        request.add_field(key, value)
      end
    end
  end
end