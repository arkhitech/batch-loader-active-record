# frozen_string_literal: true

require "batch-loader"
require "batch_loader_active_record/version"
require "batch_loader_active_record/association_manager"
require "batch_loader_active_record/association_proxy"

module BatchLoaderActiveRecord
  def self.included(base)
    base.extend(ClassMethods)
  end
  module ClassMethods    
    # ensures that object is loaded immediately or nil is returned
    def define_reader_load_method(manager)
      define_method(manager.loaded_accessor_name) do |options = nil|
        association_object = self.send(manager.accessor_name, options)
        if association_object.respond_to?(:__sync)
          association_object.__sync
        else
          association_object
        end
      end
    end
    private :define_reader_load_method
    
    def define_belongs_to_methods(name, reflection, manager, override = true)
      if reflection.polymorphic?
        define_method(manager.accessor_name) do |options = nil|
          instance_variable_set("@__#{name}", manager.polymorphic_belongs_to_batch_loader(self, options))
        end  
      else
        define_method(manager.accessor_name) do |options = nil|
          instance_variable_set("@__#{name}", manager.belongs_to_batch_loader(self, options))
        end  
      end
      if override
        class_eval <<-CODE, __FILE__, __LINE__ + 1          
          alias_method :#{name}_without_lazy, :#{name}
          def #{name}
            if @__#{name}
              !@__#{name}.nil? && @__#{name} || nil
            else 
              super
            end      
          end
        CODE
      end
      define_reader_load_method(manager)
    end
    private :define_belongs_to_methods

    def define_has_one_methods(name, reflection, manager, override = true)
      if reflection.options[:as]
        define_method(manager.accessor_name) do |options = nil|
          if new_record?
            self.send(manager.reflection.name)
          else
            instance_variable_set("@__#{name}", manager.polymorphic_has_one_to_batch_loader(self, options))
          end
        end
      else
        define_method(manager.accessor_name) do |options = nil|
          if new_record?
            self.send(manager.reflection.name)
          else
            instance_variable_set("@__#{name}", manager.has_one_to_batch_loader(self, options))
          end
        end
      end
      if override
        class_eval <<-CODE, __FILE__, __LINE__ + 1          
          alias_method :#{name}_without_lazy, :#{name}
          def #{name}
            if @__#{name}
              !@__#{name}.nil? && @__#{name} || nil
            else 
              super
            end      
          end
        CODE
      end
      define_reader_load_method(manager)      
    end
    private :define_has_one_methods

    def define_has_many_methods(name, reflection, manager, override = false)
      if reflection.options[:as]
        define_method(manager.accessor_name) do |options = nil|
          if new_record?
            self.send(manager.reflection.name)
          else
            instance_variable_set("@__#{name}", manager.polymorphic_has_many_to_batch_loader(self, options))
          end
        end
      else
        define_method(manager.accessor_name) do |options = nil|
          if new_record?
            self.send(manager.reflection.name)
          else
            instance_variable_set("@__#{name}", manager.has_many_to_batch_loader(self, options))
          end
        end
      end
      # TODO needs fixing, doesn't work properly
      if override
        class_eval <<-CODE, __FILE__, __LINE__ + 1          
          alias_method :#{name}_without_lazy, :#{name}
          def #{name}
            if @__#{name}
              @__#{name}_proxy ||= begin
                records = !@__#{name}.nil? && @__#{name} || []
                association_proxy = AssociationProxy.new(super, records)
              end              
            else 
              super
            end      
          end
        CODE
      end
      define_reader_load_method(manager)      
    end
    private :define_has_many_methods

    def define_has_and_belongs_to_many_methods(name, reflection, manager, override = false)
      define_method(manager.accessor_name) do |options = nil|
        if new_record?
          self.send(manager.reflection.name)
        else
          instance_variable_set("@__#{name}", manager.has_and_belongs_to_many_to_batch_loader(self, options))
        end
      end
      # TODO needs fixing, doesn't work properly
      if override
        class_eval <<-CODE, __FILE__, __LINE__ + 1          
          alias_method :#{name}_without_lazy, :#{name}
          def #{name}
            if @__#{name}
              @__#{name}_proxy ||= begin
                records = !@__#{name}.nil? && @__#{name} || []
                association_proxy = AssociationProxy.new(super, records)
              end              
            else 
              super
            end      
          end
        CODE
      end
      define_reader_load_method(manager)      
    end
    private :define_has_and_belongs_to_many_methods

    def lazy_association_accessor(name, override = true)
      reflection = reflect_on_association(name) or raise "Can't find association #{name.inspect}"
      manager = AssociationManager.new(model: self, reflection: reflection)
      case reflection.macro
      when :belongs_to
        define_belongs_to_methods(name, reflection, manager, override)
      when :has_one
        define_has_one_methods(name, reflection, manager, override)
      when :has_many
        define_has_many_methods(name, reflection, manager, override)
      when :has_and_belongs_to_many
        define_has_and_belongs_to_many_methods(name, reflection, manager, override)
      else
        raise NotImplementedError, "association kind #{reflection.macro.inspect} is not yet supported"
      end
    end

    def belongs_to_lazy(name, scope = nil, **options)
      belongs_to(name, scope, **options).tap do
        reflection = reflect_on_association(name) or raise "Can't find association #{name.inspect}"
        manager = AssociationManager.new(model: self, reflection: reflection)
        define_belongs_to_methods(name, reflection, manager)
      end
    end

    def has_one_lazy(name, scope = nil, **options)
      has_one(name, scope, **options).tap do
        reflection = reflect_on_association(name) or raise "Can't find association #{name.inspect}"
        manager = AssociationManager.new(model: self, reflection: reflection)
        define_has_one_methods(name, reflection, manager)
      end
    end

    def has_many_lazy(name, scope = nil, **options, &extension)
      has_many(name, scope, **options, &extension).tap do
        reflection = reflect_on_association(name) or raise "Can't find association #{name.inspect}"
        manager = AssociationManager.new(model: self, reflection: reflection)
        define_has_many_methods(name, reflection, manager)
      end
    end

    def has_and_belongs_to_many_lazy(name, scope = nil, **options, &extension)
      has_and_belongs_to_many(name, scope, **options, &extension).tap do
        reflection = reflect_on_association(name) or raise "Can't find association #{name.inspect}"
        manager = AssociationManager.new(model: self, reflection: reflection)
        define_has_and_belongs_to_many_methods(name, reflection, manager)
      end
    end
  end
end
