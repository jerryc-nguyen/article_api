module ArticleManagement
  module Serializers
    class ArticleSerializer < Grape::Entity
      expose :id
      expose :title
      expose :status
      expose :parsed_fields
      expose :fields_version
      expose :original_content
      expose :content_hash
      expose :created_at
      expose :updated_at
    end
  end
end
