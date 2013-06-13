function attachHandlers() {
  $('select#calendar_config_calendar_source').on('change', revealRelevantFields);

  function revealRelevantFields() {
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
  }

  revealRelevantFields();

  $("input#calendar_config_start_date.datefield").datepicker();
  $("input#calendar_config_end_date.datefield").datepicker();
}

$(document).ready(attachHandlers);
$(document).on('page:change', attachHandlers);
