# frozen_string_literal: true

class Ship < ActiveRecord::Base
  has_many :voyages
end

class Voyage < ActiveRecord::Base
  belongs_to :ship
end
