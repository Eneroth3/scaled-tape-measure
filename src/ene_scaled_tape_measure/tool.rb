module Eneroth
  module ScaledTapeMeasure
    # Generic tool superclass with functionality relevant in all tools.
    #
    # Remember to call super if overriding +#activate+ and +#deactivate+ on any
    # subclasses.
    class Tool
      @@active_tool_class = nil

      # Activate tool.
      #
      # Any provided parameters as well as block are passed on to the
      # constructor.
      #
      # @return [Object] the Ruby tool.
      def self.activate(*args, &block)
        tool = block ? new(*args, &block) : new(*args)
        Sketchup.active_model.select_tool(tool)

        tool
      end

      # Check if this tool is active. Intended to be called on subclasses.
      #
      # @return [Boolean]
      def self.active?
        @@active_tool_class == self
      end

      # Get command state to use in command validation proc for this tool.
      # Intended to be called on subclasses.
      #
      # @return [Integer]
      def self.command_state
        active? ? MF_CHECKED : MF_UNCHECKED
      end

      # @api
      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def activate(*_args)
        @@active_tool_class = self.class
      end

      # @api
      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def deactivate(*_args)
        @@active_tool_class = nil
      end
    end
  end
end
