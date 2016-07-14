module Neets; end


class Neets::RpcSignaller
    include ::Orchestrator::Constants


    descriptive_name 'Neets to ACA bridge'
    generic_name :Signals

    default_settings({
        tcp_port: 24842,
        neet_lookup: {
            "172.0.0.1": "Display_1"
        },
        volume_increment: 5
    })

    implements :logic


    module SignalServer
        def post_init(logger, thread, mod)
            @logger = logger
            @thread = thread
            @mod = mod
            @buffer = ::UV::BufferedTokenizer.new({
                delimiter: '$',
                indicator: '^'
            })
        end

        def on_connect(transport)
            # Someone connected (we could whitelist IPs for security)
            @ip, port = transport.peername
            logger.info "Connection from: #{@ip}:#{port}"
        end

        attr_reader :logger, :thread, :mod
    
        def on_read(data, *args)
            begin
                @buffer.extract(data).each do |request|
                    logger.debug { "recieved request #{request}" }
                    cmd, value = request.split(' ')
                    mod.process(@ip, cmd, value)
                end
            rescue => e
                logger.print_error(e, "error extracting data from: #{data.inspect} in receive_data callback")
            end
        end
    end


    def on_load
        on_update
    end

    def on_update
        # Pull in IP address to Device mappings
        # {"ip.address": "Module_1"}
        @neet_lookup = setting(:neet_lookup) || {}
        @volume_increment = setting(:volume_increment) || 5

        # Ensure server is stopped
        on_unload

        port = setting(:tcp_port) || 24842
        @server = UV.start_server "0.0.0.0", port, SignalServer, logger, thread, self

        logger.info "DHL signal server started"
    end

    def on_unload
        if @server
            @server.close
            @server = nil

            # Stop the server if started
            logger.info "Neets server stopped"
        end
    end

    def process(ip, cmd, request)
        mod = @neet_lookup[ip]

        if mod
            display = system.get_implicit(mod)

            case cmd.to_sym
            when :input
                display.power(true)
                display.switch_to(request)
            when :power
                display.power(false)
            when :volume
                vol = (display[:volume] || 0)

                # NOTE:: down is up and up is down
                # This was a work around for incorrect labeling!!!!
                if request == 'down'
                    display.volume(vol + @volume_increment)
                else
                    display.volume(vol - @volume_increment)
                end
            end

        else
            logger.info "Received command from unknown IP #{ip}"
        end
    end
end

