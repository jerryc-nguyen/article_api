user = User.find_or_create_by!(name: "Nhan") do |u|
  u.access_token = SecureRandom.hex(32)
end

articles = [
  {
    title: "Getting Started with Ruby on Rails",
    original_content: "Ruby on Rails is a server-side web application framework written in Ruby. It provides a full MVC architecture out of the box.",
    parsed_fields: {
      intro_hook: "Ruby on Rails gives you the power to build scalable web apps faster than ever.",
      main_article_body: [
        { heading: "What is Rails?", content: "Rails is a full-stack MVC framework that emphasizes convention over configuration." },
        { heading: "Getting Started", content: "Install Rails with `gem install rails`, then run `rails new my_app`." },
      ],
      best_for: "beginners, web developers, startups",
      not_for: "real-time applications, microservices purists",
      ethics_safety_notes: "Always validate user input and follow security best practices like using parameterized queries.",
      key_facts: [
        { label: "First Release", value: "2004" },
        { label: "Latest Version", value: "8.1" },
      ],
    }.to_json,
    content_hash: Digest::SHA256.hexdigest("Ruby on Rails is a server-side web application framework written in Ruby."),
    user: user,
  },
  {
    title: "Building APIs with Grape",
    original_content: "Grape is a REST-like API micro-framework for Ruby. It is designed to run as a mountable rack application.",
    parsed_fields: {
      intro_hook: "Build elegant, maintainable APIs with Grape's clean DSL.",
      main_article_body: [
        { heading: "Why Grape?", content: "Grape provides a lightweight, opinionated way to build RESTful APIs in Ruby." },
        { heading: "Defining an API", content: "Use `get`, `post`, `put`, `patch`, `delete` blocks inside your API class." },
      ],
      best_for: "API developers, Rubyists, microservice architects",
      not_for: "full-stack applications, developers wanting a GUI",
      ethics_safety_notes: "Use rate limiting and proper authentication to secure your Grape APIs.",
      key_facts: [
        { label: "Paradigm", value: "RESTful API framework" },
        { label: "Mounting", value: "Rack-compatible" },
      ],
    }.to_json,
    content_hash: Digest::SHA256.hexdigest("Grape is a REST-like API micro-framework for Ruby."),
    user: user,
  },
]

articles.each do |attrs|
  Article.find_or_create_by!(title: attrs[:title]) do |a|
    a.original_content = attrs[:original_content]
    a.parsed_fields = attrs[:parsed_fields]
    a.content_hash = attrs[:content_hash]
    a.user = attrs[:user]
  end
end
