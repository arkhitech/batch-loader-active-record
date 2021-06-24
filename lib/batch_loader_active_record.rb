# frozen_string_literal: true

require "batch-loader"
require "batch_loader_active_record/version"
require "batch_loader_active_record/association_manager"

module BatchLoaderActiveRecord
  def self.included(base)
    base.extend(ClassMethods)
  end
  module ClassMethods    
    # ensures that object is loaded immediately or nil is returned
    def define_reader_load_method(manager)
      define_method(manager.loaded_accessor_name) do |options = nil|
        association_object = self.send(manager.accessor_name, options)
        !association_object.nil? && association_object || nil
      end
    end
    private :define_reader_load_method
    
    def define_belongs_to_methods(name, reflection, manager)
      if reflection.polymorphic?
        define_method(manager.accessor_name) do |options = nil|
          instance_variable_set("@__#{name}", manager.polymorphic_belongs_to_batch_loader(self, options))
        end  
      else
        define_method(manager.accessor_name) do |options = nil|
          instance_variable_set("@__#{name}", manager.belongs_to_batch_loader(self, options))
        end  
      end
      class_eval <<-CODE, __FILE__, __LINE__ + 1          
        def #{name}
          if @__#{name}
            !@__#{name}.nil? && @__#{name} || nil
          else 
            super
          end      
        end
      CODE
      define_reader_load_method(manager)
    end
    private :define_belongs_to_methods

    def define_has_one_methods(name, reflection, manager)
      define_method(manager.accessor_name) do |options = nil|
        instance_variable_set("@__#{name}", manager.has_one_to_batch_loader(self, options))
      end
      class_eval <<-CODE, __FILE__, __LINE__ + 1          
        def #{name}
          if @__#{name}
            !@__#{name}.nil? && @__#{name} || nil
          else 
            super
          end      
        end
      CODE
      define_reader_load_method(manager)      
    end
    private :define_has_one_methods

    def define_has_many_methods(name, reflection, manager)
      define_method(manager.accessor_name) do |options = nil|
        instance_variable_set("@__#{name}", manager.has_many_to_batch_loader(self, options))
      end
      class_eval <<-CODE, __FILE__, __LINE__ + 1          
        def #{name}
          if @__#{name}
            !@__#{name}.nil? && @__#{name} || nil
          else 
            super
          end      
        end
      CODE
      define_reader_load_method(manager)      
    end
    private :define_has_many_methods

    def define_has_and_belongs_to_many_methods(name, reflection, manager)
      define_method(manager.accessor_name) do |options = nil|
        instance_variable_set("@__#{name}", manager.has_and_belongs_to_many_to_batch_loader(self, options))
      end
      class_eval <<-CODE, __FILE__, __LINE__ + 1          
        def #{name}
          if @__#{name}
            !@__#{name}.nil? && @__#{name} || nil
          else 
            super
          end      
        end
      CODE
      define_reader_load_method(manager)      
    end
    private :define_has_and_belongs_to_many_methods

    def lazy_association_accessor(name)
      reflection = reflect_on_association(name) or raise "Can't find association #{name.inspect}"
      manager = AssociationManager.new(model: self, reflection: reflection)
      case reflection.macro
      when :belongs_to
        define_belongs_to_methods(name, reflection, manager)
      when :has_one
        define_has_one_methods(name, reflection, manager)
      when :has_many
        define_has_many_methods(name, reflection, manager)
      when :has_and_belongs_to_many
        define_has_and_belongs_to_many_methods(name, reflection, manager)
      else
        raise NotImplementedError, "association kind #{reflection.macro.inspect} is not yet supported"
      end
    end

    def belongs_to_lazy(*args)
      belongs_to(*args).tap do
        name = args[0]
        reflection = reflect_on_association(name) or raise "Can't find association #{name.inspect}"
        manager = AssociationManager.new(model: self, reflection: reflection)
        define_belongs_to_methods(name, reflection, manager)
      end
    end

    def has_one_lazy(*args)
      has_one(*args).tap do
        name = args[0]
        reflection = reflect_on_association(name) or raise "Can't find association #{name.inspect}"
        manager = AssociationManager.new(model: self, reflection: reflection)
        define_has_one_methods(name, reflection, manager)
      end
    end

    def has_many_lazy(*args)
      has_many(*args).tap do
        name = args[0]
        reflection = reflect_on_association(name) or raise "Can't find association #{name.inspect}"
        manager = AssociationManager.new(model: self, reflection: reflection)
        define_has_many_methods(name, reflection, manager)
      end
    end

    def has_and_belongs_to_many_lazy(*args)
      has_and_belongs_to_many(*args).tap do
        name = args[0]
        reflection = reflect_on_association(name) or raise "Can't find association #{name.inspect}"
        manager = AssociationManager.new(model: self, reflection: reflection)
        define_has_and_belongs_to_many_methods(name, reflection, manager)
      end
    end
  end
end
