articles = [
  { title: "Getting Started with Ruby on Rails", original_content: "Ruby on Rails is a server-side web application framework written in Ruby." },
  { title: "Building APIs with Grape", original_content: "Grape is a REST-like API micro-framework for Ruby." },
  { title: "Understanding RESTful APIs", original_content: "REST stands for Representational State Transfer, a common architectural style for APIs." },
]

articles.each do |attrs|
  Article.find_or_create_by!(title: attrs[:title]) do |a|
    a.original_content = attrs[:original_content]
  end
end
