class User < ApplicationRecord
  has_many :articles, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :access_token, presence: true, uniqueness: true
end
