var ConcertoCalendar = {
  _initialized: false,

  revealRelevantFields: function () {
    var vendor = $('select#calendar_config_calendar_source').val();
    if (vendor == 'google') {
      $('input#calendar_config_api_key').closest('div.clearfix').show();
      $('input#calendar_config_calendar_id').closest('div.clearfix').show();
      $('input#calendar_config_calendar_url').closest('div.clearfix').hide();
    } else if (vendor == 'ical') {
      $('input#calendar_config_api_key').closest('div.clearfix').hide();
      $('input#calendar_config_calendar_id').closest('div.clearfix').hide();
      $('input#calendar_config_calendar_url').closest('div.clearfix').show();
    }
  },

  initHandlers: function () {
    if (ConcertoCalendar._initialized) {
      // console.debug('already initialized Calendar handlers');
    } else {
      // console.debug('initializing Calendar Handlers');
      $('select#calendar_config_calendar_source').on('change', ConcertoCalendar.revealRelevantFields);
      ConcertoCalendar.revealRelevantFields();

      $("input#calendar_config_start_date.datefield").datepicker();
      $("input#calendar_config_end_date.datefield").datepicker();
      ConcertoCalendar._initialized = true;
    }
  }
};

$(document).ready(ConcertoCalendar.initHandlers);
$(document).on('turbolinks:load', ConcertoCalendar.initHandlers);
