module Torch
  class Tensor
    include Comparable
    include Enumerable
    include Inspector

    alias_method :requires_grad?, :requires_grad
    alias_method :ndim, :dim
    alias_method :ndimension, :dim

    def self.new(*args)
      FloatTensor.new(*args)
    end

    def dtype
      dtype = ENUM_TO_DTYPE[_dtype]
      raise Error, "Unknown type: #{_dtype}" unless dtype
      dtype
    end

    def layout
      _layout.downcase.to_sym
    end

    def to_s
      inspect
    end

    def each
      return enum_for(:each) unless block_given?

      size(0).times do |i|
        yield self[i]
      end
    end

    # TODO make more performant
    def to_a
      arr = _flat_data
      if shape.empty?
        arr
      else
        shape[1..-1].reverse.each do |dim|
          arr = arr.each_slice(dim)
        end
        arr.to_a
      end
    end

    def to(device = nil, dtype: nil, non_blocking: false, copy: false)
      device ||= self.device
      device = Device.new(device) if device.is_a?(String)

      dtype ||= self.dtype
      enum = DTYPE_TO_ENUM[dtype]
      raise Error, "Unknown type: #{dtype}" unless enum

      _to(device, enum, non_blocking, copy)
    end

    def cpu
      to("cpu")
    end

    def cuda
      to("cuda")
    end

    def size(dim = nil)
      if dim
        _size_int(dim)
      else
        shape
      end
    end

    def shape
      dim.times.map { |i| size(i) }
    end

    # mirror Python len()
    def length
      size(0)
    end

    def item
      if numel != 1
        raise Error, "only one element tensors can be converted to Ruby scalars"
      end
      to_a.first
    end

    def to_i
      item.to_i
    end

    def to_f
      item.to_f
    end

    # unsure if this is correct
    def new
      Torch.empty(0, dtype: dtype)
    end

    def backward(gradient = nil, retain_graph: nil, create_graph: false)
      retain_graph = create_graph if retain_graph.nil?
      _backward(gradient, retain_graph, create_graph)
    end

    # TODO read directly from memory
    def numo
      cls = Torch._dtype_to_numo[dtype]
      raise Error, "Cannot convert #{dtype} to Numo" unless cls
      cls.from_string(_data_str).reshape(*shape)
    end

    def new_ones(*size, **options)
      Torch.ones_like(Torch.empty(*size), **options)
    end

    def requires_grad!(requires_grad = true)
      _requires_grad!(requires_grad)
    end

    def type(dtype)
      enum = DTYPE_TO_ENUM[dtype]
      raise Error, "Unknown type: #{dtype}" unless enum
      _type(enum)
    end

    def reshape(*size)
      # Python doesn't check if size == 1, just ignores later arguments
      size = size.first if size.size == 1 && size.first.is_a?(Array)
      _reshape(size)
    end

    def view(*size)
      size = size.first if size.size == 1 && size.first.is_a?(Array)
      _view(size)
    end

    def +(other)
      add(other)
    end

    def -(other)
      sub(other)
    end

    def *(other)
      mul(other)
    end

    def /(other)
      div(other)
    end

    def %(other)
      remainder(other)
    end

    def **(other)
      pow(other)
    end

    def -@
      neg
    end

    def &(other)
      logical_and(other)
    end

    def |(other)
      logical_or(other)
    end

    def ^(other)
      logical_xor(other)
    end

    # TODO better compare?
    def <=>(other)
      item <=> other
    end

    # based on python_variable_indexing.cpp and
    # https://pytorch.org/cppdocs/notes/tensor_indexing.html
    def [](*indexes)
      _index(tensor_indexes(indexes))
    end

    # based on python_variable_indexing.cpp and
    # https://pytorch.org/cppdocs/notes/tensor_indexing.html
    def []=(*indexes, value)
      raise ArgumentError, "Tensor does not support deleting items" if value.nil?
      value = Torch.tensor(value, dtype: dtype) unless value.is_a?(Tensor)
      _index_put_custom(tensor_indexes(indexes), value)
    end

    # native functions that need manually defined

    # value and other are swapped for some methods
    def add!(value = 1, other)
      if other.is_a?(Numeric)
        _add__scalar(other, value)
      else
        _add__tensor(other, value)
      end
    end

    # parser can't handle overlap, so need to handle manually
    def random!(*args)
      case args.size
      when 1
        _random__to(*args)
      when 2
        _random__from(*args)
      else
        _random_(*args)
      end
    end

    def clamp!(min, max)
      _clamp_min_(min)
      _clamp_max_(max)
    end

    private

    def tensor_indexes(indexes)
      indexes.map do |index|
        case index
        when Integer
          TensorIndex.integer(index)
        when Range
          finish = index.end
          if finish == -1 && !index.exclude_end?
            finish = nil
          else
            finish += 1 unless index.exclude_end?
          end
          TensorIndex.slice(index.begin, finish)
        when Tensor
          TensorIndex.tensor(index)
        when nil
          TensorIndex.none
        when true, false
          TensorIndex.boolean(index)
        else
          raise Error, "Unsupported index type: #{index.class.name}"
        end
      end
    end
  end
end
