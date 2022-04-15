require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]  # preprends five zeros to the left of the zipcode string and trims the last 5 values
end

def valid_phone?(formatted_number)
  number_length = formatted_number.length
  return true if number_length == 10
  return false if number_length < 10 || number_length > 11
  return 'formating_required' if formatted_number[0] == 1  
end

def clean_phonenumber(phonenumber)
  formatted_number = phonenumber.split(/\D/).join
  usable_number = valid_phone?(formatted_number)
  case usable_number
  when true then formatted_number
  when false then '0' # if number is unusable, 0 references it
  else formatted_number[-10..-1] # if length is 11 and the first number is 1, trim the first number
  end
end

def clean_regdate(reg_date)
  return reg_date if reg_date.match(%r/^\d{2}\/\d{2}\/\d{4} \d{2}:\d{2}$/) # ex. 09/08/2000

  formatted_regdate = reg_date.split(/\D/).map! do |date_number|
    date_number.rjust(2, '0')
  end
  formatted_regdate[2] = formatted_regdate[2].rjust(4, '20')
  "#{formatted_regdate[0..2].join('/')} #{formatted_regdate[-2..-1].join(':')}"
end

@registered_hours = Hash.new(0)
@registered_wdays = Hash.new(0)

def time_manager(reg_date)
  reg_date_time = Time.strptime(reg_date, '%m/%d/%Y %H:%M')
  wday = reg_date_time.strftime('%A')
  hour = reg_date_time.hour
  @registered_wdays[wday] += 1
  @registered_hours[hour] += 1
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'
  begin
    legislators = civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue 
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_form(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')
  file_path = "output/form_ID#{id}.html"
  File.open(file_path, 'w') { |file| file.puts form_letter }
end

puts 'Event manager initialized!'

contents = CSV.open(
  'event_attendees.csv', 
  headers: true, 
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

puts 'File readed succesfully, storing contents. Hold on a second...'

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phonenumber = clean_phonenumber(row[:homephone])
  legislators = legislators_by_zipcode(zipcode)
  form_letter = erb_template.result(binding)

  reg_date = clean_regdate(row[:regdate])
  time_manager(reg_date)
  save_form(id, form_letter)
end

puts 'The invitation forms where filled and saved with no errors'
puts '(!) Peak registration hour/s'

def peak_values(hash)
  peak_hours = hash.select do |_time_val, signups_num|
    hash.all? { |_other_time_val, other_signups_num| signups_num >= other_signups_num }
  end
end

peak_values(@registered_hours).each_key { |hour| puts "● #{hour}:00 => #{@registered_hours[hour]} sign ups" }
puts '(!) Peak registration day/s:'
peak_values(@registered_wdays).each_key { |wday| puts "● #{wday} => #{@registered_wdays[wday]} sign ups" }
