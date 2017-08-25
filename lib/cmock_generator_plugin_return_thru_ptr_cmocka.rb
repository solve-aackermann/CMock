class CMockGeneratorPluginReturnThruPtr
  attr_reader :priority
  attr_accessor :utils

  def initialize(config, utils)
    @utils        = utils
    @priority     = 9
  end
  
  def instance_typedefs(function)
    lines = ""
    function[:args].each do |arg|
      lines << "  int ReturnThruPtr_#{arg[:name]};\n"
    end
    lines
  end

  def mock_function_declarations(function)
    lines = ""
    function[:args].each do |arg|
      if (@utils.ptr_or_str?(arg[:type]) and not arg[:const?])
        lines << "void #{function[:name]}_ReturnThruPtr_#{arg[:name]}(int returnThruPtr_#{arg[:name]});\n"
      end
    end
    lines
  end

  def mock_interfaces(function)
    lines = []
    func_name = function[:name]
    function[:args].each do |arg|
      if (@utils.ptr_or_str?(arg[:type]) and not arg[:const?])
        lines << "void #{func_name}_ReturnThruPtr_#{arg[:name]}(int returnThruPtr_#{arg[:name]})\n"
        lines << "{\n"
          lines << "  Mock.#{function[:name]}_CallInstance->ReturnThruPtr_#{arg[:name]} = returnThruPtr_#{arg[:name]};\n"
        lines << "}\n\n"
      end
    end
    lines
  end

  def mock_implementation(function)
    lines = []
    function[:args].each do |arg|
      if (@utils.ptr_or_str?(arg[:type]) and not arg[:const?])
        lines << "  if( Mock.#{function[:name]}_CallInstance->ReturnThruPtr_#{arg[:name]} )\n"
        lines << "  {\n"
        lines << "    size_t s = mock();\n"
        lines << "    #{arg[:type]} mem = mock_type(#{arg[:type]});\n"
        lines << "    memcpy(#{arg[:name]}, mem, s);\n"
        lines << "  }\n"
      end
    end
    lines
  end
end
