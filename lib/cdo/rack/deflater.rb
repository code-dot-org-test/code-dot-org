require 'rack/deflater'
# Deflater Middleware backported from Rack 1.6 master
# See: https://github.com/rack/rack/blob/master/lib/rack/deflater.rb
require "zlib"
require "time"  # for Time.httpdate
require 'rack/utils'

module Rack
  # This middleware enables compression of http responses.
  #
  # Currently supported compression algorithms:
  #
  #   * gzip
  #   * deflate
  #   * identity (no transformation)
  #
  # The middleware automatically detects when compression is supported
  # and allowed. For example no transformation is made when a cache
  # directive of 'no-transform' is present, or when the response status
  # code is one that doesn't allow an entity body.
  class Deflater
    ##
    # Creates Rack::Deflater middleware.
    #
    # [app] rack app instance
    # [options] hash of deflater options, i.e.
    #           'if' - a lambda enabling / disabling deflation based on returned boolean value
    #                  e.g use Rack::Deflater, :if => lambda { |env, status, headers, body| body.length > 512 }
    #           'include' - a list of content types that should be compressed
    def initialize(app, options = {})
      @app = app

      @condition = options[:if]
      @compressible_types = options[:include]
    end

    def call(env)
      status, headers, body = @app.call(env)
      headers = Utils::HeaderHash.new(headers)

      unless should_deflate?(env, status, headers, body)
        return [status, headers, body]
      end

      request = Request.new(env)

      encoding = Utils.select_best_encoding(
        %w(gzip deflate identity),
        request.accept_encoding
      )

      # Set the Vary HTTP header.
      vary = headers["Vary"].to_s.split(",").map(&:strip)
      unless vary.include?("*") || vary.include?("Accept-Encoding")
        headers["Vary"] = vary.push("Accept-Encoding").join(",")
      end

      case encoding
      when "gzip"
        headers['Content-Encoding'] = "gzip"
        headers.delete('Content-Length')
        mtime = headers.key?("Last-Modified") ?
          Time.httpdate(headers["Last-Modified"]) : Time.now
        [status, headers, GzipStream.new(body, mtime)]
      when "deflate"
        headers['Content-Encoding'] = "deflate"
        headers.delete('Content-Length')
        [status, headers, DeflateStream.new(body)]
      when "identity"
        [status, headers, body]
      when nil
        message = "An acceptable encoding for the requested resource #{request.fullpath} could not be found."
        bp = Rack::BodyProxy.new([message]) {body.close if body.respond_to?(:close)}
        [406, {'Content-Type' => "text/plain", 'Content-Length' => message.length.to_s}, bp]
      end
    end

    class GzipStream
      def initialize(body, mtime)
        @body = body
        @mtime = mtime
        @closed = false
      end

      def each(&block)
        @writer = block
        gzip = ::Zlib::GzipWriter.new(self)
        gzip.mtime = @mtime
        @body.each do |part|
          gzip.write(part)
          gzip.flush
        end
      ensure
        gzip.close
        @writer = nil
      end

      def write(data)
        @writer.call(data)
      end

      def close
        return if @closed
        @closed = true
        @body.close if @body.respond_to?(:close)
      end
    end

    class DeflateStream
      DEFLATE_ARGS = [
        Zlib::DEFAULT_COMPRESSION,
        # drop the zlib header which causes both Safari and IE to choke
        -Zlib::MAX_WBITS,
        Zlib::DEF_MEM_LEVEL,
        Zlib::DEFAULT_STRATEGY
      ].freeze

      def initialize(body)
        @body = body
        @closed = false
      end

      def each
        deflator = ::Zlib::Deflate.new(*DEFLATE_ARGS)
        @body.each {|part| yield deflator.deflate(part, Zlib::SYNC_FLUSH)}
        yield deflator.finish
      ensure
        deflator.close
      end

      def close
        return if @closed
        @closed = true
        @body.close if @body.respond_to?(:close)
      end
    end

    private def should_deflate?(env, status, headers, body)
      # Skip compressing empty entity body responses and responses with
      # no-transform set.
      if Utils::STATUS_WITH_NO_ENTITY_BODY.include?(status) ||
        headers['Cache-Control'].to_s =~ /\bno-transform\b/ ||
        (headers['Content-Encoding'] && headers['Content-Encoding'] !~ /\bidentity\b/)
        return false
      end

      # Skip if @compressible_types are given and does not include request's content type
      return false if @compressible_types && !(headers.key?('Content-Type') && @compressible_types.include?(headers['Content-Type'][/[^;]*/]))

      # Skip if @condition lambda is given and evaluates to false
      return false if @condition && !@condition.call(env, status, headers, body)

      true
    end
  end
end
