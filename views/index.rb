class Peglist
  module Views
    class Index < Mustache
      include ViewHelpers
      
      def name
        @env["bob"]
      end
    end
  end
end