class Article < ApplicationRecord
  enum :status, {
    draft: "draft",
    reviewed: "reviewed",
    published: "published",
  }, default: :draft

  validates :title, presence: true
  validates :status, presence: true, inclusion: { in: statuses.keys }

  serialize :parsed_fields, coder: JSON
end
