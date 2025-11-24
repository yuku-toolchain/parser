❌ ISSUES FOUND:
1. regex-literals.snap.json (test/snapshots/regex-literals.snap.json)
   - Problem: Shows errors instead of properly parsed regex literals
   - Expected: Should contain valid regex_literal AST nodes for all 16 regex patterns
   - Current: Empty body with 2 errors about unexpected tokens
2. template-literal-advanced.snap.json (test/snapshots/template-literal-advanced.snap.json:165-263)
   - Problem: Nested template literal at line 4 (nested ${inner ${y}} template) has duplicate quasis entries
   - Issue: Shows both the inner template elements AND duplicates them in the outer template
   - Expected: Properly nested template_literal structure without duplication
3. precedence-tests.snap.json (test/snapshots/precedence-tests.snap.json)
   - Problem: Incomplete - only covers 16 of 27 test lines
   - Missing: Lines 17-27 including a + !b, ++a * b, a * ++b, a++ * b, a * b++, typeof a + b, a + typeof b, -a ** b, (-a) ** b, ~a & b, a & ~b
   - Current: Cuts off with a postfix operator error
4. array-patterns.snap.json (test/snapshots/array-patterns.snap.json:544-814)
   - Problem: Nested array patterns (lines 10-12) show duplicated elements
   - Example: let [[a]] = arr shows both a standalone a AND a nested array containing a
   - Expected: Single nested array_pattern structure
   - Lines affected: Test lines 10, 11, 12, 16
5. numeric-errors.snap.json (test/snapshots/numeric-errors.snap.json)
   - Problem: Only contains 1 error (0x) but test has 10 error cases
   - Missing errors for: 0b, 0o, 1__2, 1_, 1.5e, 1.5e+, 1.5e-, 1.5n, 0xFFn.toString()
   - Expected: 10 distinct error entries
6. update-expressions.snap.json (test/snapshots/update-expressions.snap.json)
   - Problem: Empty body with only 1 error, but test has 8 valid update expressions
   - Expected: 8 parsed update_expression nodes (prefix/postfix ++/--)
   - Current: Shows line terminator error and no parsed expressions
