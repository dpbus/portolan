# frozen_string_literal: true

module Portolan
  module Type
    CLASSES = { string: String, integer: Integer, boolean: Boolean, date: Date, datetime: DateTime }.freeze
    NAMES = CLASSES.keys.freeze

    def self.for(name) = CLASSES.fetch(name).new
  end
end
