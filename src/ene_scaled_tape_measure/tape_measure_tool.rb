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

      # Size of arrow head.
      ARROW_HEAD_SIZE = 8

      # Scale to measure with respect to.
      @@scale ||= Scale.new("1:1")

      # @api
      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def activate
        super

        @state = STATE_START
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

        case @state
        when STATE_START
          view.tooltip = @start_ip.tooltip
        when STATE_MEASURE
          view.tooltip = output
          draw_arrow(@start_ip.position, @end_ip.position, view)
        end
      end

      # @api
      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def enableVCB?
        @state == STATE_START
      end

      # @api
      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def getExtents
        bb = Sketchup.active_model.bounds
        bb.add(@start_ip.position)
        bb.add(@end_ip.position)

        bb
      end

      # @api
      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def onCancel(_reason, _view)
        reset
        view.invalidate
      end

      # @api
      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def onLButtonDown(_flags, _x, _y, view)
        case @state
        when STATE_START
          @state = STATE_MEASURE
        when STATE_MEASURE
          reset
          view.invalidate
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
      def onUserText(text, _view)
        scale = Scale.new(text)
        unless scale.valid?
          UI.messagebox("Invalid scale.")
          return
        end

        @@scale = scale
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

      private

      def draw_arrow(point1, point2, view)
        return if point1 == point2

        view.set_color_from_line(point1, point2)
        view.draw(GL_LINES, [point1, point2])
        draw_arrow_head(point1, measure_vector.reverse, view)
        draw_arrow_head(point2, measure_vector, view)
      end

      def draw_arrow_head(tip, direction, view)
        cam = view.camera
        cam_v = cam.perspective? ? tip - cam.eye : cam.direction
        perp_v = direction.normalize * cam_v
        flattened = cam_v * perp_v
        offset = view.pixels_to_model(ARROW_HEAD_SIZE, tip)

        view.draw(GL_LINE_STRIP, [
          tip.offset(Geom.linear_combination(1, perp_v, -1, flattened), offset),
          tip,
          tip.offset(Geom.linear_combination(-1, perp_v, -1, flattened), offset)
        ])
      end

      # @return [Length]
      def length
        (measure_vector.length * @@scale.factor).to_l
      end

      # @return [Geom::Vector3d]
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

        "#{length} (#{@@scale})"
      end

      def update_status_text
        case @state
        when STATE_START
          Sketchup.status_text =
            "Type in scale or select point or edge to measure from."
          Sketchup.vcb_label = "Scale"
          Sketchup.vcb_value = @@scale.to_s
        when STATE_MEASURE
          Sketchup.status_text = "Select point to measure to."
          Sketchup.vcb_label = "Length"
          Sketchup.vcb_value = output
        end
      end
    end
  end
end
