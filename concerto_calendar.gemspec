$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "concerto_calendar/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "concerto_calendar"
  s.version     = ConcertoCalendar::VERSION
  s.authors     = ["Brian Michalski"]
  s.email       = ["bmichalski@gmail.com"]
  s.homepage    = "https://github.com/concerto/concerto-calendar/"
  s.summary     = "Calendar Content for Concerto 2."
  s.description = "Simple support to render google calendar content in Concerto 2."

  s.files = Dir["{app,config,db,lib,public}/**/*"] + ["LICENSE", "Rakefile", "README.md"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 3.2.11"
  s.add_dependency "google-api-client"

  s.add_development_dependency "sqlite3"
end
