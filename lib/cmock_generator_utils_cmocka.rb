# ==========================================
#   CMock Project - Automatic Mock Generation for C
#   Copyright (c) 2007 Mike Karlesky, Mark VanderVoord, Greg Williams
#   [Released under MIT License. Please refer to license.txt for details]
# ==========================================

class CMockGeneratorUtils_cmocka

  attr_accessor :config, :helpers, :ordered, :ptr_handling, :arrays, :cexception

  def initialize(config, helpers={})
    @config = config
    @ptr_handling = @config.when_ptr
    @ordered      = @config.enforce_strict_ordering
    @arrays       = @config.plugins.include? :array
    @cexception   = @config.plugins.include? :cexception
    @expect_any   = @config.plugins.include? :expect_any_args
    @return_thru_ptr = @config.plugins.include? :return_thru_ptr
    @ignore_arg   = @config.plugins.include? :ignore_arg
    @ignore       = @config.plugins.include? :ignore
    @treat_as     = @config.treat_as
    @helpers      = helpers
  end

  def code_verify_an_arg_expectation(function, arg)
    if (@arrays)
      case(@ptr_handling)
        when :smart        then code_verify_an_arg_expectation_with_smart_arrays(function, arg)
        when :compare_data then code_verify_an_arg_expectation_with_normal_arrays(function, arg)
        when :compare_ptr  then raise "ERROR: the array plugin doesn't enjoy working with :compare_ptr only.  Disable one option."
      end
    else
      code_verify_an_arg_expectation_with_no_arrays(function, arg)
    end
  end

  def code_add_base_expectation(func_name, global_ordering_supported=true)
    lines =  "//  CMOCK_MEM_INDEX_TYPE cmock_guts_index = CMock_Guts_MemNew(sizeof(CMOCK_#{func_name}_CALL_INSTANCE));\n"
    lines << "  CMOCK_#{func_name}_CALL_INSTANCE* cmock_call_instance = (CMOCK_#{func_name}_CALL_INSTANCE*)CMock_Guts_GetAddressFor(cmock_guts_index);\n"
    lines << "  assert_non_null(cmock_call_instance);\n"
    lines << "  memset(cmock_call_instance, 0, sizeof(*cmock_call_instance));\n"
    lines << "  Mock.#{func_name}_CallInstance = CMock_Guts_MemChain(Mock.#{func_name}_CallInstance, cmock_guts_index);\n"
    lines << "  Mock.#{func_name}_IgnoreBool = (int)0;\n" if (@ignore)
    lines << "  cmock_call_instance->CallOrder = ++GlobalExpectCount;\n" if (@ordered and global_ordering_supported)
    lines << "  cmock_call_instance->ExceptionToThrow = CEXCEPTION_NONE;\n" if (@cexception)
    lines << "  cmock_call_instance->IgnoreMode = CMOCK_ARG_ALL;\n" if (@expect_any)
    lines
  end

  def code_assign_argument_quickly(dest, arg)
    if (arg[:ptr?] or @treat_as.include?(arg[:type]))
      "  #{dest} = #{arg[:const?] ? "(#{arg[:type]})" : ''}#{arg[:name]};\n"
    else
      "  memcpy(&#{dest}, &#{arg[:name]}, sizeof(#{arg[:type]}));\n"
    end
  end

  def ptr_or_str?(arg_type)
    return (arg_type.include? '*' or
            @treat_as.fetch(arg_type, "").include? '*')
  end

  #private ######################

  def lookup_expect_type(function, arg)
    c_type     = arg[:type]
    arg_name   = arg[:name]
    expected   = "cmock_call_instance->Expected_#{arg_name}"
    cmocka_func = if ((arg[:ptr?]) and ((c_type =~ /\*\*/) or (@ptr_handling == :compare_ptr)))
                   ['UNITTEST_ASSERT_EQUAL_PTR', '']
                 else
                   (@helpers.nil? or @helpers[:cmocka_helper].nil?) ? ["UNITTEST_ASSERT_EQUAL",''] : @helpers[:cmocka_helper].get_helper(c_type)
                 end
    unity_msg  = "Function '#{function[:name]}' called with unexpected value for argument '#{arg_name}'."
    return c_type, arg_name, expected, cmocka_func[0], cmocka_func[1], unity_msg
  end

  def code_verify_an_arg_expectation_with_no_arrays(function, arg)
    c_type, arg_name, expected, cmocka_func, pre, unity_msg = lookup_expect_type(function, arg)
    
    lines = ""
    lines << "  {\n"
    lines << "    // code_verify_an_arg_expectation_with_no_arrays cmocka_func #{cmocka_func}\n"
    case(cmocka_func)
      when "UNITTEST_ASSERT_EQUAL_MEMORY"
        lines << "    check_expected(#{pre}#{arg_name});\n"
      when "UNITTEST_ASSERT_EQUAL_INT"
        lines << "    check_expected(#{pre}#{arg_name});\n"
      when "UNITTEST_ASSERT_EQUAL_STRING"
        lines << "    check_expected(#{pre}#{arg_name});\n"
      when "UNITTEST_ASSERT_EQUAL_PTR"
        lines << "    check_expected(#{pre}#{arg_name});\n"
      when "UNITTEST_ASSERT_EQUAL_MEMORY_ARRAY"
        lines << "    check_expected(#{pre}#{arg_name});\n"
        if (pre == '&')
          lines << "    assert_memory_equalb((void*)(#{pre}#{expected}), (void*)(#{pre}#{arg_name}), sizeof(#{c_type.sub('*','')}));\n"
        else
          lines << "    if (#{pre}#{expected} == NULL)\n"
          lines << "      { assert_null(#{pre}#{arg_name}); }\n"
          lines << "    else\n"
          lines << "      { assert_memory_equalc((void*)(#{pre}#{expected}), (void*)(#{pre}#{arg_name}), sizeof(#{c_type.sub('*','')})); }\n"
        end
      when /_ARRAY/
        lines << "    check_expected(#{pre}#{arg_name});\n"
      else
        lines << "    check_expected(#{pre}#{arg_name});\n"
        #lines << "    #{cmocka_func}(#{pre}#{expected}, #{pre}#{arg_name}, cmock_line, CMockStringMismatch);\n"
    end
    lines << "  }\n"
    lines
  end

  def code_verify_an_arg_expectation_with_normal_arrays(function, arg)
    c_type, arg_name, expected, mocka_func, pre, unity_msg = lookup_expect_type(function, arg)
    depth_name = (arg[:ptr?]) ? "cmock_call_instance->Expected_#{arg_name}_Depth" : 1
    lines = ""
    lines << "  {\n"
    case(cmocka_func)
      when "UNITTEST_ASSERT_EQUAL_MEMORY"
        c_type_local = c_type.gsub(/\*$/,'')
        lines << "    assert_memory_equale((void*)(#{pre}#{expected}), (void*)(#{pre}#{arg_name}), sizeof(#{c_type_local}));\n"
      when "UNITTEST_ASSERT_EQUAL_MEMORY_ARRAY"
        if (pre == '&')
          lines << "    assert_memory_equalf((void*)(#{pre}#{expected}), (void*)(#{pre}#{arg_name}), sizeof(#{c_type.sub('*','')}));\n"
        else
          lines << "    if (#{pre}#{expected} == NULL)\n"
          lines << "      { assert_null(#{pre}#{arg_name}); }\n"
          lines << "    else\n"
          lines << "      { UNITTEST_ASSERT_EQUAL_MEMORY_ARRAY((void*)(#{pre}#{expected}), (void*)(#{pre}#{arg_name}), sizeof(#{c_type.sub('*','')}), #{depth_name}, cmock_line, CMockStringMismatch); }\n"
        end
      when /_ARRAY/
        if (pre == '&')
          lines << "    #{cmocka_func}(#{pre}#{expected}, #{pre}#{arg_name}, #{depth_name}, cmock_line, CMockStringMismatch);\n"
        else
          lines << "    if (#{pre}#{expected} == NULL)\n"
          lines << "      { assert_null(#{pre}#{arg_name}); }\n"
          lines << "    else\n"
          lines << "      { #{cmocka_func}(#{pre}#{expected}, #{pre}#{arg_name}, #{depth_name}, cmock_line, CMockStringMismatch); }\n"
        end
      else
        lines << "    #{cmocka_func}(#{pre}#{expected}, #{pre}#{arg_name}, cmock_line, CMockStringMismatch);\n"
    end
    lines << "  }\n"
    lines
  end

  def code_verify_an_arg_expectation_with_smart_arrays(function, arg)
    c_type, arg_name, expected, cmocka_func, pre, unity_msg = lookup_expect_type(function, arg)
    depth_name = (arg[:ptr?]) ? "cmock_call_instance->Expected_#{arg_name}_Depth" : 1
    lines = ""
    lines << "  {\n"
    case(cmocka_func)
      when "UNITTEST_ASSERT_EQUAL_MEMORY"
        c_type_local = c_type.gsub(/\*$/,'')
        lines << "    assert_memory_equal((void*)(#{pre}#{expected}), (void*)(#{pre}#{arg_name}), sizeof(#{c_type_local}));\n"
      when "UNITTEST_ASSERT_EQUAL_MEMORY_ARRAY"
        if (pre == '&')
          lines << "    UNITTEST_ASSERT_EQUAL_MEMORY_ARRAY((void*)(#{pre}#{expected}), (void*)(#{pre}#{arg_name}), sizeof(#{c_type.sub('*','')}), #{depth_name}, cmock_line, CMockStringMismatch);\n"
        else
          lines << "    if (#{pre}#{expected} == NULL)\n"
          lines << "      { assert_null(#{arg_name}); }\n"
          lines << ((depth_name != 1) ? "    else if (#{depth_name} == 0)\n      { UNITTEST_ASSERT_EQUAL_PTR(#{pre}#{expected}, #{pre}#{arg_name}, cmock_line, CMockStringMismatch); }\n" : "")
          lines << "    else\n"
          lines << "      { UNITTEST_ASSERT_EQUAL_MEMORY_ARRAY((void*)(#{pre}#{expected}), (void*)(#{pre}#{arg_name}), sizeof(#{c_type.sub('*','')}), #{depth_name}, cmock_line, CMockStringMismatch); }\n"
        end
      when /_ARRAY/
        if (pre == '&')
          lines << "    #{cmocka_func}(#{pre}#{expected}, #{pre}#{arg_name}, #{depth_name}, cmock_line, CMockStringMismatch);\n"
        else
          lines << "    if (#{pre}#{expected} == NULL)\n"
          lines << "      { assert_null(#{pre}#{arg_name}); }\n"
          lines << ((depth_name != 1) ? "    else if (#{depth_name} == 0)\n      { UNITTEST_ASSERT_EQUAL_PTR(#{pre}#{expected}, #{pre}#{arg_name}, cmock_line, CMockStringMismatch); }\n" : "")
          lines << "    else\n"
          lines << "      { #{cmocka_func}(#{pre}#{expected}, #{pre}#{arg_name}, #{depth_name}, cmock_line, CMockStringMismatch); }\n"
        end
      else
        lines << "    #{cmocka_func}(#{pre}#{expected}, #{pre}#{arg_name}, cmock_line, CMockStringMismatch);\n"
    end
    lines << "  }\n"
    lines
  end

end