module BatchLoaderActiveRecord
  class AssociationManager
    attr_reader :model, :reflection

    def initialize(model:, reflection:)
      @model = model
      @reflection = reflection
    end

    def accessor_name
      :"#{reflection.name}_lazy"
    end

    def loaded_accessor_name
      :"#{reflection.name}_lazy_loaded"
    end

    def belongs_to_batch_loader(instance, options = nil)
      custom_key = batch_key
      relation = relation_with_scope(instance, options && options[:scope])
      custom_key += [relation.to_sql.hash] if options

      foreign_key_value = instance.send(reflection.foreign_key) or return nil
      BatchLoader.for(foreign_key_value).batch(key: custom_key) do |foreign_key_values, loader|
        relation.where(id: foreign_key_values).each { |instance| loader.call(instance.id, instance) }
      end
    end

    def polymorphic_belongs_to_batch_loader(instance, options = nil)
      custom_key = batch_key

      # relation = relation_with_scope(options[:scope])
      # custom_key += [relation.to_sql.hash] if options
      custom_key += [options.hash] if options

      foreign_id = instance.send(reflection.foreign_key) or return nil
      foreign_type = instance.send(reflection.foreign_type)&.constantize or return nil
      BatchLoader.for([foreign_type, foreign_id]).batch(key: custom_key) do |foreign_ids_types, loader|
        foreign_ids_types
          .group_by(&:first)
          .each do |type, type_ids|
            ids = type_ids.map(&:second)
            klass_scope_with_scope = klass_scope(type).where(id: ids)
            klass_scope_with_scope = klass_scope_with_scope.merge(options[:scope]) if options && options[:scope]
            klass_scope_with_scope.each do |instance|
              loader.call([type, instance.id], instance)
            end
          end
      end
    end

    def polymorphic_has_one_to_batch_loader(instance, options = nil)
      custom_key = batch_key

      relation = relation_with_scope(instance, options && options[:scope])
      custom_key += [relation.to_sql.hash] if options
      foreign_id = instance.id or return nil
      foreign_type = instance.class.name or return nil
      BatchLoader.for([foreign_type, foreign_id]).batch(key: custom_key) do |foreign_ids_types, loader|
        foreign_ids_types
          .group_by(&:first)
          .each do |type, type_ids|
            model_ids = type_ids.map(&:second)
            relation.where(reflection.foreign_key => model_ids, "#{reflection.options[:as]}_type" => type).each do |instance|              
              loader.call([type, instance.public_send(reflection.foreign_key)], instance)
            end  
          end
      end
    end

    def has_one_to_batch_loader(instance, options = nil)
      custom_key = batch_key

      relation = relation_with_scope(instance, options && options[:scope])
      custom_key += [relation.to_sql.hash] if options
      BatchLoader.for(instance.id).batch(key: custom_key) do |model_ids, loader|
        relation = relation.where(reflection.foreign_key => model_ids)
        relation.each do |instance|
          loader.call(instance.public_send(reflection.foreign_key), instance)
        end
      end
    end

    def polymorphic_has_many_to_batch_loader(instance, options = nil)
      custom_key = batch_key

      relation = relation_with_scope(instance, options && options[:scope])
      custom_key += [relation.to_sql.hash] if options
      foreign_id = instance.id or return nil
      foreign_type = instance.class.name or return nil
      BatchLoader.for([foreign_type, foreign_id]).batch(default_value: [], key: custom_key) do |foreign_ids_types, loader|
        foreign_ids_types
          .group_by(&:first)
          .each do |type, type_ids|
            model_ids = type_ids.map(&:second)
            relation.where(reflection.foreign_key => model_ids, "#{reflection.options[:as]}_type" => type).each do |instance|
              loader.call([type, instance.public_send(reflection.foreign_key)]) { |value| value << instance }
            end  
          end
      end
    end

    def has_many_to_batch_loader(instance, options = nil)
      custom_key = batch_key

      relation = relation_with_scope(instance, options && options[:scope])
      custom_key += [relation.to_sql.hash] if options
      BatchLoader.for(instance.id).batch(default_value: [], key: custom_key) do |model_ids, loader|
        if reflection.through_reflection
          instances = fetch_for_model_ids(model_ids, relation: relation)
          instances.each do |instance|
            loader.call(instance.public_send(:_instance_id)) { |value| value << instance }
          end
        else
          relation.where(reflection.foreign_key => model_ids).each do |instance|
            loader.call(instance.public_send(reflection.foreign_key)) { |value| value << instance }
          end
        end
      end
    end

    def has_and_belongs_to_many_to_batch_loader(instance, options = nil)
      custom_key = batch_key

      relation = relation_with_scope(instance, options && options[:scope])
      custom_key += [relation.to_sql.hash] if options
      BatchLoader.for(instance.id).batch(default_value: [], key: custom_key) do |model_ids, loader|
        instance_id_path = "#{reflection.join_table}.#{reflection.foreign_key}"
        if relation.select_values.any?
          select_relation = relation.merge(relation.select("#{instance_id_path} AS _instance_id"))
        else
          select_relation = relation.select("#{relation.table_name}.*, #{instance_id_path} AS _instance_id")
        end
        select_relation.
          joins(habtm_join(reflection)).
          where("#{reflection.join_table}.#{reflection.foreign_key}" => model_ids).
          each do |instance|
            loader.call(instance.public_send(:_instance_id)) { |value| value << instance }
          end
      end
    end

    private

    def relation_with_scope(instance, instance_scope)
      @relation_with_scope ||= {}
      @relation_with_scope[instance_scope&.hash || ''] ||= begin
        relation = instance.association(reflection.name).send(:target_scope)
        if reflection.scope
          relation = relation.merge(reflection.scope)
        end
        if instance_scope
          relation = relation.merge(instance_scope)
          # relation = target_scope.merge(instance_scope)
        # else
          # relation = target_scope
        end
        # if reflection.type
        #   if reflection.through_reflection
        #     relation = relation.where(reflection.type => reflection.through_reflection.class_name)
        #   else
        #     relation = relation.where(reflection.type => model.to_s)
        #   end
        # end
        relation
      end
    end

    def target_scope
      @target_scope ||= if reflection.scope
        reflection.klass.scope_for_association.merge(reflection.scope)
      else
        reflection.klass.scope_for_association
      end
    end

    def klass_scope(klass)
      if reflection.scope
        klass.scope_for_association.merge(reflection.scope)
      else
        klass.scope_for_association
      end
    end

    def batch_key
      @batch_key ||= [model.table_name, reflection.name].freeze
    end

    def fetch_for_model_ids(ids, relation:)
      instance_id_path = "#{reflection.active_record.table_name}.#{reflection.active_record.primary_key}"
      model_class = reflection.active_record
      reflections = reflection_chain(reflection)
      join_strings = [reflection_join(reflections.first, relation)]
      reflections.each_cons(2) do |previous, current|
        join_strings << reflection_join(current, previous.active_record)
      end
      if relation.select_values.any?
        select_relation = relation.merge(relation.select("#{instance_id_path} AS _instance_id"))
      else
        select_relation = relation.select("#{relation.table_name}.*, #{instance_id_path} AS _instance_id")
      end

      select_relation = join_strings.reduce(select_relation) do |select_relation, join_string|
        select_relation.joins(join_string)
      end
      select_relation = select_relation.where("#{model_class.table_name}.#{model_class.primary_key} IN (?)", ids)
    end

    def reflection_chain(reflection)
      reflections = [reflection]
      begin
        previous   = reflection
        reflection = previous.source_reflection
        if reflection && reflection != previous
          reflections << reflection
        else
          reflection = nil
        end
      end while reflection
      reflections.reverse
    end

    def reflection_join(orig_reflection, model_class)
      reflection = orig_reflection.through_reflection || orig_reflection
      id_path = id_path_for(reflection, model_class)
      table_name = reflection.active_record.table_name
      id_column = reflection.belongs_to? ? reflection.foreign_key : reflection.active_record.primary_key
      "INNER JOIN #{table_name} ON #{table_name}.#{id_column} = #{id_path}"
    end

    def id_path_for(reflection, model_class)
      id_column = if reflection.belongs_to?
        model_class.primary_key
      else
        reflection.foreign_key
      end
      "#{model_class.table_name}.#{id_column}"
    end

    def habtm_join(reflection)
      <<~SQL
        INNER JOIN #{reflection.join_table}
                ON #{reflection.join_table}.#{reflection.association_foreign_key} =
                   #{reflection.klass.table_name}.#{reflection.active_record.primary_key}
      SQL
    end
  end
end