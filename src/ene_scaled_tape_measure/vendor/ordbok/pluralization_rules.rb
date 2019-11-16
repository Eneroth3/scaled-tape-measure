# See https://github.com/Eneroth3/ordbok.

module Eneroth::ScaledTapeMeasure

# Rules how to pluralize phrases in various language groups.
#
# Get pluralization category for given count as defined by the Unicode Language
# Plural Rules.
# http://www.unicode.org/cldr/charts/29/supplemental/language_plural_rules.html
#
# Rule names are based on rails-l18n.
# https://github.com/svenfuchs/rails-i18n/tree/master/lib/rails_i18n/common_pluralizations
module PluralizationRules# TODO: Wrap inside Ordbok class.

  # Determine pluralization category according to `one_other` rule
  # (e.g. used in English, Swedish, Italian, German, Spanish).
  #
  # @param count [Numeric]
  #
  # @return [Symbol]
  def self.one_other(count)
    count == 1 ? :one : :other
  end

  # Determine pluralization category according to `one_upto_two_other` rule
  # (e.g. used in French and (non-European) Portuguese).
  #
  # @param count [Numeric]
  #
  # @return [Symbol]
  def self.one_upto_two_other(count)
    count >= 0 && count < 2 ? :one : :other
  end

  # Determine pluralization category according to `east_slavic` rule
  # (e.g. used in Russian).
  #
  # @param count [Numeric]
  #
  # @return [Symbol]
  def self.east_slavic(count)
    mod10  = count % 10
    mod100 = count % 100

    if count.is_a?(Float)
      :other
    elsif mod10 == 1 && mod100 != 11
      :one
    elsif mod10.between?(2, 4) && !mod100.between?(12, 14)
      :few
    else
      :many
    end
  end

  # Determine pluralization category according to `polish` rule.
  #
  # @param count [Numeric]
  #
  # @return [Symbol]
  def self.polish(count)
    mod10  = count % 10
    mod100 = count % 100

    if count.is_a?(Float)
      :other
    elsif count == 1
      :one
    elsif mod10.between?(2, 4) && !mod100.between?(12, 14)
      :few
    else
      :many
    end
  end

  # Determine pluralization category according to `welsh` rule.
  #
  # @param count [Numeric]
  #
  # @return [Symbol]
  def self.welsh(count)
    case count
    when 1
      :one
    when 2
      :two
    when 3
      :few
    when 6
      :many
    else
      :other
    end
  end

end
end
