module ConcertoCalendar
  class Engine < ::Rails::Engine
    isolate_namespace ConcertoCalendar

    initializer "register content type" do |app|
      app.config.content_types << Calendar
    end
  end
end
