# See https://github.com/Eneroth3/ordbok.

require "json"

module Eneroth::ScaledTapeMeasure
Sketchup.require "#{PLUGIN_ROOT}/vendor/ordbok/pluralization_rules"

# Ordbok localization library for SketchUp extensions.
#
# @note Period (.) is an illegal character in individual keys, as it is used as
#   delimiter for nested keys.
#
# @example
#   # 'extension-dir/resources/en-US.lang'
#   # {"greeting":"Hello World!"}
#
#   # 'extension-dir/main.rb'
#   require "extension-dir/ordbok"
#   OB = Ordbok.new
#   OB[:greeting]
#   # => "Hello World!"
class Ordbok

  # Initialize Ordbok object.
  #
  # It is recommended to assign this object to constant for access throughout
  # your extension.
  #
  # @example
  #   OB = Ordbok.new
  #
  # @param lang [Symbol, nil] The language to use.
  #   When nil, Ordbok fall backs to language from last session
  #   (if remember_lang is true and a value can be found), SketchUp's language,
  #   en-US, or whatever language can be found.
  # @param resource_dir [String, nil] Absolute path to directory containing
  #   language files.
  #   When nil, "resources" relative to where Ordbok.new is called is used.
  # @param remember_lang [Boolean] Save language preference betweens sessions.
  # @param pref_key [Symbol, nil] Key to save language setting to.
  #   When nil, a key based on the Extension's module is used.
  #
  # @raise [LoadError] if no lang files exists in resource_dir.
  def initialize(lang: nil, resource_dir: nil, remember_lang: true, pref_key: nil)
    @caller_path  = caller_locations(1..1).first.path
    @resource_dir = resource_dir || default_resource_dir
    raise LoadError, "No .lang files found in #{@resource_dir}." if available_langs.empty?
    @remember_lang = remember_lang
    @pref_key      = pref_key || default_pref_key
    @lang_pref     = (lang && lang.to_sym) || (remember_lang && saved_lang) || nil
    try_load_langs
  end

  # Returns the code of the currently used language.
  #
  # @return [Symbol]
  attr_reader :lang

  # Returns the code of the current lang preference.
  # If no language has been explicitly chosen, nil is returned.
  # Use lang to get the code of the actually used language.
  #
  # @return [Symbol]
  attr_reader :lang_pref

  # @overload remember_lang
  #   Get whether the chosen language should be restored in next session.
  #   @return [Boolean]
  # @overload remember_lang=(value)
  #   Set whether the chosen language should be restored in next session.
  #   @param value [Boolean]
  attr_accessor :remember_lang

  # @overload pref_key
  #   Get the key by witch the language preference is stored between sessions.
  #   @return [Symbol]
  # @overload pref_key=(value)
  #   Set the key by witch the language preference is stored between sessions.
  #   @param value [Symbol]
  attr_accessor :pref_key

  # List the available languages in the resources directory.
  #
  # A language is a file with the extension .lang.
  #
  # @return [Array<Symbol>]
  def available_langs
    pattern = "#{@resource_dir.tr('\\', '/')}/*.lang"
    Dir.glob(pattern).map { |p| File.basename(p, ".*").to_sym }
  end

  # List names of available languages in the resources directory indexed by
  # their code.
  #
  # @return [Hash{Symbol => String}]
  def available_lang_names
    # To #to_h method in SU2014.
    Hash[available_langs.map { |l| [l, lang_name(l)] }]
  end

  def inspect
    "#<#{self.class.name}:#{object_id} (#{lang})>"
  end

  # Set language.
  #
  # @param lang [Symbol]
  #
  # @raise [ArgumentError] If the language is unavailable.
  def lang=(lang)
    if lang && !lang_available?(lang)
      raise ArgumentError, "Language unavailable. Does file exist? #{lang_path(lang)}"
    end

    @lang_pref = lang && lang.to_sym
    save_lang(@lang_pref) if @remember_lang
    try_load_langs
  end

  # Check if a specific language is available.
  #
  # @param lang [Symbol]
  #
  # @return [Boolean]
  def lang_available?(lang)
    File.exist?(lang_path(lang))
  end

  # Output localized string for key.
  #
  # Formats string according to additional parameters, if any.
  # If key is missing, warn and return stringified key.
  #
  # @param key [Symbol, String]
  # @param opts [Hash] Interpolation options. See Kernel.format for details.
  # @option opts :count [Numeric] The count keyword is not only interpolated to
  #   the string, but also used to select nested entry based on pluralization,
  #   if available (see example).
  #
  # @example
  #   # (Assuming there is a resource directory with valid lang files)
  #   OB = Ordbok.new
  #
  #   # (Assuming :greeting defined as "Hello World!")
  #   OB[:greeting]
  #   # => "Hello World!"
  #
  #   # Key can be String too.
  #   OB["greeting"]
  #   # => "Hello World!"
  #
  #   # (Assuming :interpolate defined as "Interpolate string here: %{string}.")
  #   OB[:interpolate, string: "Hello World!"]
  #   # => "Interpolate string here: Hello World!."
  #
  #   # Keys can be nested, defining groups of related messages.
  #   # For nested nested keys, use String with period as delimiter.
  #   # Note that "." is an illegal character within individual keys!
  #   OB["message_notification.zero"]
  #   # => "You have no new messages."
  #
  #   # The :count keyword is not only interpolated to the String, but also
  #   # used to select nested entry (if available). This allows you to
  #   # specify separate strings with different pluralization.
  #
  #   # If the count is 0, the entry :zero is used if available.
  #   # (Assuming "message_notification.zero" is "You have no new message.")
  #   OB["message_notification", count: 0 ]
  #   # => "You have no new messages."
  #
  #   # If the count is 1, the entry :one is used if available.
  #   # (Assuming "message_notification.one" is "You have %{count} new message.")
  #   OB["message_notification", count: 1 ]
  #   # => "You have 1 new message."
  #
  #   # Otherwise the entry :other is used.
  #   # (Assuming "message_notification.other" is "You have %{count} new messages.")
  #   OB["message_notification", count: 7 ]
  #   # => "You have 7 new messages."
  #
  # @return [String]
  def [](key, opts = {})
    count = opts[:count]
    template = lookup(key, count)
    if template
      format(template, opts)
    else
      warn "key #{key} is missing."
      key.to_s
    end
  end

  private

  # List of languages to to try loading, in the order they should be tried.
  # Note that this list can contain languages that aren't available.
  #
  # @return [Array<Symbol>]
  def lang_load_queue
    [
      @lang_pref,
      @remember_lang ? saved_lang : nil,
      Sketchup.os_language.to_sym,
      :"en-US",
      available_langs.first
    ].compact
  end

  # Get name of available language from lang code.
  #
  # @param lang [Symbol]
  #
  # @return [String]
  def lang_name(lang)
    file_content = File.read(lang_path(lang))

    JSON.parse(file_content, symbolize_names: true)[:name][:native]
  end

  # Default directory to look for translations in.
  #
  # @return [String]
  def default_resource_dir
    File.join(File.dirname(@caller_path), "resources")
  end

  # Generate a key by witch to save language preference.
  # Based on parent module names, e.g. Eneroth::AwesomeExtension ->
  # "Eneroth_AweseomeExtension_Orbok".
  #
  # @return [Symbol]
  def default_pref_key
    self.class.name.gsub("::", "_")
  end

  # Find value in nested hash using array of keys.
  #
  # @param hash [Hash]
  # @param keys [Arraty]
  #
  # @return value or nil if missing.
  def hash_lookup_by_key_array(hash, keys)
    keys.reduce(hash) { |h, k| h.is_a?(Hash) && h[k.to_sym] || nil }
  end

  # Path to a specific lang file.
  #
  # @param lang [Symbol
  #
  # @return [String]
  def lang_path(lang = @lang)
    File.join(@resource_dir, "#{lang}.lang")
  end

  # Loads the lang file containing the translation table.
  #
  # @return [Void]
  def load_lang_file
    file_content = File.read(lang_path)
    parsed_json = JSON.parse(file_content, symbolize_names: true)
    @dictionary = parsed_json[:dictionary]
    @pluralization_rule = parsed_json[:pluralization_rule]

    nil
  end

  # Look up an entry in the translation table.
  #
  # @param key [Symbol, String]
  # @param count [nil, Object]
  #
  # @raise [KeyError] If key points to a nested Hash, not a String, and count
  #   isn't specified as a Numeric.
  #
  # @return [String, nil]
  def lookup(key, count = nil)
    entry =
      if key.is_a?(Symbol)
        @dictionary[key]
      elsif key.is_a?(String)
        hash_lookup_by_key_array(@dictionary, key.split("."))
      end

    entry = pluralize(entry, count) if entry.is_a?(Hash) && count.is_a?(Numeric)

    raise KeyError, "key points to sub-Hash, not String: #{key}" if entry.is_a?(Hash)

    entry
  end

  # Find sub-entry depending on count and pluralization rules.
  #
  # @param entry [Hash]
  # @param count [Numeric]
  #
  # @return [String, nil]
  def pluralize(entry, count)
    # If count is 0 and a phrase for the count 0 is specified, use it regardless
    # of pluralization rules.
    # Even in languages where zero isn't different strictly grammatically, it is
    # practical to have the ability to assign a separate phrase, e.g.
    # "You have no new messages", rather than "You have 0 new messages".
    return entry[:zero] if count.zero? && entry[:zero]

    rule = @pluralization_rule || "one_other"
    category = PluralizationRules.send(rule, count)

    entry[category] || entry[:other]
  end

  # Save language preference
  #
  # @param lang [Symbol, nil]
  #
  # @return [Void]
  def save_lang(lang)
    v = lang ? lang.to_s : nil
    Sketchup.write_default(@pref_key.to_s, "lang", v)

    nil
  end

  # Return saved language preference, or nil if there is none.
  #
  # @return [Symbol, nil]
  def saved_lang
    lang = Sketchup.read_default(@pref_key.to_s, "lang")
    lang && lang.to_sym
  end

  # Try loading languages from load queue.
  #
  # @return [Symbol, nil] Lang code of loaded language on success.
  def try_load_langs
    lang_load_queue.each do |lang|
      next unless lang_available?(lang)
      @lang = lang
      load_lang_file
      return lang
    end

    nil
  end

end

end
