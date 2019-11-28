module Torch
  module Optim
    class Optimizer
      def initialize
        @state = {}
      end

      def zero_grad
        @params.each do |param|
          if param.grad
            param.grad.detach!
            param.grad.zero!
          end
        end
      end
    end
  end
end
