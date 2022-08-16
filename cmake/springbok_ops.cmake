# Add Compilation and Linker options based on iree/build_tools/cmake/iree_cops.cmake

# Key compilation options
iree_select_compiler_opts(IREE_DEFAULT_COPTS
  CLANG_OR_GCC
  "-fvisibility=hidden"

  # NOTE: The RTTI setting must match what LLVM was compiled with (defaults
  # to RTTI disabled).
  "$<$<COMPILE_LANGUAGE:CXX>:-fno-rtti>"
  "$<$<COMPILE_LANGUAGE:CXX>:-fno-exceptions>"
)

# Compiler diagnostics.
# Please keep these in sync with build_tools/bazel/iree.bazelrc
iree_select_compiler_opts(IREE_DEFAULT_COPTS

  # Clang diagnostics. These largely match the set of warnings used within
  # Google. They have not been audited super carefully by the IREE team but are
  # generally thought to be a good set and consistency with those used
  # internally is very useful when importing. If you feel that some of these
  # should be different (especially more strict), please raise an issue!
  CLANG
  "-Werror"
  "-Wall"

  # Disable warnings we don't care about or that generally have a low
  # signal/noise ratio.
  "-Wno-ambiguous-member-template"
  "-Wno-char-subscripts"
  "-Wno-deprecated-declarations"
  "-Wno-extern-c-compat" # Matches upstream. Cannot impact due to extern C inclusion method.
  "-Wno-gnu-alignof-expression"
  "-Wno-gnu-variable-sized-type-not-at-end"
  "-Wno-ignored-optimization-argument"
  "-Wno-invalid-offsetof" # Technically UB but needed for intrusive ptrs
  "-Wno-invalid-source-encoding"
  "-Wno-mismatched-tags"
  "-Wno-pointer-sign"
  "-Wno-reserved-user-defined-literal"
  "-Wno-return-type-c-linkage"
  "-Wno-self-assign-overloaded"
  "-Wno-sign-compare"
  "-Wno-signed-unsigned-wchar"
  "-Wno-strict-overflow"
  "-Wno-trigraphs"
  "-Wno-unknown-pragmas"
  "-Wno-unknown-warning-option"
  "-Wno-unused-command-line-argument"
  "-Wno-unused-const-variable"
  "-Wno-unused-function"
  "-Wno-unused-local-typedef"
  "-Wno-unused-private-field"
  "-Wno-user-defined-warnings"

  # Explicitly enable some additional warnings.
  # Some of these aren't on by default, or under -Wall, or are subsets of
  # warnings turned off above.
  "-Wctad-maybe-unsupported"
  "-Wfloat-overflow-conversion"
  "-Wfloat-zero-conversion"
  "-Wfor-loop-analysis"
  "-Wformat-security"
  "-Wgnu-redeclared-enum"
  "-Wimplicit-fallthrough"
  "-Winfinite-recursion"
  "-Wliteral-conversion"
  "-Wnon-virtual-dtor"
  "-Woverloaded-virtual"
  "-Wself-assign"
  "-Wstring-conversion"
  "-Wtautological-overlap-compare"
  "-Wthread-safety"
  "-Wthread-safety-beta"
  "-Wunused-comparison"
  "-Wvla"
)


iree_select_compiler_opts(IREE_DEFAULT_LINKOPTS
  CLANG_OR_GCC
  # Required by all modern software, effectively:
  "-lm"
)
