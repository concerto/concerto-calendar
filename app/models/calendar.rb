class Calendar < DynamicContent
  after_initialize :set_defaults, :on => :new
  validate :validate_config, :on => :create

  # this is the common class used for holding the content to be rendered
  # it is populated from the various calendar sources
  class CalendarResults
    class CalendarResultItem
      attr_accessor :name, :description, :location, :start_time, :end_time

      def initialize(name, description, location, start_time, end_time)
        @name=name
        @description = description
        @location = location
        @start_time = start_time
        @end_time = end_time
      end
    end

    attr_accessor :error_message, :name, :items

    def initialize
      self.items = []
      self.name = ""
      self.error_message = ""
    end

    def error?
      !self.error_message.empty?
    end

    def add_item(name, description, location, start_time, end_time)
      self.items << CalendarResultItem.new(name, description, location, start_time, end_time)
    end
  end

  DISPLAY_FORMATS = { 
    "List (Multiple)" => "headlines", 
    "Detailed (Single)" => "detailed" 
  }
  CALENDAR_SOURCES = { # exclude RSS and ATOM since cant get individual fields
    "Google" => "google", 
    "iCal" => "ical", 
#    "Bedework JSON" => "bedeworkjson" 
  }  

  def set_defaults
    self.config['calendar_source'] ||= 'ical'
    self.config['day_format'] ||= '%A %b %e'
    self.config['time_format'] ||= '%l:%M %P'
    self.config['max_results'] ||= 10
  end

  def build_content
    contents = []
    result = fetch_calendar

    if result.error?
      raise result.error_message
    else
      day_format = self.config['day_format']
      time_format = self.config['time_format']

      case self.config['output_format']
      when 'headlines' # 5 items per entry, titles only
        result.items.each_slice(5).with_index do |items, index|
          htmltext = HtmlText.new()
          htmltext.name = "#{result.name} (#{index+1})"
          htmltext.data = "<h1>#{result.name}</h1>#{items_to_html(items, day_format, time_format)}"
          contents << htmltext
        end
      when 'detailed' # each item is a separate entry, title and description
        result.items.each_with_index do |item, index|
          htmltext = HtmlText.new()
          htmltext.name = "#{result.name} (#{index+1})"
          htmltext.data = item_to_html(item, day_format, time_format)
          contents << htmltext
        end
      else
        raise ArgumentError, 'Unexpected output format for Calendar feed.'
      end
    end

    return contents
  end

  def fetch_calendar
    result = CalendarResults.new
    client_key = self.config['api_key']
    calendar_id = self.config['calendar_id']
    calendar_source = self.config['calendar_source']
    start_date = self.config['start_date'].strip.empty? ? Clock.time.beginning_of_day.iso8601 : self.config['start_date'].to_time.beginning_of_day.iso8601
    end_date = self.config['end_date'].strip.empty? ? (start_date.to_time.beginning_of_day + self.config['days_ahead'].to_i.days).end_of_day.iso8601 : self.config['end_date'].to_time.beginning_of_day.iso8601

    case calendar_source
    when 'google'
      if !client_key.empty?
        # ---------------------------------- google calendar api v3 via client api
        require 'google/api_client'

        client = Google::APIClient.new
        client.authorization = nil
        client.key = client_key
        
        cal = client.discovered_api('calendar', 'v3')

        params = {}
        params['calendarId'] = calendar_id
        params['maxResults'] = self.config['max_results'] if !params['max_results'].blank?
        params['singleEvents'] = true
        params['orderBy'] = 'startTime'
        params['fields'] = "description,items(description,end,endTimeUnspecified,location,organizer/displayName,source/title,start,status,summary,updated),summary,timeZone,updated"
        params['timeMin'] = start_date
        params['timeMax'] = end_date

        tmp = client.execute(:api_method => cal.events.list, :parameters => params)

        # convert to common data structure
        result.error_message = tmp.error_message if tmp.error?
        if !result.error?
          result.name = tmp.data.summary
          tmp.data.items.each do |item|
            result.add_item(item.summary, item.description, item.location, item.start.dateTime, item.end.dateTime)
          end
        end
      else
        # ---------------------------------- public calendar via plain http
        require 'net/http'
        url = "http://www.google.com/calendar/feeds/#{calendar_id}/public/full?alt=json"
        params = {}
        params['max-results'] = self.config['max_results'] if !params['max_results'].blank?
        params['singleevents'] = true
        params['orderby'] = 'starttime'
        params['start-min'] = start_date
        params['start-max'] = end_date
        url += params.collect { |k,v| "&#{k}=#{v}" }.join()

        tmp = nil
        begin
          json_data = Net::HTTP.get_response(URI.parse(url)).body
          tmp = JSON.load(json_data)
        rescue => e
          result.error_message = e.message
        end

        # convert to common data structure
        if !result.error?
          result.name = tmp["feed"]["title"]["$t"]
          tmp["feed"]["entry"].each do |item|
            location = item["gd$where"].first["valueString"]
            start_time = item["gd$when"].first["startTime"].to_time
            end_time = item["gd$when"].first["endTime"].to_time
            result.add_item(item["title"]["$t"], item["content"]["$t"], location, start_time, end_time)
          end
        end
      end
    when 'ical'
        # ---------------------------------- iCal calendar 
        # need to filter manually below because the url may not accommodate filtering
        # so respect self.config[max_results] and start_date and end_date (which incorporates the days ahead)
        require 'open-uri'
        require 'icalendar'

        begin
          url = self.config['calendar_url']
          calendars = nil
          open(URI.parse(url)) do |cal|
            calendars = Icalendar.parse(cal)
          end

          max_results = self.config['max_results'].to_i
          result.name =  self.name    # iCal doesn't provide a calendar name, so use the user's provided name
          calendars.first.events.each do |item|
            title = item.summary
            description = item.description
            location = item.location
            item_start_time = item.dtstart.to_time unless item.dtstart.nil?
            item_end_time = item.dtend.to_time unless item.dtend.nil?
            # make sure the item's start date is within the specified range
            if item_start_time >= start_date && item_start_time < end_date
              result.add_item(title, description, location, item_start_time, item_end_time)
            end
          end
          result.items.sort! { |a, b| a.start_time <=> b.start_time }
          result.items = result.items[0..(max_results -1)]
        rescue => e
          result.error_message = e.message
        end
    else
      result.error_message = "unsupported calendar source #{calendar_source}"
    end

    return result
  end

  def item_to_html(item, day_format, time_format)
    start_time = item.start_time.strftime(time_format)
    end_time = item.end_time.strftime(time_format) unless item.end_time.nil?

    html = []
    html << "<h1>#{item.name}</h1>"
    html << "<h2>#{item.start_time.strftime(day_format)}</h2>" 
    html << (end_time.nil? ? "<div class=\"cal-time\">#{start_time}</div>" : "<div class=\"cal-time\">#{start_time} - #{end_time}</div>") unless start_time == end_time
    html << "<div class=\"cal-location\">#{item.location}</div>"
    html << "<p>#{item.description}</p>"
    return html.join("")
  end

  # display date (only when it changes) / times with title...
  def items_to_html(items, day_format, time_format)
    html = []
    last_date = nil
    items.each do |item|
      # see if we need a date header
      if last_date != item.start_time.to_date
        if last_date.nil?
          # dont need to close list
        else
          html << "</dl>"
        end
        html << "<h2>#{item.start_time.strftime(day_format)}</h2>"
        html << "<dl>"
      end
      # todo: end time should include date if different
      start_time = item.start_time.strftime(time_format)
      end_time = item.end_time.strftime(time_format) unless item.end_time.nil?

      html << (end_time.nil? ? "<dt>#{start_time}</dt>" : "<dt>#{start_time} - #{end_time}</dt>") unless start_time == end_time
      html << "<dd>#{item.name}</dd>"
      last_date = item.start_time.to_date
    end
    html << "</dl>" if !last_date.nil?
    return html.join("")
  end

  # calendar api parameters and preferred view (output_format)
  def self.form_attributes
    attributes = super()
    attributes.concat([:config => [
      :calendar_source, # google or ical (or bedework JSON eventually)
      :api_key,         # google
      :calendar_id,     # google
      :calendar_url,    # iCal url (specify parms in url manually)
      :max_results,
      :days_ahead,
      :start_date,
      :end_date,
      :output_format,   # all cals
      :day_format,      # all cals
      :time_format      # all cals
    ]])
  end

  def validate_config
    # if self.config['api_key'].blank?
    #   errors.add(:config_api_key, "can't be blank")
    # end

    prerequisites_met = true
    if self.config['calendar_id'].blank? && self.config['calendar_source'] == "google"
      errors.add(:config_calendar_id, "can't be blank")
      prerequisites_met = false
    end
    if self.config['calendar_url'].blank? && self.config['calendar_source'] != "google"
      errors.add(:config_calendar_url, "can't be blank")
      prerequisites_met = false
    end
    if self.config['max_results'].blank? 
      errors.add(:config_max_results, "can't be blank")
    end
    # if self.config['days_ahead'].blank?  && self.config['end_date'].blank? 
    #   errors.add(:config_days_ahead, "days ahead or end_date must be specified")
    # end
    if !self.config['start_date'].blank? && !self.config['end_date'].blank?
      start_date = self.config['start_date'].to_date
      end_date = self.config['end_date'].to_date
      if start_date > end_date
        errors.add(:config_start_date, "must precede end date")
      end
    end
    if !CALENDAR_SOURCES.values.include?(self.config['calendar_source'])
      errors.add(:config_calendar_source, "must be #{CALENDAR_SOURCES.keys.join(' or ')}")
    end
    if !DISPLAY_FORMATS.values.include?(self.config['output_format'])
      errors.add(:config_output_format, "must be #{DISPLAY_FORMATS.keys.join(' or ')}")
    end
    # todo: validate strftime components in day_format and time_format?

    begin
      validate_request #if !self.config['api_key'].blank?
    rescue => e
      errors.add(:base, "Could not fetch calendar - #{e.message}")
    end if prerequisites_met
  end

  # make sure the request is valid by fetching a result back
  def validate_request
    result = fetch_calendar

    if result.error?
      raise result.error_message
    end
  end
end
