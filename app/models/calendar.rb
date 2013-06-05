class Calendar < DynamicContent

  DISPLAY_NAME = 'Calendar'

  validate :validate_config

  def build_content
    require 'google/api_client'
   
    contents = []

    client = Google::APIClient.new
    client.authorization = nil
    client.key = self.config['api_key']
    
    cal = client.discovered_api('calendar', 'v3')

    params = {}
    params['calendarId'] = self.config['calendar_id']
    params['maxResults'] = self.config['max_results']
    params['singleEvents'] = true
    params['orderBy'] = 'startTime'
    params['fields'] = "description,items(description,end,endTimeUnspecified,location,organizer/displayName,source/title,start,status,summary,updated),summary,timeZone,updated"
    params['timeMin'] = Clock.time.beginning_of_day.iso8601
    params['timeMax'] = (Clock.time.beginning_of_day + self.config['days_ahead'].to_i.days).end_of_day.iso8601

    result = client.execute(:api_method => cal.events.list, 
      :parameters => params)

    if result.error?
      raise result.error_message
    else
      case self.config['output_format']
      when 'headlines' # 5 items per entry, titles only
        result.data.items.each_slice(5).with_index do |items, index|
          htmltext = HtmlText.new()
          htmltext.name = "#{result.data.summary} (#{index+1})"
          htmltext.data = "<h1>#{result.data.summary}</h1> #{items_to_html(items)}"
          contents << htmltext
        end
      when 'detailed' # each item is a separate entry, title and description
        result.data.items.each_with_index do |item, index|
          htmltext = HtmlText.new()
          htmltext.name = "#{result.data.summary} (#{index+1})"
          htmltext.data = item_to_html(item)
          contents << htmltext
        end
      else
        raise ArgumentError, 'Unexpected output format for Calendar feed.'
      end
    end

    return contents
  end

  def item_to_html(item)
    return "<h1>#{item.summary}</h1><p>#{item.start.dateTime} - #{item.end.dateTime}</p><p>#{item.description}</p><p>#{item.location}</p>"
  end

  def items_to_html(items)
    return items.collect{|item| "<h2>#{item.start.dateTime} - #{item.summary}</h2>"}.join(" ")
  end

  # calendar api parameters and preferred view (output_format)
  def self.form_attributes
    attributes = super()
    attributes.concat([:config => [
      :api_key,
      :calendar_id, 
      :max_results,
      :days_ahead,
      :output_format
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
    if !['headlines', 'detailed'].include?(self.config['output_format'])
      errors.add(:config_output_format, "must be Headlines (multiple) or Details (single)")
    end

    begin
      validate_request
    rescue => e
      errors.add(:config_api_key, e.message)
    end
  end

  # make sure the request is valid by fetching a result back
  def validate_request
    require 'google/api_client'

    client = Google::APIClient.new
    client.authorization = nil
    client.key = self.config['api_key']
    
    cal = client.discovered_api('calendar', 'v3')

    params = {}
    params['calendarId'] = self.config['calendar_id']
    params['maxResults'] = 1

    result = client.execute(:api_method => cal.events.list, 
      :parameters => params)

    if result.error?
      raise result.error_message
    end
  end
end
