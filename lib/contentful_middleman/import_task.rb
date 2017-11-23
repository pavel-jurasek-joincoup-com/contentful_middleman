# encoding: utf-8

module ContentfulMiddleman
  class ImportTask
    def initialize(space_name, content_type_names, content_type_mappers, contentful)
      @space_name           = space_name
      @content_type_names   = content_type_names
      @content_type_mappers = content_type_mappers
      @changed_local_data   = false
      @contentful           = contentful
    end

    def run
      old_version_hash = ContentfulMiddleman::VersionHash.read_for_space(@space_name)

      LocalData::Store.new(local_data_files, @space_name).write

      new_version_hash = ContentfulMiddleman::VersionHash.write_for_space_with_entries(@space_name, entries)

      @changed_local_data = new_version_hash != old_version_hash
    end

    def changed_local_data?
      @changed_local_data
    end

    def entries
      @entries ||= @contentful.entries
    end

    def file_name(content_type_name, entry)
      entry_id = entry.sys.key?(:id) ? entry.sys[:id] : entry.id
      File.join(@space_name, content_type_name, entry_id.to_s)
    end

    private
    def local_data_files
      entries.map do |entry|
        content_type_mapper_class = @content_type_mappers.fetch(entry.sys[:content_type].id, nil)

        next unless content_type_mapper_class

        content_type_name = @content_type_names.fetch(entry.sys[:content_type].id).to_s
        context = ContentfulMiddleman::Context.new

        content_type_mapper = content_type_mapper_class.new(entries, @contentful.options)
        content_type_mapper.map(context, entry)

        LocalData::File.new(context.to_yaml, file_name(content_type_name, entry))
      end.compact
    end
  end
end
