class TimeOfDay
  include Comparable

  attr_reader :hour, :minute, :second, :day_offset, :utc_offset, :second_offset
  alias min minute
  alias sec second

  def initialize(hour, minute = nil, second = nil, day_offset: nil, utc_offset: nil)
    @hour = hour.to_i
    @minute = minute.to_i
    @second = second.to_i
    @day_offset = day_offset.to_i
    @utc_offset = utc_offset.to_i

    @second_offset = ((@day_offset * 24 + @hour) * 60 + @minute) * 60 + @second - @utc_offset
  end

  def self.create(time = nil, attributes = nil)
    attributes ||= {}

    %i{hour minute min second sec day_offset time_zone}.each do |attribute|
      attributes[attribute] = time.send(attribute) if time.respond_to?(attribute)
    end

    if minute = attributes.delete(:min)
      attributes[:minute] = minute
    end
    if second = attributes.delete(:sec)
      attributes[:second] = second
    end

    if zone = attributes.delete(:time_zone)
      attributes[:utc_offset] = zone.utc_offset
    end

    new attributes.fetch(:hour), attributes[:minute], attributes[:second], attributes.except(:hour, :minute, :second)
  end

  def self.from_second_offset(offset, utc_offset: 0)
    offset += utc_offset

    day_offset = offset / 1.day
    offset = offset % 1.day

    hour = offset / 1.hour
    offset = offset % 1.hour

    minute = offset / 1.minute
    second = offset % 1.minute

    TimeOfDay.new hour, minute, second, day_offset: day_offset, utc_offset: utc_offset
  end

  def without_utc_offset
    self.class.from_second_offset second_offset
  end

  def add(seconds: 0, day_offset: 0)
    self.class.from_second_offset second_offset + seconds + day_offset.days, utc_offset: utc_offset
  end

  def with_utc_offset(utc_offset)
    self.class.from_second_offset second_offset, utc_offset: utc_offset
  end

  def with_zone(time_zone)
    time_zone = ActiveSupport::TimeZone[time_zone] if time_zone.is_a?(String)
    with_utc_offset(time_zone&.utc_offset || 0)
  end

  def with_day_offset(offset)
    self.class.from_second_offset second_offset + (offset-day_offset).days, utc_offset: utc_offset
  end

  def day_offset?
    day_offset != 0
  end

  def utc_offset?
    utc_offset != 0
  end

  SIMPLE_FORMAT = "%.2d:%.2d:%.2d"
  def to_hms
    SIMPLE_FORMAT % [hour, minute, second]
  end

  def to_s
    [].tap do |parts|
      parts << to_hms
      parts << "day:#{day_offset}" if day_offset?
      parts << "utc_offset:#{utc_offset}" if utc_offset?
    end.join(' ')
  end

  def to_vehicle_journey_at_stop_time
    ::Time.new(2000, 1, 1, hour, minute, second, "+00:00")
  end

  def to_iso_8601
    @iso_8601 ||= ISO8601.new(self).to_s
  end

  def -(other)
    second_offset - other.second_offset
  end

  class ISO8601 < SimpleDelegator

    UTC_FORMAT = "%.2d:%.2d:%.2dZ"
    NON_UTC_FORMAT = "%.2d:%.2d:%.2d%s%.2d:%.2d"

    def to_s
      unless utc_offset?
        UTC_FORMAT % [hour, minute, second]
      else
        NON_UTC_FORMAT % [hour, minute, second, sign_utc_offset, hour_utc_offset, minute_utc_offset]
      end
    end

    def sign_utc_offset
      utc_offset >= 0 ? '+' : '-'
    end

    def hour_utc_offset
      utc_offset.abs / 1.hour
    end

    def minute_utc_offset
      utc_offset.abs % 1.hour / 1.minute
    end

  end

  def <=>(other)
    return unless other.respond_to?(:second_offset)
    @second_offset <=> other.second_offset
  end

  PARSE_REGEX = /
      \A
      ([01]?\d|2[0-4])
      :?
      ([0-5]\d)?
      :?
      ([0-5]\d)?
      \z
    /x

  def self.parse(definition, attributes = nil)
    if PARSE_REGEX =~ definition
      hour, minute, second = $1, $2, $3
      new hour, minute, second, attributes || {}
    end
  end

  def self.unserialize(value, attributes = nil)
    return nil if value.nil?

    if value.is_a?(String)
      parse value, attributes
    else
      create value, attributes
    end
  end

end
