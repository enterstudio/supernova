require 'socket'

module Supernova
  module Starbound

    # A Starbound server.
    #
    # @todo Default proc.
    class Server

      # The default block for listening to connections.
      #
      # @return [Proc]
      def self.for_client(&block)
        if block_given?
          @block = block
        else
          @block ||= proc {}
        end
      end

      # The options passed to the server on initialization.
      #
      # @return [Hash]
      attr_reader :options

      # The default options.
      DEFAULT_OPTIONS = {
        :type  => :tcp,
        :host  => "127.0.0.1",
        :port  => 2010,
        :path  => "/tmp/sock"
      }

      # Whether or not to run.  Once this is set to false, the server
      # stops listening for clients.
      #
      # @return [Boolean]
      attr_accessor :run

      # The list of active threads that are running.
      #
      # @return [Array<Thread>]
      attr_reader :thread_list

      # Initialize the server with the given options.  If the options
      # has a +:protocol+ key, it is removed from the options and set
      # as the protocol options.
      #
      # @param options [Hash]
      # @option options [Symbol] :type the type of server.  Can be any
      #   of +:tcp+ or +:unix+.  Defaults to +:tcp+.
      # @option options [String] :host the host to bind to.  Defaults
      #   to +"127.0.0.1"+.  Only used if +:type+ is +:tcp+.
      # @option options [Numeric] :port the port to bind to.  Defaults
      #   to +2010+.  Only used if +:type+ is +:tcp+.
      # @option options [String] :path the path to the unix socket.
      #   Only used if +:type+ is +:unix+.
      def initialize(options = {})
        @options = DEFAULT_OPTIONS.merge options
        @protocol_options = (options.delete(:protocol) || {}).dup
        @run = true
        @thread_list = []
        @protocols = []
      end

      # Listen for clients.  Uses the given block to yield to when a
      # client is found.
      #
      # @yieldparam protocol [Protocol] the protocol instance that is
      #   used for the client.
      def listen(&block)
        block ||= self.class.for_client
        Supernova.logger.info { "Server started." }
        while run
          next unless IO.select [server], nil, nil, 1
          thread_list << Thread.start(server.accept) do |client|
            Supernova.logger.info { "Client accepted." }
            begin
              protocol = Protocol.new(
                @protocol_options.merge(:type => :server))

              @protocols << protocol

              protocol.socket = client
              protocol.handshake

              block.call(protocol)
            rescue ExitError => e
              Supernova.logger.error { "Closing while client is connected.  Notifying..." }
              if protocol
                protocol.close(:shutdown)
              else
                client.close unless client.closed?
              end
            rescue RemoteCloseError
            rescue ProtocolError => e
              Supernova.logger.error { "Client failed: #{e.message} #{e.backtrace.join("\n")}" }
              client.close unless client.closed?
            end

            thread_list.delete(Thread.current)
            Supernova.logger.info { "Client disconnected." }
            protocol.close(false)
          end
        end
      end

      # Shuts down the server.
      #
      # @return [void]
      def shutdown
        puts "shutting down"
        @run = false
        thread_list.each do |thread|
          thread.raise ExitError
        end
      end

      # Returns the server type that this server should run as,
      # already instantized.
      #
      # @return [Object]
      def server
        @_server ||= case options.fetch(:type, :tcp)
        when :tcp
          TCPServer.new options.fetch(:host, "127.0.0.1"),
            options.fetch(:port, 2010)
        when :unix
          UNIXServer.new options.fetch(:path)
        when :pipe
          FakeServer.new options.fetch(:pipe)
        end
      end

      # A fake server that wraps a pipe.
      class FakeServer

        # Initialize the fake server with the pipe.
        def initialize(pipe)
          @pipe = pipe
        end

        # Does nothing.
        def listen(_); end

        # Returns the pipe.
        #
        # @return [Object]
        def accept
          @pipe
        end
      end

    end
  end
end
