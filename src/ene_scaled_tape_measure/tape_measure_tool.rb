module Eneroth
  module ScaledTapeMeasure
    Sketchup.require "#{PLUGIN_ROOT}/tool.rb"
    Sketchup.require "#{PLUGIN_ROOT}/vendor/scale.rb"

    # Tool for measuring length with respect to custom scale.
    class TapeMeasureTool < Tool
      # Identifier of tool state for picking start point.
      STATE_START = 0

      # Identifier for tool state for picking end point.
      STATE_MEASURE = 1

      # @api
      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def activate
        super

        @state = STATE_START
        # TODO: Keep scale between tool sessions.
        @scale = Scale.new("1:1")
        @start_ip = Sketchup::InputPoint.new
        @end_ip = Sketchup::InputPoint.new

        update_status_text
      end

      # @api
      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def deactivate(view)
        super

        reset
        view.invalidate
      end

      # @api
      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def draw(view)
        @start_ip.draw(view)
        @end_ip.draw(view)

        # TODO: Draw line and arrows.

        view.tooltip =
          case @state
          when STATE_START
            @start_ip.tooltip
          when STATE_MEASURE
            output
          end
      end

      # @api
      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def enableVCB?
        true
      end

      # @api
      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def onCancel(_reason, _view)
        reset
      end

      # @api
      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def onLButtonDown(_flags, _x, _y, _view)
        case @state
        when STATE_START
          @state = STATE_MEASURE
        when STATE_MEASURE
          reset
        end
        update_status_text
      end

      # @api
      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def onMouseMove(_flags, x, y, view)
        case @state
        when STATE_START
          @start_ip.pick(view, x, y)
        when STATE_MEASURE
          @end_ip.pick(view, x, y)
          Sketchup.vcb_value = output
        end
        view.invalidate
      end

      # @api
      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def onUserText(view, text)
        # TODO: Parse scale. Set @scale if valid.
      end

      # @api
      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def resume(view)
        view.invalidate
        update_status_text
      end

      # @api
      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def suspend(view)
        view.invalidate
      end

      # @api
      # @see https://extensions.sketchup.com/en/content/eneroth-tool-memory
      def ene_tool_cycler_icon
        # TODO: Make icon.
        File.join(PLUGIN_ROOT, "images", "tape_measure.svg")
      end

      private

      # @return [Length]
      def length
        (measure_vector.length * @scale.factor).to_l
      end

      def measure_vector
        @end_ip.position - @start_ip.position
      end

      def reset
        @end_ip.clear
        @state = STATE_START
      end

      # @return [String]
      def output
        return "" unless @end_ip.valid?

        "#{length} (#{@scale})"
      end

      def update_status_text
        # REVIEW: Should VCB even show length or only scale?
        case @state
        when STATE_START
          Sketchup.status_text = "Type in scale or click to start measure."
          Sketchup.vcb_label = "Scale"
          Sketchup.vcb_value = @scale.to_s
        when STATE_MEASURE
          Sketchup.status_text = "Click to end measure."
          Sketchup.vcb_label = "Length"
        end
      end
    end
  end
end
