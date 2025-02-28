# A module that allows us to dynamically turn on and off
# features without requiring a code push.
#
# Basic usage:
# if Gatekeeper.allows("new-tutorial", default: false)
#   # shows the new tutorial
# else
#   # raise a 403
# end
#
# Advanced usage:
# You can also pass conditions that allow for more complex
# configuration of access.  For example:
#
# if Gatekeeper.allows("feature-sharing", where: { script_id: @script.id }, default: false)
#
# This allows you to turn on feature-sharing for specific scripts

require 'dynamic_config/datastore_cache'
require 'dynamic_config/dynamic_config_base'
require 'dynamic_config/environment_aware_dynamic_config_helper'
require 'dynamic_config/adapters/dynamodb_adapter'
require 'dynamic_config/adapters/json_file_adapter'
require 'dynamic_config/adapters/memory_adapter'

class GatekeeperBase < DynamicConfigBase
  # @param feature [String] the name of the feature
  # @param where [Hash] a hash of conditions
  # @param default [Bool] the default value to return
  # @returns [Bool]
  def allows(feature, where: {}, default: false)
    rule_map = get_rule_map(feature)
    conditions = []
    conditions << where_key(where)
    conditions << where_key({}) unless where.empty?

    conditions.each do |k|
      return rule_map[k] if rule_map.key? k
    end

    default
  end

  def disallows(*params)
    !allows(*params)
  end

  # Sets the value for a given feature/where combo
  # @param feature [String]
  # @param where [Hash]
  # @param value [Bool]
  def set(feature, where: {}, value: nil)
    raise ArgumentError, "Value must be a boolean" unless !!value == value

    rule_map = get_rule_map(feature)
    rule_map[where_key(where)] = value
    super(feature, rule_map)
  end

  # Deletes a specific where clause
  # @param feature [String]
  # @param where [Hash]
  # @returns [Bool] whether or not something was deleted
  def delete(feature, where: {})
    raise ArgumentError, "feature must be a string" unless feature.is_a? String

    rule_map = get_rule_map(feature)
    key = where_key(where)
    if rule_map.key? key
      rule_map.delete key
      # This is a little odd, but in Ruby 2 if the last argument of a method
      # call is a Hash, Ruby will attempt to interpret it as a hash of keyword
      # arguments and so we can get some unexpected behavior when `rule_map`
      # ends up as an empty hash.
      #
      # To prevent that, explicitly pass a (no-op) hash of keyword arguments to
      # this method call so it never attempts to use rule_map for that purpose.
      #
      # TODO after updating to Ruby 3.0: remove the now-unnecessary `**{}`
      @datastore_cache.set(feature, rule_map, **{})
      return true
    end
    false
  end

  # Returns the mapping of conditions to bool for the given feature
  # @param feature [String]
  # @returns [Hash]
  def get_rule_map(feature)
    json_map = @datastore_cache.get(feature)
    return json_map unless json_map.nil?
    return {}
  end

  # Generates the key for the where clause
  # @param where [Hash]
  # returns [String]
  def where_key(where)
    Oj.dump(stringify_keys(where).sort, mode: :strict)
  end

  # Factory method for creating GatekeeperBase objects
  # @returns [GatekeeperBase]
  def self.create
    datastore_cache = EnvironmentAwareDynamicConfigHelper.create_datastore_cache(CDO.gatekeeper_table_name)
    GatekeeperBase.new datastore_cache
  end

  # Returns the hash version of gatekeeper
  def to_hash
    gatekeeper = {}

    @datastore_cache.all.each do |feature, rules|
      gatekeeper[feature] = feature_details = []
      rules.each do |conditions, value|
        rule = {"rule" => nil}

        conditions = JSON.parse(conditions)
        unless conditions.empty?
          where_clause = {}
          rule['where'] = where_clause
          conditions.each do |property, property_value|
            where_clause[property] = property_value
          end
        end
        rule['value'] = value
        feature_details << rule
      end
    end
    gatekeeper
  end

  # Returns a set of all of the distinct feature names, for features that contain at least one rule.
  def feature_names
    Set.new.tap do |result|
      @datastore_cache.all.each do |feature, rules|
        result << feature unless rules.blank?
      end
    end
  end

  # Returns a set of all of the script names used in rule conditions.
  def script_names
    property_values('script_name')
  end

  # Returns a set of all of the distinct values used in where conditions for
  # the property named `condition_property`.
  def property_values(condition_property)
    Set.new.tap do |result|
      @datastore_cache.all.each do |_feature, rules|
        rules.each do |conditions, _value|
          JSON.parse(conditions).each do |property, value|
            result << value if property == condition_property
          end
        end
      end
    end
  end

  # Converts the current config state to a yaml string
  # @returns [String]
  # @override
  def to_yaml
    YAML.dump(to_hash)
  end

  def refresh
    @datastore_cache.update_cache
  end

  private def stringify_keys(hsh)
    hsh.inject({}) do |hash, pair|
      hash[pair[0].to_s] = pair[1]
      hash
    end
  end
end

Gatekeeper = GatekeeperBase.create
