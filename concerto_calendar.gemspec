$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "concerto_calendar/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "concerto_calendar"
  s.version     = ConcertoCalendar::VERSION
  s.authors     = ["Marvin Frederickson"]
  s.email       = ["marvin.frederickson@gmail.com"]
  s.homepage    = "https://github.com/concerto/concerto-calendar/"
  s.summary     = "Calendar Content for Concerto 2."
  s.description = "Simple support to render google calendar v2/v3 or iCal content in Concerto 2."
  s.license     = 'Apache 2.0'

  s.files = Dir["{app,config,db,lib,public}/**/*"] + ["LICENSE", "Rakefile", "README.md"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails"
  s.add_dependency "google-api-client"
  s.add_dependency "icalendar", '~> 1.5'

  s.add_development_dependency "sqlite3"
end
