class System < ApplicationRecord
  has_many :users
  has_many :chat_messages
  has_many :locations
  
  enum security_status: [:high, :medium, :low]
end