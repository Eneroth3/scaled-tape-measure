# See https://github.com/Eneroth3/ordbok.

module Eneroth::ScaledTapeMeasure
Sketchup.require "#{PLUGIN_ROOT}/vendor/ordbok/ordbok"

class Ordbok

  # Create menu items for selecting language.
  #
  # @param menu [Sketchup::Menu]
  # @param offer_system_lang [Boolean] Whether to include "System Default" as an
  #   option for picking language based on SU language.
  # @param system_lang_name [String] What to call menu item for system language.
  #   Note that this isn't the name of any language itself but the phrase
  #   denoting no language is explicitly picked.
  #
  # @example
  #   OB = Ordbok.new(remember_lang: true)
  #   menu = UI.menu("Plugins").add_submenu("My Extension").add_submenu("Language")
  #   OB.lang_menu(menu)
  #
  # @return [Void]
  def lang_menu(menu, offer_system_lang: true, system_lang_name: "System Default")
    if offer_system_lang
      item = menu.add_item(system_lang_name) { self.lang = nil }
      menu.set_validation_proc(item) { lang_pref.nil? ? MF_CHECKED : MF_UNCHECKED }
      menu.add_separator
    end

    available_lang_names.sort.each do |code, name|
      item = menu.add_item(name) { self.lang = code }
      if offer_system_lang
        menu.set_validation_proc(item) { lang_pref == code ? MF_CHECKED : MF_UNCHECKED }
      else
        menu.set_validation_proc(item) { self.lang == code ? MF_CHECKED : MF_UNCHECKED }
      end
    end

    nil
  end

end
end

