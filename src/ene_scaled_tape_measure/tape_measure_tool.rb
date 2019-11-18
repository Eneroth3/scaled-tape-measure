module Eneroth
  module ScaledTapeMeasure
    Sketchup.require "#{PLUGIN_ROOT}/tool"
    Sketchup.require "#{PLUGIN_ROOT}/vendor/scale"
    Sketchup.require "#{PLUGIN_ROOT}/vendor/refined_input_point"

    using RefinedInputPoint

    # Tool for measuring length with respect to custom scale.
    class TapeMeasureTool < Tool
      # Identifier of tool state for picking start point.
      STATE_START = 0

      # Identifier for tool state for picking end point.
      STATE_MEASURE = 1

      # Size of arrow head.
      ARROW_HEAD_SIZE = 8

      # ID for tool cursor.
      CURSOR = UI.create_cursor("#{PLUGIN_ROOT}/images/cursor.svg", 6, 24)

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
        case @state
        when STATE_START
          view.tooltip = @start_ip.tooltip
        when STATE_MEASURE
          view.tooltip = output

          view.line_stipple = "_"
          view.draw(GL_LINES, [@end_ip.position, measure_end])

          view.line_stipple = ""
          view.line_width = view.inference_locked? ? 3 : 1
          draw_arrow(@start_ip.position, measure_end, view)
        end

        @start_ip.draw(view)
        @end_ip.draw(view)
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
        bb.add(measure_end) if @end_ip.valid?

        bb
      end

      # @api
      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def onCancel(_reason, view)
        reset
        view.invalidate
      end

      # @api
      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def onSetCursor
        UI.set_cursor(CURSOR)
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
      def onKeyDown(key, _repeat, _flags, view)
        return unless key == CONSTRAIN_MODIFIER_KEY

        view.lock_inference(@state == STATE_START ? @start_ip : @end_ip)
        view.invalidate
      end

      # @api
      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def onKeyUp(key, _repeat, _flags, view)
        return unless key == CONSTRAIN_MODIFIER_KEY

        view.lock_inference
        view.invalidate
      end

      # @api
      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def onUserText(text, _view)
        scale = Scale.new(text)
        unless scale.valid?
          UI.messagebox(OB["invalid_scale"])
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
      def ene_tool_cycler_name
        OB["tool_name"]
      end

      # @api
      # @see https://extensions.sketchup.com/en/content/eneroth-tool-memory
      def ene_tool_cycler_icon
        File.join(PLUGIN_ROOT, "images", "icon.svg")
      end

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

      def measure_end
        if @start_ip.degrees_of_freedom == 1 && @start_ip.freedom_constraint
          plane = [@start_ip.position, @start_ip.freedom_constraint]
          return @end_ip.position.project_to_plane(plane)
        end

        @end_ip.position
      end

      # @return [Geom::Vector3d]
      def measure_vector
        measure_end - @start_ip.position
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
          Sketchup.status_text = OB["status_start"]
          Sketchup.vcb_label = OB["label_start"]
          Sketchup.vcb_value = @@scale.to_s
        when STATE_MEASURE
          Sketchup.status_text = OB["status_measure"]
          Sketchup.vcb_label = OB["label_measure"]
          Sketchup.vcb_value = output
        end
      end
    end
  end
end
