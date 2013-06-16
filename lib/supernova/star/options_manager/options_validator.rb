module Supernova
  class Star
    module OptionsManager

      # Handles how options should be set up.
      class OptionsValidator

        attr_reader :required_options

        attr_reader :coercions

        def initialize
          @required_options = []
          instance_exec Proc.new
        end

        # @overload require_options(array)
        #   Adds the contents of array to the required options.
        #   @param array [Array<Symbol>] the options to add.
        # @overload require_options(*options)
        #   Adds the contents of options to the required options.
        #   @param options [Array<Symbol>]
        def require_options(*options)
          @required_options.push(*options.flatten)
        end

        alias_method :require_option, :require_options

        # Checks if the given options hash is valid, according
        # to the rules here.
        #
        # @param options [#keys] the options to validate.
        # @returns [Boolean]
        def valid?(options)
          (@required_options - options.keys).size == 0
        end

      end
    end
  end
end
