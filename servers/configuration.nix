{ lib
, pkgs
, config
, ...
}:
let
  authorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILztL16pShpN/loc4tkq1V6zKmDNu/WWtMEJk4zadHHO tguimbert@work"
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIFH1m31u/W8216NNkdrbvlJf0D3JRla16XD8clMeGDRyAAAABHNzaDo="
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIItgAyaI4GxuTh2LU+Z7cWDb1HIEfVMWxJ5mRwDiGmbOAAAABHNzaDo="
  ];
  klamp = pkgs.stdenv.mkDerivation {
    pname = "klamp";
    version = "1.0.0";
    src = pkgs.fetchFromGitHub {
      owner = "kyleisah";
      repo = "Klipper-Adaptive-Meshing-Purging";
      rev = "b0dad8ec9ee31cb644b94e39d4b8a8fb9d6c9ba0";
      hash = "sha256-05l1rXmjiI+wOj2vJQdMf/cwVUOyq5d21LZesSowuvc=";
    };
    installPhase = ''
      mkdir -p $out/bin/configuration
      cp Configuration/* $out/bin/configuration
    '';
  };
in
{
  boot.initrd.availableKernelModules = [ "usbhid" ];
  boot.kernelPackages = pkgs.linuxPackages;

  networking = {
    hostName = "klipper";
    networkmanager = {
      enable = true;
      ensureProfiles = {
        environmentFiles = [ config.sops.secrets."wireless.env".path ];
        profiles = {
          home-wifi = {
            connection = {
              id = "home-wifi";
              type = "wifi";
            };
            wifi.ssid = "$HOME_WIFI_SSID";
            wifi-security = {
              auth-alg = "open";
              key-mgmt = "wpa-psk";
              psk = "$HOME_WIFI_PASSWORD";
            };
          };
        };
      };
    };
    firewall = {
      enable = true;
      allowedTCPPorts = [
        80
        config.services.moonraker.port
        1984
      ];
    };
  };

  time.timeZone = "Europe/Paris";

  users = {
    mutableUsers = false;
    users = {
      tguimbert = {
        isNormalUser = true;
        hashedPasswordFile = config.sops.secrets.tguimbert-password.path;
        extraGroups = [ "wheel" ];
        openssh.authorizedKeys.keys = authorizedKeys;
      };
      root.openssh.authorizedKeys.keys = authorizedKeys;
      klipper = {
        isSystemUser = true;
        group = "klipper";
      };
    };
    groups.klipper = { };
  };

  environment.systemPackages = with pkgs; [
    helix
    bottom
    klamp
  ];

  services = {
    openssh = {
      enable = true;
      settings.PasswordAuthentication = false;
      extraConfig = ''
        AllowTcpForwarding yes
        AllowAgentForwarding no
        AllowStreamLocalForwarding no
        AuthenticationMethods publickey
      '';
    };
    klipper = {
      enable = true;
      mutableConfig = false;
      # configFile = ./printer.cfg;
      settings = {
        stepper_x = {
          step_pin = "PB13";
          dir_pin = "!PB12";
          enable_pin = "!PB14";
          microsteps = 16;
          rotation_distance = 40;
          endstop_pin = "^PC0";
          position_endstop = 0;
          position_max = 246;
          homing_speed = 50;
        };
        "tmc2209 stepper_x" = {
          uart_pin = "PC11";
          tx_pin = "PC10";
          uart_address = 0;
          run_current = 0.580;
          stealthchop_threshold = 999999;
        };
        stepper_y = {
          step_pin = "PB10";
          dir_pin = "!PB2";
          enable_pin = "!PB11";
          microsteps = 16;
          rotation_distance = 40;
          endstop_pin = "^PC1";
          position_endstop = 0;
          position_max = 235;
          homing_speed = 50;
        };
        "tmc2209 stepper_y" = {
          uart_pin = "PC11";
          tx_pin = "PC10";
          uart_address = 2;
          run_current = 0.580;
          stealthchop_threshold = 999999;
        };
        stepper_z = {
          step_pin = "PB0";
          dir_pin = "PC5";
          enable_pin = "!PB1";
          microsteps = 16;
          rotation_distance = 8;
          endstop_pin = "probe:z_virtual_endstop";
          position_max = 250;
          position_min = -2;
        };
        "tmc2209 stepper_z" = {
          uart_pin = "PC11";
          tx_pin = "PC10";
          uart_address = 1;
          run_current = 0.580;
          stealthchop_threshold = 999999;
        };
        bltouch = {
          sensor_pin = "^PC14";
          control_pin = "PA1";
          x_offset = -45.8;
          y_offset = -7.2;
          z_offset = 1.000;
        };
        safe_z_home = {
          home_xy_position = "115,115";
          speed = 50;
          z_hop = 10;
          z_hop_speed = 5;
        };
        bed_mesh = {
          speed = 120;
          horizontal_move_z = 3.5;
          mesh_min = "10, 10";
          mesh_max = "200, 220";
          probe_count = 9;
          algorithm = "bicubic";
        };
        screws_tilt_adjust = {
          screw1 = "80.8, 42.2"; # 35-bltouch.x_offset, 35-btouch.y_offset;
          screw1_name = "front left screw";
          screw2 = "245.8, 42.2"; # 200-bltouch.x_offset, 35-btouch.y_offset;
          screw2_name = "front right screw";
          screw3 = "245.8, 207.2"; # 200-bltouch.x_offset, 200-btouch.y_offset;
          screw3_name = "rear right screw";
          screw4 = "80.8, 207.2"; # 35-bltouch.x_offset, 200-btouch.y_offset;
          screw4_name = "rear left screw";
          horizontal_move_z = 10.;
            speed = 50.;
          screw_thread = "CW-M4";
        };
        extruder = {
          step_pin = "PB3";
          dir_pin = "!PB4";
          enable_pin = "!PD1";
          microsteps = 16;
          rotation_distance = 31.091742;
          nozzle_diameter = 0.400;
          filament_diameter = 1.750;
          heater_pin = "PC8";
          sensor_type = "Generic 3950";
          sensor_pin = "PA0";
          control = "pid";
          pid_Kp = 25.785;
          pid_Ki = 1.386;
          pid_Kd = 119.900;
          min_temp = 0;
          max_temp = 250;
          max_extrude_only_distance = 101;
          max_extrude_cross_section = 5;
          pressure_advance = 0.7;
        };
        "tmc2209 extruder" = {
          uart_pin = "PC11";
          tx_pin = "PC10";
          uart_address = 3;
          run_current = 0.650;
        };
        heater_bed = {
          heater_pin = "PC9";
          sensor_type = "EPCOS 100K B57560G104F";
          sensor_pin = "PC4";
          control = "pid";
          pid_Kp = 69.929;
          pid_Ki = 1.087;
          pid_Kd = 1124.990;
          min_temp = 0;
          max_temp = 130;

        };
        "heater_fan heatbreak_cooling_fan" = {
          pin = "PC7";
        };
        "heater_fan controller_fan" = {
          pin = "PB15";
        };
        fan = {
          pin = "PC6";
        };
        mcu = {
          serial = "/dev/serial/by-id/usb-Klipper_stm32g0b1xx_4F00350002504B5735313920-if00";
        };
        printer = {
          kinematics = "cartesian";
          max_velocity = 300;
          max_accel = 3000;
          max_z_velocity = 5;
          max_z_accel = 100;
        };
        exclude_object = { };
        display = {
          lcd_type = "st7920";
          cs_pin = "PB8";
          sclk_pin = "PB9";
          sid_pin = "PD6";
          encoder_pins = "^PA10, ^PA9";
          click_pin = "^!PA15";
        };
        "output_pin beeper" = {
          pin = "PB5";
        };
        # Wrong?
        "bed_screws" = {
          screw1 = "30.5, 37";
          screw2 = "30.5, 207";
          screw3 = "204.5, 207";
          screw4 = "204.5, 37";
        };
        board_pins = {
          aliases = ''
            # EXP1 header
              EXP1_1=PB5,  EXP1_3=PA9,   EXP1_5=PA10, EXP1_7=PB8, EXP1_9=<GND>,
              EXP1_2=PA15, EXP1_4=<RST>, EXP1_6=PB9,  EXP1_8=PD6, EXP1_10=<5V>
          '';
        };
        pause_resume = { };
        display_status = { };
        virtual_sdcard = {
          path = "/var/lib/moonraker/gcodes";
        };
        "gcode_macro PAUSE" = {
          description = "Pause the actual running print";
          rename_existing = "BASE_PAUSE";
          # change this if you need more or less extrusion
          variable_extrude = 1.0;
          gcode = ''

            ##### PAUSE #####
              # Parameters
              {% set z = params.Z|default(10)|int %}                                                   ; z hop amount

              {% if printer['pause_resume'].is_paused|int == 0 %}
                  SET_GCODE_VARIABLE MACRO=RESUME VARIABLE=zhop VALUE={z}                              ; set z hop variable for reference in resume macro
                  SET_GCODE_VARIABLE MACRO=RESUME VARIABLE=etemp VALUE={printer['extruder'].target}    ; set hotend temp variable for reference in resume macro

                  # SET_FILAMENT_SENSOR SENSOR=filament_sensor ENABLE=0                                  ; disable filament sensor
                  SAVE_GCODE_STATE NAME=PAUSE                                                          ; save current print position for resume
                  BASE_PAUSE                                                                           ; pause print
                  {% if (printer.gcode_move.position.z + z) < printer.toolhead.axis_maximum.z %}       ; check that zhop doesn't exceed z max
                      G91                                                                              ; relative positioning
                      G1 Z{z} F900                                                                     ; raise Z up by z hop amount
                  {% else %}
                      { action_respond_info("Pause zhop exceeds maximum Z height.") }                  ; if z max is exceeded, show message and set zhop value for resume to 0
                      SET_GCODE_VARIABLE MACRO=RESUME VARIABLE=zhop VALUE=0
                  {% endif %}
                  G90                                                                                  ; absolute positioning
                  G1 X{printer.toolhead.axis_maximum.x/2} Y{printer.toolhead.axis_minimum.y+5} F6000   ; park toolhead at front center
                  SAVE_GCODE_STATE NAME=PAUSEPARK                                                      ; save parked position in case toolhead is moved during the pause (otherwise the return zhop can error)
                  M104 S0                                                                              ; turn off hotend
                  SET_IDLE_TIMEOUT TIMEOUT=43200                                                       ; set timeout to 12 hours
              {% endif %}
          '';
        };
        "gcode_macro RESUME" = {
          description = "Resume the actual running print";
          rename_existing = "BASE_RESUME";
          variable_zhop = 0;
          variable_etemp = 0;
          gcode = ''

            ##### RESUME #####
              # Parameters
              {% set e = params.E|default(2.5)|int %}                                          ; hotend prime amount (in mm)

              {% if printer['pause_resume'].is_paused|int == 1 %}
                  # SET_FILAMENT_SENSOR SENSOR=filament_sensor ENABLE=1                          ; enable filament sensor
                  #INITIAL_RGB                                                                    ; reset LCD color
                  SET_IDLE_TIMEOUT TIMEOUT={printer.configfile.settings.idle_timeout.timeout}  ; set timeout back to configured value
                  {% if etemp > 0 %}
                      M109 S{etemp|int}                                                        ; wait for hotend to heat back up
                  {% endif %}
                  RESTORE_GCODE_STATE NAME=PAUSEPARK MOVE=1 MOVE_SPEED=100                     ; go back to parked position in case toolhead was moved during pause (otherwise the return zhop can error)
                  G91                                                                          ; relative positioning
                  M83                                                                          ; relative extruder positioning
                  {% if printer[printer.toolhead.extruder].temperature >= printer.configfile.settings.extruder.min_extrude_temp %}
                      G1 Z{zhop * -1} E{e} F900                                                ; prime nozzle by E, lower Z back down
                  {% else %}
                      G1 Z{zhop * -1} F900                                                     ; lower Z back down without priming (just in case we are testing the macro with cold hotend)
                  {% endif %}
                  RESTORE_GCODE_STATE NAME=PAUSE MOVE=1 MOVE_SPEED=60                          ; restore position
                  BASE_RESUME                                                                  ; resume print
              {% endif %}
          '';
        };
        "gcode_macro CANCEL_PRINT" = {
          description = "Cancel the actual running print";
          rename_existing = "BASE_CANCEL_PRINT";
          gcode = ''

            ##### CANCEL_PRINT #####
              SET_IDLE_TIMEOUT TIMEOUT={printer.configfile.settings.idle_timeout.timeout} ; set timeout back to configured value
              CLEAR_PAUSE
              SDCARD_RESET_FILE
              PRINT_END
              BASE_CANCEL_PRINT
          '';
        };
        "gcode_macro M600" = {
          description = "Filament change";
          gcode = ''

            ##### M600 #####
              #LCDRGB R=0 G=1 B=0  ; Turn LCD green
              PAUSE                ; Pause
          '';
        };
        "gcode_macro M109" = {
          description = "Wait for hotend temperature without stabilizing";
          rename_existing = "M99109";
          gcode = ''

            ##### M109 #####
              #Parameters
              {% set s = params.S|float %}

              M104 {% for p in params %}{'%s%s' % (p, params[p])}{% endfor %}  ; Set hotend temp
              {% if s != 0 %}
                  TEMPERATURE_WAIT SENSOR=extruder MINIMUM={s} MAXIMUM={s+1}   ; Wait for hotend temp (within 1 degree)
              {% endif %}
          '';
        };
        "gcode_macro M190" = {
          description = "Wait for bed temperature without stabilizing";
          rename_existing = "M99190";
          gcode = ''

            ##### M190 #####
              #Parameters
              {% set s = params.S|float %}

              M140 {% for p in params %}{'%s%s' % (p, params[p])}{% endfor %}   ; Set bed temp
              {% if s != 0 %}
                  TEMPERATURE_WAIT SENSOR=heater_bed MINIMUM={s} MAXIMUM={s+1}  ; Wait for bed temp (within 1 degree)
              {% endif %}
          '';
        };
        "gcode_macro _CG28" = {
          description = "Conditional homing";
          gcode = ''

            ##### _CG28 #####
              {% if "xyz" not in printer.toolhead.homed_axes %}
                  G28
              {% endif %}
          '';
        };
        "gcode_macro PRINT_START" = {
          gcode = ''

            ##### PRINT_START BED_TEMP={bed_temperature_initial_layer[current_extruder]} EXTRUDER_TEMP={nozzle_temperature_initial_layer[current_extruder]} #####
              {% set BED_TEMP = params.BED_TEMP|default(60)|float %}
              {% set EXTRUDER_TEMP = params.EXTRUDER_TEMP|default(190)|float %}
              # Start bed heating
              M140 S{BED_TEMP}
              # Set temporary nozzle temp to prevent oozing during homing
              M104 S150
              # Use absolute coordinates
              G90
              # Reset the G-Code Z offset (adjust Z offset if needed)
              SET_GCODE_OFFSET Z=0.0
              # Home the printer
              _CG28
              # Wait for bed to reach temperature
              M190 S{BED_TEMP}
              BED_MESH_CALIBRATE
              SMART_PARK
              # Set and wait for nozzle to reach temperature
              M109 S{EXTRUDER_TEMP}
              LINE_PURGE
          '';
        };
        "gcode_macro PRINT_END" = {
          gcode = ''

            ##### PRINT_END #####
              # Turn off bed, extruder, and fan
              M140 S0
              M104 S0
              M106 S0
              # Move nozzle away from print while retracting
              G91
              G1 X-2 Y-2 E-10 F300
              # Raise nozzle by 10mm
              G1 Z10 F3000
              G90
              # Disable steppers
              M84
          '';
        };

        "include ${builtins.unsafeDiscardStringContext klamp}/bin/configuration/Adaptive_Meshing.cfg" =
          { }; # Include to enable adaptive meshing configuration.
        "include ${builtins.unsafeDiscardStringContext klamp}/bin/configuration/Line_Purge.cfg" = { }; # Include to enable adaptive line purging configuration.
        # "include ${builtins.unsafeDiscardStringContext klamp}/bin/configuration/Voron_Purge.cfg" = { }; # Include to enable adaptive Voron logo purging configuration.
        "include ${builtins.unsafeDiscardStringContext klamp}/bin/configuration/Smart_Park.cfg" = { }; # Include to enable the Smart Park function, which parks the printhead near the print area for final heating.
        "gcode_macro _KAMP_Settings" = {
          description = "This macro contains all adjustable settings for KAMP";

          # The following variables are settings for KAMP as a whole.
          variable_verbose_enable = "True"; # Set to True to enable KAMP information output when running. This is useful for debugging.

          # The following variables are for adjusting adaptive mesh settings for KAMP.
          variable_mesh_margin = 0; # Expands the mesh size in millimeters if desired. Leave at 0 to disable.
          variable_fuzz_amount = 0; # Slightly randomizes mesh points to spread out wear from nozzle-based probes. Leave at 0 to disable.

          # The following variables are for those with a dockable probe like Klicky, Euclid, etc.                 # ----------------  Attach Macro | Detach Macro
          variable_probe_dock_enable = "False"; # Set to True to enable the usage of a dockable probe.      # ---------------------------------------------
          variable_attach_macro = "'Attach_Probe'"; # The macro that is used to attach the probe.               # Klicky Probe:   'Attach_Probe' | 'Dock_Probe'
          variable_detach_macro = "'Dock_Probe'"; # The macro that is used to store the probe.                # Euclid Probe:   'Deploy_Probe' | 'Stow_Probe'
          # Legacy Gcode:   'M401'         | 'M402'

          # The following variables are for adjusting adaptive purge settings for KAMP.
          variable_purge_height = 0.8; # Z position of nozzle during purge, default is 0.8.
          variable_tip_distance = 10; # Distance between tip of filament and nozzle before purge. Should be similar to PRINT_END final retract amount.
          variable_purge_margin = 10; # Distance the purge will be in front of the print area, default is 10.
          variable_purge_amount = 30; # Amount of filament to be purged prior to printing.
          variable_flow_rate = 12; # Flow rate of purge in mm3/s. Default is 12.

          # The following variables are for adjusting the Smart Park feature for KAMP, which will park the printhead near the print area at a specified height.
          variable_smart_park_height = 10; # Z position for Smart Park, default is 10.

          gcode = ''
            # Gcode section left intentionally blank. Do not disturb.

               {action_respond_info(" Running the KAMP_Settings macro does nothing, it is only used for storing KAMP settings. ")}
          '';
        };
      };
      firmwares.mcu = {
        enable = true;
        enableKlipperFlash = true;
        configFile = ./mcu.cfg;
        serial = "/dev/serial/by-id/usb-Klipper_stm32g0b1xx_4F00350002504B5735313920-if00";
      };
    };
    moonraker = {
      enable = true;
      group = "klipper";
      address = "0.0.0.0";
      settings = {
        file_manager = {
          enable_object_processing = true;
        };
        data_store = {
          temperature_store_size = 600;
          gcode_store_size = 1000;
        };
        authorization = {
          cors_domains = [
            "*.local"
            "*.lan"
            "*://localhost"
            "*://klipper"
          ];
          trusted_clients = [
            "10.0.0.0/8"
            "127.0.0.0/8"
            "169.254.0.0/16"
            "172.16.0.0/12"
            "192.168.0.0/16"
            "FE80::/10"
            "::1/128"
          ];
        };
        history = { };
        octoprint_compat = { };
        update_manager = {
          enable_auto_refresh = false;
          enable_system_updates = [ false ];
        };
        announcements = {
          subscriptions = [ "fluidd" ];
        };
      };
      allowSystemControl = true;
    };
    fluidd.enable = true;
    go2rtc = {
      enable = true;
      settings = {
        streams = {
          usbcam = "ffmpeg:device?video=0&resolution=1280x720#video=h264";
        };
        api = {
          origin = "*";
        };
      };
    };
  };

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };

  swapDevices = [ ];

  networking.useDHCP = lib.mkDefault true;

  sops = {
    defaultSopsFile = ./secrets/klipper.yaml;
    age = {
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = true;
    };
    secrets = {
      tguimbert-password.neededForUsers = true;
      "wireless.env" = { };
    };
  };

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
  hardware.enableRedistributableFirmware = true;
  system.stateVersion = "25.05";
}
