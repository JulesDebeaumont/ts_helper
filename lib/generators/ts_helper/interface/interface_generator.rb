module TsHelper
  module Generators
    class InterfaceGenerator < Rails::Generators::Base

      def main

        # USAGE:
        # rails runner rails-models-to-ts.rb > useInterface.ts
        # https://gist.github.com/zealot128/419949f1c426330493c84bb8eadc4533

        if Rails.env.development?
          Rails.application.eager_load!
          models = ApplicationRecord.descendants.reject { |i| i.abstract_class? }

          belongs_to = true
          has_many = true
          filename = "useInterface.ts"

          conversions = {
            "string" => "string",
            "inet" => "string",
            "text" => "string",
            "json" => "Record<string, any>",
            "jsonb" => "Record<string, any>",
            "binary" => "string",
            "integer" => "number",
            "bigint" => "number",
            "float" => "number",
            "decimal" => "number",
            "boolean" => "boolean",
            "date" => "string",
            "datetime" => "string",
            "timestamp" => "string",
            "datetime_with_timezone" => "string",
          }
          type_template = ""
          array_of_model_names = []
          models.each { |model|
            name = model.model_name.singular.camelcase
            array_of_model_names<< name

            columns = model.columns.map { |i|
              type = conversions[i.type.to_s]
              if (enum = model.defined_enums[i.name])
                type = enum.keys.map { |k| "'#{k}'" }.join(" | ")
              end

              {
                name: i.name,
                ts_type: i.null ? "#{type} | null" : type
              }
            }

            model.reflect_on_all_associations.select(&:collection?).each { |collection|
              target = collection.compute_class(collection.class_name).model_name.singular.camelcase

              columns << {
                name: "#{collection.name}?",
                ts_type: "#{target}[]"
              }
            } if has_many
            model.reflect_on_all_associations.select(&:has_one?).each { |collection|
              target = collection.compute_class(collection.class_name).model_name.singular.camelcase

              columns << {
                name: "#{collection.name}?",
                ts_type: target
              }
            } if has_many

            model.reflect_on_all_associations.select(&:belongs_to?).reject(&:polymorphic?).each { |collection|
              target = collection.compute_class(collection.class_name).model_name.singular.camelcase

              columns << {
                name: "#{collection.name}?",
                ts_type: target } } if belongs_to

            type_template += <<~TYPESCRIPT
              interface #{name} {
                #{columns.map { |column| "  #{column[:name]}: #{column[:ts_type]}; " }.join("\n")}
              }

            TYPESCRIPT
          }

          template = <<~TPL
            #{type_template.indent(2)}

            export {
              #{array_of_model_names.join(",\n")}
            }
          TPL

          File.write(filename, template)
        end

        puts "\e[32m" + "Done! \nFile path:" + "\e[0m" + " " + "\e[32m" +  "\e[3m" + "#{Dir.pwd}/#{filename}" + "\e[23m" + " \e[0m"
        return nil
      end

    end
  end
end