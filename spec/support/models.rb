# frozen_string_literal: true

class Ship < ActiveRecord::Base
  has_many :voyages
end

class Captain < ActiveRecord::Base
  has_many :voyages
end

class Voyage < ActiveRecord::Base
  belongs_to :ship
  belongs_to :captain, optional: true
  belongs_to :patron, polymorphic: true, optional: true
  alias_attribute :distance, :leagues
end
