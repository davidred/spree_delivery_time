# Spree::Order.state_machine.before_transition :to => :payment, :do => :delivery_time_provided?

module Spree
  Order.class_eval do
    include DeliveryTimeControllerHelper

    validate :delivery_time

    def time_high(time_sym)
      return unless [:pickup, :dropoff].include?(time_sym)
      (send(time_sym) + 1.hour).strftime("%l:%M %p")
    end

    def time_low(time_sym)
      return unless [:pickup, :dropoff].include?(time_sym)
      send(time_sym).strftime("%l:%M %p")
    end

    def date_str(time_sym)
      return unless [:pickup, :dropoff].include?(time_sym)
      send(time_sym).strftime("%a, %d %b %Y")
    end

    def date(time_sym)
      return unless [:pickup, :dropoff].include?(time_sym)
      send(time_sym).strftime("%Y-%m-%d")
    end

    def time(time_sym)
      return unless [:pickup, :dropoff].include?(time_sym)
      send(time_sym).strftime("%H:%M:%S")
    end

    def delivery_time_str(time_sym)
      return unless [:pickup, :dropoff].include?(time_sym)
      return "#{date_str(time_sym)} #{time_low(time_sym)}"
    end

    private

    def delivery_time_provided?
      # Is both pickup and dropoff time present?
      if (dropoff.nil? || pickup.nil?)
        errors.add(:order, "must have pickup and dropoff time in the form of 'YYYY-MM-DD HH:MM:SS'")
        return false
      end
      true
    end

    def delivery_time
      # do not perform validation unless updating pickup or dropoff
      return unless pickup_changed? || dropoff_changed?
      set_time_zone
      return unless (pickup || dropoff)
      return false unless delivery_time_provided?
      # return false unless valid_time_format?([pickup, dropoff])
      return false unless valid_time_range?
    end

    # Check that the pickup time and delivery time are in a valid range
    def valid_time_range?
      # Is pickup time later than dropoff time?
      if pickup > dropoff
        errors.add(:pickup_time, 'must be earlier than dropoff time')
        return false
      # Is pickup and dropoff time during operating hours?
      elsif (!pickup.hour.between?(time_open.hour, time_close.hour) || !dropoff.hour.between?(time_open.hour, time_close.hour))
        errors.add(:delivery_time, "must be during our business hours: #{time_open.strftime('%T')} - #{time_close.strftime('%T')}")
        return false
      # Is dropoff time at least min necessary hours from pickup time?
      elsif (dropoff < (pickup + min_hours_from_pickup_to_delivery.hours))
        errors.add(:dropoff_time, "must be at least #{min_hours_from_pickup_to_delivery} hours from pickup time.")
        return false
      # Is pickup time at least min necessary hours from order time? Allow for 30min window to place order.
      elsif (pickup < (Time.zone.now + min_hours_from_order_to_pickup.hours - 30.minutes))
        errors.add(:pickup_time, "must be at least #{min_hours_from_order_to_pickup} hours from now.")
        return false
      end
    end
  end
end
