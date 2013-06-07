class Calendar < DynamicContent

  DISPLAY_NAME = 'Calendar'
  DISPLAY_FORMATS = { "List (Multiple)" => "headlines", "Detailed (Single)" => "detailed" }

  validate :validate_config

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
        result.data.items.each_slice(5).with_index do |items, index|
          htmltext = HtmlText.new()
          htmltext.name = "#{result.data.summary} (#{index+1})"
          htmltext.data = "<h1>#{result.data.summary}</h1>#{items_to_html(items, day_format, time_format)}"
          contents << htmltext
        end
      when 'detailed' # each item is a separate entry, title and description
        result.data.items.each_with_index do |item, index|
          htmltext = HtmlText.new()
          htmltext.name = "#{result.data.summary} (#{index+1})"
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
    client_key = self.config['api_key']
    calendar_id = self.config['calendar_id']

    # ---------------------------------- google calendar api v3
    require 'google/api_client'

    client = Google::APIClient.new
    client.authorization = nil
    client.key = client_key
    
    cal = client.discovered_api('calendar', 'v3')

    params = {}
    params['calendarId'] = calendar_id
    params['maxResults'] = self.config['max_results']
    params['singleEvents'] = true
    params['orderBy'] = 'startTime'
    params['fields'] = "description,items(description,end,endTimeUnspecified,location,organizer/displayName,source/title,start,status,summary,updated),summary,timeZone,updated"
    params['timeMin'] = Clock.time.beginning_of_day.iso8601
    params['timeMax'] = (Clock.time.beginning_of_day + self.config['days_ahead'].to_i.days).end_of_day.iso8601

    result = client.execute(:api_method => cal.events.list, :parameters => params)
  end

  def item_to_html(item, day_format, time_format)
    html = []
    html << "<h1>#{item.summary}</h1>"
    html << "<h2>#{item.start.dateTime.strftime(day_format)}</h2>" 
    html << "<div class=\"cal-time\">#{item.start.dateTime.strftime(time_format)} - #{item.end.dateTime.strftime(time_format)}</div>"
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
      if last_date != item.start.dateTime.to_date
        if last_date.nil?
          # dont need to close list
        else
          html << "</dl>"
        end
        html << "<h2>#{item.start.dateTime.strftime(day_format)}</h2>"
        html << "<dl>"
      end
      # todo: end time should include date if different
      html << "<dt>#{item.start.dateTime.strftime(time_format)} - #{item.end.dateTime.strftime(time_format)}</dt>"
      html << "<dd>#{item.summary}</dd>"
      last_date = item.start.dateTime.to_date
    end
    html << "</dl>" if !last_date.nil?
    return html.join("")
  end

  # calendar api parameters and preferred view (output_format)
  def self.form_attributes
    attributes = super()
    attributes.concat([:config => [
      :api_key,
      :calendar_id, 
      :max_results,
      :days_ahead,
      :output_format,
      :day_format,
      :time_format
    ]])
  end

  def validate_config
    if self.config['api_key'].blank?
      errors.add(:config_api_key, "can't be blank")
    end
    if self.config['calendar_id'].blank?
      errors.add(:config_calendar_id, "can't be blank")
    end
    if self.config['max_results'].blank?
      errors.add(:config_max_results, "can't be blank")
    end
    if self.config['days_ahead'].blank?
      errors.add(:config_days_ahead, "can't be blank")
    end
    if !DISPLAY_FORMATS.values.include?(self.config['output_format'])
      errors.add(:config_output_format, "must be #{DISPLAY_FORMATS.keys.join(' or ')}")
    end
    # todo: validate strftime components in day_format and time_format?

    begin
      validate_request if !self.config['api_key'].blank?
    rescue => e
      errors.add(:config_api_key, e.message)
    end
  end

  # make sure the request is valid by fetching a result back
  def validate_request
    result = fetch_calendar

    if result.error?
      raise result.error_message
    end
  end
end
