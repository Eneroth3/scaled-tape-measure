# frozen_string_literal: true

module Eneroth
  module ScaledTapeMeasure
    Sketchup.require "#{PLUGIN_ROOT}/vendor/ordbok/ordbok"
    Sketchup.require "#{PLUGIN_ROOT}/vendor/ordbok/lang_menu"

    # Ordbok object.
    OB = Ordbok.new

    Sketchup.require "#{PLUGIN_ROOT}/tape_measure_tool"

    # Reload extension.
    #
    # @param clear_console [Boolean] Whether console should be cleared.
    # @param undo [Boolean] Whether last oration should be undone.
    #
    # @return [void]
    def self.reload(clear_console = true, undo = false)
      # Hide warnings for already defined constants.
      verbose = $VERBOSE
      $VERBOSE = nil
      Dir.glob(File.join(PLUGIN_ROOT, "**/*.{rb,rbe}")).each { |f| load(f) }
      $VERBOSE = verbose

      # Use a timer to make call to method itself register to console.
      # Otherwise the user cannot use up arrow to repeat command.
      UI.start_timer(0) { SKETCHUP_CONSOLE.clear } if clear_console

      Sketchup.undo if undo

      nil
    end

    unless @loaded
      @loaded = true

      menu = UI.menu("Plugins").add_submenu(EXTENSION.name)

      cmd = UI::Command.new(OB["tool_name"]) { TapeMeasureTool.activate }
      cmd.set_validation_proc { TapeMeasureTool.command_state }
      menu.add_item(cmd)

      menu.add_separator

      OB.lang_menu(
        menu.add_submenu(OB[:lang_option]),
        system_lang_name: OB[:system_lang_name]
      )
    end
  end
end
