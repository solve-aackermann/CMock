class CMockGeneratorPluginIgnoreArg
  attr_reader :priority
  attr_accessor :utils

  def initialize(config, utils)
    @utils        = utils
    @priority     = 10
  end
  
  def mock_function_declarations(function)
    lines = ""
    func_name = function[:name]
    function[:args].each do |arg|
      arg_name = arg[:name]
      arg_type = arg[:type]
      lines << "// ignoreArgCount: number of counts to ignore; -1 ignore every check\n"
      lines << "#define #{func_name}_IgnoreArg_#{arg_name}(ignoreArgCount)"
      lines << " #{func_name}_CMockIgnoreArg_#{arg_name}(__FILE__, __LINE__, ignoreArgCount)\n"
      lines << "void #{func_name}_CMockIgnoreArg_#{arg_name}(const char* const file, const int line, int ignoreArgCount);\n\n"
    end
    lines
  end

  def mock_interfaces(function)
    lines = []
    func_name = function[:name]
    function[:args].each do |arg|
      arg_name = arg[:name]
      arg_type = arg[:type]
      lines << "void #{func_name}_CMockIgnoreArg_#{arg_name}(const char* const file, const int line, int ignoreArgCount)\n"
      lines << "{\n"
      lines << "  _expect_any(CMockString_#{func_name}, CMockString_#{arg_name}, file, line, ignoreArgCount);\n"
      lines << "}\n\n"
    end
    lines
  end
end
