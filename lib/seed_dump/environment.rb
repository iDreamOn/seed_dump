class SeedDump
  module Environment

    def add_parent(models, reorder, model)
      model.reflect_on_all_associations(:belongs_to).each do |parent|
        key = parent.name.to_s.strip.underscore.singularize.camelize.constantize
        add_parent(models, reorder, models[models.index(key)]) unless reorder.has_key?(key)
      end
      reorder[model.name] = model
    end

    def dump_using_environment(env = {})
      Rails.application.eager_load!

      models_env = env['MODEL'] || env['MODELS']
      models = if models_env
                 models_env.split(',')
                           .collect {|x| x.strip.underscore.singularize.camelize.constantize }
               else
                 ActiveRecord::Base.descendants
               end
      
      reorder = {}

      models.select do |model| 
        if (model.to_s != 'ActiveRecord::SchemaMigration') && 
          model.table_exists? && 
          model.exists? && 
          !model.reflect_on_all_associations(:belongs_to).any? 
          reorder[model.name] = model
          models.delete(model.name)
        end
      end

      models.select do |model| 
        if (model.to_s != 'ActiveRecord::SchemaMigration') && 
            model.table_exists? && 
            model.exists? && 
            model.reflect_on_all_associations(:belongs_to).any? &&
            !model.name.to_s.start_with?('HABTM_')
            model.reflect_on_all_associations(:belongs_to).each do |parent|
              add_parent(models, reorder, model)
         end
            reorder[model.name] = model
            models.delete(model.name)
         end
      end

      models.select do |model|
        if (model.to_s != 'ActiveRecord::SchemaMigration') &&
          model.table_exists? &&
          model.exists?
          reorder[model.name] = model
          models.delete(model.name)
        end
      end

      models = reorder.values

      append = (env['APPEND'] == 'true')

      models_exclude_env = env['MODELS_EXCLUDE']
      if models_exclude_env
        models_exclude_env.split(',')
                          .collect {|x| x.strip.underscore.singularize.camelize.constantize }
                          .each { |exclude| models.delete(exclude) }
      end

      models.each do |model|
        model = model.limit(env['LIMIT'].to_i) if env['LIMIT']

        SeedDump.dump(model,
                      append: append,
                      batch_size: (env['BATCH_SIZE'] ? env['BATCH_SIZE'].to_i : nil),
                      exclude: (env['EXCLUDE'] ? env['EXCLUDE'].split(',').map {|e| e.strip.to_sym} : nil),
                      file: (env['FILE'] || 'db/seeds.rb'),
                      import: (env['IMPORT'] == 'true'))

        append = true
      end
    end

    
  end
end
