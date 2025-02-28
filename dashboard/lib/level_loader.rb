require 'set'

class LevelLoader
  # Top-level entry point, called by rake seed:custom_levels
  def self.load_custom_levels(level_name)
    import_levels(Policies::LevelFiles.level_file_glob(level_name))
  end

  #
  # Loads a group of level files from disk and imports them into the database.
  #
  # - Level files not found in the database will be created.
  # - Level files found in the database will be updated if they don't match the
  #   file as loaded from disk.
  #
  # @param [String] level_file_glob - dashboard-relative, wildcard-friendly path
  #   to one or more .level files.
  #   Examples:
  #     'config/scripts/levels/K-1 Bee 2.level'
  #     'config/scripts/**/*.level'
  #
  def self.import_levels(level_file_glob)
    level_file_paths = file_paths_from_glob(level_file_glob)

    # This is only expected to happen when LEVEL_NAME is set and the
    # filename is not found
    unless level_file_paths.count > 0
      raise 'no matching level names found. ' \
        'please check level name for exact case and spelling. ' \
        'the level name is the level filename without the .level suffix.'
    end

    # Use a transaction because loading levels requires two separate imports.
    Level.transaction do
      level_md5s_by_name = Hash[Level.pluck(:name, :md5)]
      existing_level_names = level_md5s_by_name.keys.to_set

      level_file_names = level_file_paths.map do |path|
        Policies::LevelFiles.level_name_from_path(path)
      end

      if level_file_names.include? 'blockly'
        raise 'custom levels must not be named "blockly"'
      end

      # First, save stubs of any new levels - they'll need to have ids in
      # order to create certain associations (in particular
      # level_concept_difficulty) when we bulk-load the level properties.
      new_level_names = level_file_names.
        reject {|name| existing_level_names.include? name}
      Level.import! new_level_names.map {|name| {name: name}}

      # Load level properties from disk and build a collection of levels that
      # have changed.
      changed_levels = level_file_paths.
          filter_map {|path| Services::LevelFiles.load_custom_level(path, level_md5s_by_name)}.
          select(&:changed?)

      if [:development, :adhoc].include?(rack_env) && !CDO.properties_encryption_key
        puts "WARNING: skipping seeding encrypted levels because CDO.properties_encryption_key is not defined"
        changed_levels.reject!(&:encrypted?)
      end

      dsl_levels = changed_levels.select {|l| l.is_a? DSLDefined}
      if dsl_levels.any?
        raise "cannot define DSLDefined level types in .level files: #{dsl_levels.map {|l| "#{l.name}.level".dump}.join(',')}"
      end

      # activerecord-import (with MySQL, anyway) doesn't save associated
      # models, so we've got to do this manually.
      immutable_lcd_columns = %i{id level_id created_at}
      changed_lcds = changed_levels.filter_map(&:level_concept_difficulty)
      lcd_update_columns = LevelConceptDifficulty.columns.map(&:name).map(&:to_sym).
        reject {|column| immutable_lcd_columns.include? column}
      LevelConceptDifficulty.import! changed_lcds, on_duplicate_key_update: lcd_update_columns

      # activerecord-import doesn't trigger before_save and before_create hooks
      # for imported models, so we trigger these manually to make sure they're
      # set up the same way they would be otherwise.
      # @see https://github.com/zdennis/activerecord-import/wiki/Callbacks
      changed_levels.each do |level|
        level.run_callbacks(:save) {false}
        level.run_callbacks(:create) {false}
      end

      # Bulk-import changed levels.
      immutable_level_columns = %i(id name created_at)
      update_columns = Level.columns.map(&:name).map(&:to_sym).
        reject {|column| immutable_level_columns.include? column}
      Level.import! changed_levels, on_duplicate_key_update: update_columns

      # now we want to run some after_save callbacks, which didn't get run when
      # by run_callbacks earlier. it seems too risky to run all after_save
      # callbacks automatically, because someone modifying the level edit
      # experience of any individual level could add an after_save callback
      # which modifies the DB and which they expect to get run only on
      # levelbuilder. so, just run the callbacks we're sure we need instead.
      changed_levels.each do |level|
        level.setup_contained_levels
        level.setup_project_template_level
      end
    end
  end

  private_class_method def self.file_paths_from_glob(glob)
    Dir.glob(Rails.root.join(glob)).sort
  end
end
