module Meeting; end


class Meeting::Universal
    include ::Orchestrator::Constants


    def on_load
        on_update

        # Shutdown schedule
        # Every night at 11:30pm shutdown the systems if they are on
        schedule.cron(setting(:shutdown_time) || '30 23 * * *') do
            shutdown
        end
    end

    def on_update
        self[:name] = system.name
        self[:help_msg] = setting(:help_msg)

        # Pod sharing settings
        @always_share = !!setting(:always_share)
        self[:Presenter_hide] = self[:Presenter_hide] ? !@always_share : false

        # Grab the input list
        @input_tab_mapping = {}             # Used in POD sharing code
        self[:inputs] = setting(:inputs)
        self[:inputs].each do |input|
            self[input] = setting(input)
            (self[input] || []).each do |source|
                @input_tab_mapping[source.to_sym] = input
            end
        end

        # Grab the list of inputs and outputs
        self[:sources] = setting(:sources)
        self[:outputs] = setting(:outputs)
        self[:mics] = setting(:mics)
        @sharing_output = self[:outputs].keys.first

        # Grab lighting presets
        self[:lights] = setting(:lights)
        @light_mapping = {}
        if self[:lights]
            if self[:lights][:levels]
                self[:lights][:levels].each do |level|
                    @light_mapping[level[:name]] = level[:trigger]
                    @light_mapping[level[:trigger]] = level[:name]
                end
            end

            @light_default = self[:lights][:default]
            @light_present = self[:lights][:present]
            @light_shutdown = self[:lights][:shutdown]
            @light_group = setting(:lighting_group)
        end

        # Check for min / max volumes
        self[:vol_max] = setting(:vol_max) || 100  # Set to 3
        self[:vol_min] = setting(:vol_min) || 0    # Set to -50

        # Get the list of apps and channels
        @apps = setting(:apps)
        @channels = setting(:channels)
        @cameras = setting(:cameras)
        self[:has_preview] = setting(:has_preview)
        self[:pc_control] = system.exists?(:Computer)
        self[:apps] = @apps.keys if @apps
        self[:channels] = @channels.keys if @channels
        self[:cameras] = @cameras.keys if @cameras

        # Get any default settings
        @defaults = setting(:defaults) || {}
    end


    #
    # SOURCE SWITCHING
    #

    # The current tab being viewed
    def tab(tabid)
        self[:tab] = tabid.to_sym
    end

    def preview(source)
        if self[:has_preview]
            disp_source = self[:sources][source.to_sym]
            preview_input = disp_source[:preview] || disp_source[:input]

            system[:Switcher].switch({preview_input => self[:has_preview]})
        end
    end

    def present(source, display)
        display = (display || :all_displays).to_sym
        source = source.to_sym
        
        if display == :all_displays
            self[:outputs].each_key do |key|
                show(source, key)
            end
            self[:all_displays] = {
                source: source
            }
        else
            show(source, display)
            self[:all_displays] = {
                source: :none
            }
        end

        if !@lights_set && @light_present
            # Task 4: If lighting is available then we may want to update them
            lights_to(@light_present)
        end
    end


    #
    # SOURCE MUTE AND AUDIO CONTROL
    #

    # Mutes both the display and audio
    # Unmute is performed by source switching
    def video_mute(display)
        display = display.to_sym
        disp_mod = system.get_implicit(display)
        
        disp_info = self[:outputs][display]
        unless disp_info[:output].nil? 
            system[:Switcher].switch({0 => disp_info[:output]})
        end

        # Source switch will unmute some projectors
        if disp_mod.respond_to?(:mute)
            @would_mute = schedule.in(300) do
                @would_mute = nil
                disp_mod.mute
            end
        end

        # Remove the indicator icon
        self[display] = {
            source: :none
        }
    end


    # Helpers for all display audio
    def global_mute(val)
        mute = is_affirmative?(val)
        self[:master_mute] = mute
        self[:outputs].each do |key, value|
            if value[:no_audio].nil?
                mixer_id = value[:mixer_id]
                mixer_index = value[:mixer_mute_index] || value[:mixer_index] || 1

                system[:Mixer].mute(mixer_id, mute, mixer_index)
            end
        end
    end

    def global_vol(val)
        val = in_range(val, self[:vol_max], self[:vol_min])
        self[:master_volume] = val
        self[:outputs].each do |key, value|
            if value[:no_audio].nil?
                mixer_id = value[:mixer_id]
                mixer_index = value[:mixer_index] || 1

                system[:Mixer].fader(mixer_id, val, mixer_index)
            end
        end
    end



    #
    # SHUTDOWN AND POWERUP
    #

    def powerup
        # Keep track of displays from neighboring rooms
        @setCamDefaults = true

        # cancel any delayed shutdown events

        # Turns on audio if off (audio driver)
        # Triggers PDU

        # Turns on lights
        if @light_default
            lights_to(@light_default)
            @lights_set = false
        end


        self[:tab] = self[:inputs][0]
        self[:state] = :online
        wake_pcs


        # Is there a single display in that rooms?
        disp = system.get(:Display, 2)
        default_source = setting(:default_source)
        if disp.nil? && default_source
            present(default_source, self[:outputs].keys[0])
        end


        # defaults = {
            # routes: {input: [outputs]}
            # levels: {fader_id: [level, muted]}
        #}
        sys = system
        sys[:Switcher].switch(@defaults[:routes]) if @defaults[:routes]

        mixer = sys[:Mixer]

        if @defaults[:on_preset]
            mixer.preset(@defaults[:on_preset])

        else
            # Output levels and mutes
            level = @defaults[:output_level]
            self[:outputs].each do |key, value|
                if value[:no_audio].nil? && value[:mixer_id]
                    args = {}
                    args[:ids] = value[:mute_id] || value[:mixer_id]
                    args[:muted] = false
                    args[:index] = value[:mixer_mute_index] || value[:mixer_index] if value[:mixer_mute_index] || value[:mixer_index]
                    args[:type] = value[:mixer_type] if value[:mixer_type]
                    mixer.mutes(args)

                    new_level = value[:default_level] || level
                    if new_level
                        args = {}
                        args[:ids] = value[:mixer_id]
                        args[:level] = new_level
                        args[:index] = value[:mixer_index] if value[:mixer_index]
                        args[:type] = value[:mixer_type] if value[:mixer_type]
                        mixer.faders(args)
                    end
                end
            end

            # Mic levels and mutes
            if self[:mics]
                level = @defaults[:mic_level]
                self[:mics].each do |mic|
                    new_level = mic[:default_level] || level

                    args = {}
                    args[:ids] = mic[:mute_id] || mic[:id]
                    args[:muted] = false
                    args[:index] = mic[:index] if mic[:index]
                    args[:type] = mic[:type] if mic[:type]
                    mixer.mutes(args)

                    if new_level
                        args = {}
                        args[:ids] = mic[:id]
                        args[:level] = new_level
                        args[:index] = mic[:index] if mic[:index]
                        args[:type] = mic[:type] if mic[:type]
                        mixer.faders(args)
                    end
                end
            end
        end

        preview(self[self[:tab]][0])
    end

    def shutdown(all = nil)
        # Shudown action on Lights
        if @light_shutdown
            lights_to(@light_shutdown)
            @lights_set = false
        end

        mixer = system[:Mixer]

        # Unroutes 
        # Turns off audio if off (audio driver)
        # Triggers PDU
        # Turns off lights after a period of time
        # Turns off other display types
        self[:outputs].each do |key, value|
            begin
                # Next if joining room
                next if value[:remote] && (self[key].nil? || self[key][:source] == :none)

                # Blank the source
                self[key] = {
                    source: :none
                }

                # Turn off display if a physical device
                if value[:no_mod].nil?
                    disp = system.get_implicit(key)
                    if disp.respond_to?(:power)
                        logger.debug "Shutting down #{key}"
                        disp.power(Off)
                    end

                    # Retract screens if one exists
                    screen_info = value[:screen]
                    unless screen_info.nil?
                        screen = system.get_implicit(screen_info[:module])
                        screen.up(screen_info[:index])
                    end
                end

                # Turn off output at switch
                outputs = value[:output]
                if outputs
                    system[:Switcher].switch({0 => outputs})
                    system[:Switcher].switch({0 => self[:has_preview]}) if self[:has_preview]
                end

                # Mute the output if mixer involved
                if @defaults[:off_preset].nil? && value[:no_audio].nil? && value[:mixer_id]
                    args = {}
                    args[:ids] = value[:mute_id] || value[:mixer_id]
                    args[:muted] = true
                    args[:index] = value[:mixer_mute_index] || value[:mixer_index] if value[:mixer_mute_index] || value[:mixer_index]
                    args[:type] = value[:mixer_type] if value[:mixer_type]
                    mixer.mutes(args)
                end

            rescue => e # Don't want to stop powering off devices on an error
                logger.print_error(e, 'Error powering off displays: ')
            end
        end

        # TODO:: PDU

        if @defaults[:off_preset]
            mixer.preset(@defaults[:off_preset])

        elsif self[:mics]
            # Mic mutes
            self[:mics].each do |mic|
                args = {}
                args[:ids] = mic[:mute_id] || mic[:id]
                args[:muted] = true
                args[:index] = mic[:index] if mic[:index]
                args[:type] = mic[:type] if mic[:type]
                mixer.mutes(args)
            end
        end

        system.all(:Computer).logoff
        system.all(:Camera).power(Off)
        system.all(:Visualiser).power(Off)

        self[:state] = :shutdown
    end


    #
    # MISC FUNCTIONS
    #
    def start_cameras
        cams = system.all(:Camera)
        cams.power(On)
        if @setCamDefaults
            cams.preset('default')
            @setCamDefaults = false
        end
    end

    def wake_pcs
        system.all(:Computer).wake(setting(:broadcast))
    end


    def application(app, comp)
        source = self[:sources][comp.to_sym]
        system.get((source[:mod] || :Computer).to_sym, source[:index] || 1).launch_application *@apps[app.to_sym]
    end

    def channel(name, comp)
        source = self[:sources][comp.to_sym]
        command = @apps[:vlc] + ['--fullscreen', @channels[name.to_sym]]
        system.get((source[:mod] || :Computer).to_sym, source[:index] || 1).launch_application *command
    end


    def show_camera(name, comp)
        source = self[:sources][comp.to_sym]
        command = @apps[:vlc] + ['--fullscreen', "rtsp://root:aca17838@#{@cameras[name]}/axis-media/media.amp?videocodec=h264"]
        system.get((source[:mod] || :Computer).to_sym, source[:index] || 1).launch_application *command
    end


    def vc_content(outp, inp)
        vc = self[:sources][outp.to_sym]
        return unless vc[:content]
        source = self[:sources][inp.to_sym]
        system[:Switcher].switch({source[:input] => vc[:content]})
    end

    def lights_to(level)
        if level.is_a? String
            level_name = level
            level_num = @light_mapping[level]
        else
            level_num = level
            level_name = @light_mapping[level]
        end

        system[:Lighting].trigger(@light_group, level_num)
        self[:light_level] = level_name

        @lights_set = true
    end


    # -----------
    # POD SHARING (assumes single output)
    # -----------
    def do_share(value)
        current = self[@sharing_output]
        current_source = current ? self[@sharing_output][:source] : :none

        if value == true && current_source != :sharing_input
            self[:Presenter_hide] = false # Just in case
            logger.debug { "Pod changing source #{@sharing_output} - current source #{current_source}" }

            @sharing_old_source = current_source.to_sym

            present(:sharing_input, @sharing_output)
            tab :Presenter
            system[:Display].mute_audio

        elsif value == false && current_source == :sharing_input
            changing_to = @sharing_old_source == :none ? self[:sources].keys.first : @sharing_old_source
            changing_to = changing_to.to_sym
            logger.debug { "Pod reverting source #{changing_to}" }

            tab @input_tab_mapping[changing_to.to_sym]
            present(changing_to, @sharing_output)

            system[:Display].unmute_audio
        end
    end

    def enable_sharing(value)
        self[:Presenter_hide] = @always_share ? false : !value
        do_share(false) if value == false
    end


    # -------------------
    # TODO:: JOINING PODS (assumes single output)
    # -------------------



    protected


    def show(source, display)
        disp_info = self[:outputs][display]
        disp_source = self[:sources][source]


        # Task 1: switch the display on and to the correct source
        unless disp_info[:no_mod]
            disp_mod = system.get_implicit(display)

            if disp_mod[:power] == Off || disp_mod[:power_target] == Off
                arity = disp_mod.arity(:power)

                # Check if we need to broadcast to turn it on
                if setting(:broadcast) && check_arity(arity)
                    disp_mod.power(On, setting(:broadcast))
                else
                    disp_mod.power(On)
                end

                # Set default levels if it was off
                if not disp_info[:mixer_id]
                    level = disp_info[:default_level] || @defaults[:output_level]
                    disp_mod.volume level if level
                end

            elsif disp_mod.respond_to?(:mute)
                if @would_mute
                    @would_mute.cancel
                    @would_mute = nil
                end
                disp_mod.unmute if disp_mod[:mute]
            end

            if disp_source[:source] && disp_mod[:input] != disp_source[:source]
                disp_mod.switch_to(disp_source[:source])
            end

            # mute the audio if there is dedicated audio
            if disp_source[:audio_out]
                if disp_mod.respond_to?(:mute_audio)
                    disp_mod.mute_audio
                elsif disp_mod.respond_to?(:volume)
                    disp_mod.volume(disp_mod[:volume_min] || 0)
                end
            else
                disp_mod.unmute if disp_mod[:mute] # if mute status is defined
            end
        end


        # Task 2: switch the switcher if it meets the criteria below
        # -> if a switcher is available (check for module)
        # -> if the source has an input
        # -> if the display has an output
        if disp_source[:input] && disp_info[:output]
            system[:Switcher].switch({disp_source[:input] => disp_info[:output]})
        end


        # Task 3: lower the screen if this display has one
        unless disp_info[:screen].nil?
            screen = system.get_implicit(disp_info[:screen][:module])
            screen.down(disp_info[:screen][:index])
        end

        # Provide the UI with source information
        self[display] = {
            source: source,
            title: disp_source[:title],
            type: disp_source[:type]
        }
    end


    # Checks if the display support broadcasting power on
    def check_arity(arity)
        arity >= 2 || arity < 0
    end
end

