# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext/object/blank'

require_relative 'portolan/version'
require_relative 'portolan/type/string'
require_relative 'portolan/type/enum'
require_relative 'portolan/type/integer'
require_relative 'portolan/type/boolean'
require_relative 'portolan/type/date'
require_relative 'portolan/type/date_time'
require_relative 'portolan/type'
require_relative 'portolan/dimension'
require_relative 'portolan/measure'
require_relative 'portolan/dataset'
require_relative 'portolan/registry'

module Portolan
end
