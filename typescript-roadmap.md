# TypeScript Implementation Roadmap for Yuku

## 📋 Phase 1: Foundation & Basic Types (Week 1-2)

### Day 1-2: Token Layer Setup
**Estimated: 2-3 hours total**

- [ ] Add TypeScript-specific tokens to `token.zig`
  - Keywords: `type`, `readonly`, `keyof`, `infer`, `is`, `abstract`, `override`, `satisfies`
  - Operators: `<` (type parameters), `>`, `=>` (type arrow), `:` (type annotation)
- [ ] Update lexer to recognize TypeScript keywords in `.ts` and `.tsx` files
- [ ] Test: Basic token recognition

**Files to modify:** `src/js/token.zig`

**Why start here:** Tokens are the foundation. Getting these right makes everything else easier.

---

### Day 3-4: Type Annotation Infrastructure
**Estimated: 3-4 hours total**

- [ ] Add `TSTypeAnnotation` node to `ast.zig`
- [ ] Implement `: type` parsing in variable declarations
  ```typescript
  const x: number = 5;
  let y: string;
  ```
- [ ] Add type annotation to binding identifiers
- [ ] Test: Simple variable type annotations

**Files to modify:** `src/js/ast.zig`, `src/js/syntax/variables.zig`

**Quick Win:** You'll see typed variables working immediately!

---

### Day 5-7: Basic Type Keywords (Easy!)
**Estimated: 3-4 hours total**

- [ ] Implement primitive type keywords:
  - `TSAnyKeyword`, `TSStringKeyword`, `TSNumberKeyword`, `TSBooleanKeyword`
  - `TSNullKeyword`, `TSUndefinedKeyword`, `TSVoidKeyword`
  - `TSUnknownKeyword`, `TSNeverKeyword`, `TSSymbolKeyword`
  - `TSBigIntKeyword`, `TSObjectKeyword`
- [ ] Add parser function `parseTypeKeyword`
- [ ] Test: `const x: string`, `let y: number`, etc.

**Files to create:** `src/js/syntax/types.zig`

**Why it's easy:** These are just keywords—straightforward parsing, instant satisfaction!

---

### Day 8-10: Type References & Simple Types
**Estimated: 4-5 hours total**

- [ ] Implement `TSTypeReference` (e.g., `MyType`, `Array<T>`)
- [ ] Add `TSTypeName` and `IdentifierReference` support
- [ ] Implement `TSLiteralType` (string, number, boolean literals in types)
- [ ] Implement `TSThisType` (`this` as a type)
- [ ] Test: Custom type references and literal types

**Files to modify:** `src/js/syntax/types.zig`, `src/js/ast.zig`

**Milestone:** You can now parse most basic TypeScript declarations!

---

### Day 11-12: Union & Intersection Types
**Estimated: 2-3 hours total**

- [ ] Implement `TSUnionType` (`A | B | C`)
- [ ] Implement `TSIntersectionType` (`A & B & C`)
- [ ] Handle operator precedence (intersection binds tighter than union)
- [ ] Test: Complex union/intersection combinations

**Files to modify:** `src/js/syntax/types.zig`

---

### Day 13-14: Array & Tuple Types
**Estimated: 3-4 hours total**

- [ ] Implement `TSArrayType` (`T[]`)
- [ ] Implement `TSTupleType` (`[string, number]`)
- [ ] Add `TSOptionalType` for optional tuple elements (`[string, number?]`)
- [ ] Add `TSRestType` for rest tuple elements (`[string, ...number[]]`)
- [ ] Test: Arrays and tuples

**Files to modify:** `src/js/syntax/types.zig`

---

## 📚 Phase 2: Function Types & Declarations (Week 3-4)

### Day 15-17: Function Type Annotations
**Estimated: 4-5 hours total**

- [ ] Add return type annotations to functions
  ```typescript
  function foo(): number { return 42; }
  ```
- [ ] Add parameter type annotations
  ```typescript
  function bar(x: string, y: number): void { }
  ```
- [ ] Support optional parameters (`param?: type`)
- [ ] Test: Typed functions

**Files to modify:** `src/js/syntax/functions.zig`, `src/js/ast.zig`

---

### Day 18-20: Function Type Expressions
**Estimated: 4-5 hours total**

- [ ] Implement `TSFunctionType` (`(x: string) => number`)
- [ ] Implement `TSConstructorType` (`new (x: string) => MyClass`)
- [ ] Support `abstract` modifier for constructor types
- [ ] Parse type parameters in function types
- [ ] Test: Function type expressions

**Files to modify:** `src/js/syntax/types.zig`

---

### Day 21-23: Type Parameters (Generics - Part 1)
**Estimated: 5-6 hours total**

- [ ] Implement `TSTypeParameter` node
- [ ] Implement `TSTypeParameterDeclaration` (`<T, U>`)
- [ ] Add to functions: `function foo<T>(x: T): T`
- [ ] Add constraints: `<T extends string>`
- [ ] Add defaults: `<T = number>`
- [ ] Test: Basic generic functions

**Files to modify:** `src/js/syntax/types.zig`, `src/js/syntax/functions.zig`

**Important:** Generics are everywhere in TypeScript—this is a crucial foundation!

---

### Day 24-25: Type Parameter Instantiation
**Estimated: 3-4 hours total**

- [ ] Implement `TSTypeParameterInstantiation` (`<string, number>`)
- [ ] Add to function calls: `foo<string>(x)`
- [ ] Add to type references: `Array<number>`
- [ ] Disambiguate from JSX in `.tsx` files (tricky!)
- [ ] Test: Generic function calls

**Files to modify:** `src/js/syntax/types.zig`, `src/js/syntax/expressions.zig`

---

### Day 26-28: Arrow Function Type Annotations
**Estimated: 3-4 hours total**

- [ ] Add type parameters to arrow functions
- [ ] Add parameter type annotations
- [ ] Add return type annotations
- [ ] Test: `const f = <T>(x: T): T => x`

**Files to modify:** `src/js/syntax/expressions.zig`, `src/js/syntax/parenthesized.zig`

---

## 🏗️ Phase 3: Interfaces & Classes (Week 5-6)

### Day 29-31: Interface Declarations
**Estimated: 5-6 hours total**

- [ ] Implement `TSInterfaceDeclaration`
- [ ] Implement `TSInterfaceBody`
- [ ] Parse property signatures (`TSPropertySignature`)
- [ ] Parse method signatures (`TSMethodSignature`)
- [ ] Support `readonly`, `optional` modifiers
- [ ] Test: Basic interfaces

**Files to create/modify:** `src/js/syntax/interfaces.zig`

---

### Day 32-34: Interface Signatures
**Estimated: 4-5 hours total**

- [ ] Implement `TSCallSignatureDeclaration`
- [ ] Implement `TSConstructSignatureDeclaration`
- [ ] Implement `TSIndexSignature` (`[key: string]: value`)
- [ ] Test: Complex interface signatures

**Files to modify:** `src/js/syntax/interfaces.zig`

---

### Day 35-37: Interface Extends & Implements
**Estimated: 4-5 hours total**

- [ ] Implement `TSInterfaceHeritage` (extends clause)
- [ ] Support multiple extends: `interface A extends B, C`
- [ ] Implement `TSClassImplements` for classes
- [ ] Add `implements` clause to class declarations
- [ ] Test: Interface inheritance

**Files to modify:** `src/js/syntax/interfaces.zig`, `src/js/syntax/class.zig`

---

### Day 38-40: Class Type Annotations
**Estimated: 5-6 hours total**

- [ ] Add type annotations to class properties
- [ ] Add type annotations to class methods
- [ ] Support `declare` modifier for ambient declarations
- [ ] Support `abstract` modifier for classes and members
- [ ] Add `TSParameterProperty` (constructor shorthand)
- [ ] Test: Fully typed classes

**Files to modify:** `src/js/syntax/class.zig`, `src/js/ast.zig`

---

### Day 41-42: Access Modifiers
**Estimated: 2-3 hours total**

- [ ] Add `TSAccessibility` enum (`public`, `private`, `protected`)
- [ ] Parse access modifiers on class members
- [ ] Support `readonly` modifier
- [ ] Support `override` modifier
- [ ] Test: Access control in classes

**Files to modify:** `src/js/syntax/class.zig`

---

## 🎨 Phase 4: Advanced Types (Week 7-8)

### Day 43-45: Object Type Literals
**Estimated: 4-5 hours total**

- [ ] Implement `TSTypeLiteral` (`{ x: number; y: string }`)
- [ ] Reuse interface signature parsing
- [ ] Support nested object types
- [ ] Test: Object type literals

**Files to modify:** `src/js/syntax/types.zig`

---

### Day 46-48: Mapped Types
**Estimated: 5-6 hours total**

- [ ] Implement `TSMappedType`
- [ ] Parse `[K in keyof T]: T[K]`
- [ ] Support modifiers: `readonly`, `?`, `+`, `-`
- [ ] Add `nameType` support (`as` clause)
- [ ] Test: Mapped types

**Files to modify:** `src/js/syntax/types.zig`

**Note:** This is challenging but incredibly powerful!

---

### Day 49-50: Conditional Types
**Estimated: 3-4 hours total**

- [ ] Implement `TSConditionalType` (`T extends U ? X : Y`)
- [ ] Handle nested conditionals
- [ ] Test: Conditional type logic

**Files to modify:** `src/js/syntax/types.zig`

---

### Day 51-52: Indexed Access & Type Operators
**Estimated: 3-4 hours total**

- [ ] Implement `TSIndexedAccessType` (`T[K]`)
- [ ] Implement `TSTypeOperator` (`keyof T`, `readonly T`, `unique T`)
- [ ] Test: Type operators

**Files to modify:** `src/js/syntax/types.zig`

---

### Day 53-54: Infer & Type Queries
**Estimated: 3-4 hours total**

- [ ] Implement `TSInferType` (`infer U`)
- [ ] Implement `TSTypeQuery` (`typeof x`)
- [ ] Support `TSQualifiedName` (`A.B.C`)
- [ ] Test: Type queries and inference

**Files to modify:** `src/js/syntax/types.zig`

---

### Day 55-56: Template Literal Types
**Estimated: 3-4 hours total**

- [ ] Implement `TSTemplateLiteralType`
- [ ] Reuse template literal parsing logic
- [ ] Support type interpolation
- [ ] Test: Template literal types

**Files to modify:** `src/js/syntax/types.zig`

---

## 🚀 Phase 5: Declarations & Modules (Week 9-10)

### Day 57-59: Type Aliases
**Estimated: 4-5 hours total**

- [ ] Implement `TSTypeAliasDeclaration`
- [ ] Support type parameters on aliases
- [ ] Support `declare` modifier
- [ ] Test: Type aliases

**Files to create/modify:** `src/js/syntax/declarations.zig`

---

### Day 60-62: Enum Declarations
**Estimated: 4-5 hours total**

- [ ] Implement `TSEnumDeclaration`
- [ ] Implement `TSEnumBody` and `TSEnumMember`
- [ ] Support string and numeric enums
- [ ] Support computed enum values
- [ ] Support `const` enums
- [ ] Test: Enums

**Files to create/modify:** `src/js/syntax/declarations.zig`

---

### Day 63-65: Module & Namespace Declarations
**Estimated: 4-5 hours total**

- [ ] Implement `TSModuleDeclaration` (`module`, `namespace`)
- [ ] Implement `TSModuleBlock`
- [ ] Support nested namespaces
- [ ] Implement `TSGlobalDeclaration` (`global`)
- [ ] Test: Namespaces and modules

**Files to modify:** `src/js/syntax/statements.zig`

---

### Day 66-67: Import/Export Type Extensions
**Estimated: 3-4 hours total**

- [ ] Add `ImportOrExportKind` enum (`value` | `type`)
- [ ] Support `import type` syntax
- [ ] Support `export type` syntax
- [ ] Implement `TSImportEqualsDeclaration`
- [ ] Implement `TSExternalModuleReference`
- [ ] Test: Type imports/exports

**Files to modify:** `src/js/syntax/modules.zig`

---

### Day 68-69: Export Assignment & Namespace Export
**Estimated: 2-3 hours total**

- [ ] Implement `TSExportAssignment` (`export = expr`)
- [ ] Implement `TSNamespaceExportDeclaration` (`export as namespace`)
- [ ] Test: TypeScript module exports

**Files to modify:** `src/js/syntax/modules.zig`

---

## ⚡ Phase 6: Type Assertions & Special Features (Week 11-12)

### Day 70-72: Type Assertions
**Estimated: 4-5 hours total**

- [ ] Implement `TSAsExpression` (`x as T`)
- [ ] Implement `TSTypeAssertion` (`<T>x`)
- [ ] Implement `TSNonNullExpression` (`x!`)
- [ ] Implement `TSSatisfiesExpression` (`x satisfies T`)
- [ ] Test: Type assertions

**Files to modify:** `src/js/syntax/expressions.zig`

---

### Day 73-74: Type Predicates
**Estimated: 3-4 hours total**

- [ ] Implement `TSTypePredicate` (`x is T`)
- [ ] Support `asserts` predicates
- [ ] Test: Type guard functions

**Files to modify:** `src/js/syntax/types.zig`

---

### Day 75-76: Import Types
**Estimated: 3-4 hours total**

- [ ] Implement `TSImportType` (`import("module").Type`)
- [ ] Implement `TSImportTypeQualifier`
- [ ] Support type arguments in import types
- [ ] Test: Import types

**Files to modify:** `src/js/syntax/types.zig`

---

### Day 77-78: Named Tuple Members
**Estimated: 2-3 hours total**

- [ ] Implement `TSNamedTupleMember` (`[key: string, value: number]`)
- [ ] Support optional named members
- [ ] Test: Named tuples

**Files to modify:** `src/js/syntax/types.zig`

---

### Day 79-80: Parenthesized & This Types
**Estimated: 2-3 hours total**

- [ ] Implement `TSParenthesizedType` (`(T)`)
- [ ] Implement `TSThisParameter` for functions
- [ ] Test: Parenthesized types

**Files to modify:** `src/js/syntax/types.zig`

---

## 🔧 Phase 7: Polish & Integration (Week 13)

### Day 81-82: Decorator Support (Optional)
**Estimated: 3-4 hours total**

- [ ] Implement `Decorator` node
- [ ] Support decorators on classes
- [ ] Support decorators on class members
- [ ] Test: Decorators

**Files to modify:** `src/js/ast.zig`, `src/js/syntax/class.zig`

**Note:** Decorators are Stage 3 but commonly used with TypeScript.

---

### Day 83-84: TSX Integration
**Estimated: 3-4 hours total**

- [ ] Ensure type parameters work in `.tsx` files
- [ ] Disambiguate `<T>` from JSX elements
- [ ] Add `typeArguments` to JSX elements and call expressions
- [ ] Test: TypeScript + JSX together

**Files to modify:** `src/js/syntax/jsx.zig`, `src/js/syntax/expressions.zig`

---

### Day 85-86: Declare Statements
**Estimated: 3-4 hours total**

- [ ] Support `declare` modifier on variables
- [ ] Support `declare` modifier on functions (`TSDeclareFunction`)
- [ ] Support `declare` modifier on classes
- [ ] Support ambient declarations
- [ ] Test: `.d.ts` file parsing

**Files to modify:** Various syntax files

---

### Day 87-88: Edge Cases & Error Messages
**Estimated: 3-4 hours total**

- [ ] Review all TypeScript error messages
- [ ] Add helpful hints for common mistakes
- [ ] Handle edge cases (e.g., `<` ambiguity in JSX)
- [ ] Test: Error recovery

**Files to modify:** All parser files

---

### Day 89-90: Final Testing & Documentation
**Estimated: 3-4 hours total**

- [ ] Create comprehensive test suite covering all TypeScript features
- [ ] Test against real-world TypeScript projects
- [ ] Update documentation
- [ ] Celebrate! 🎉

**Files to create:** `tests/ts/`, update `README.md`

---

## 📊 Progress Tracking

Use this checklist to track your progress:

- [ ] Phase 1: Foundation & Basic Types (14 days)
- [ ] Phase 2: Function Types & Declarations (14 days)
- [ ] Phase 3: Interfaces & Classes (14 days)
- [ ] Phase 4: Advanced Types (14 days)
- [ ] Phase 5: Declarations & Modules (13 days)
- [ ] Phase 6: Type Assertions & Special Features (11 days)
- [ ] Phase 7: Polish & Integration (10 days)

**Total: ~90 days at 1-2 hours/day**

---

## 💡 Tips for Success

### 1. **Start with Tests**
Write test cases before implementing each feature. It clarifies what you're building and gives you instant feedback.

### 2. **Reference Existing Code**
Your JavaScript and JSX parsers are great references! TypeScript syntax often mirrors JavaScript with type annotations.

### 3. **Use the AST Reference**
Keep `ast-reference.ts` open. It shows exactly what each node should look like.

### 4. **Handle Ambiguities Early**
TypeScript has some parsing ambiguities (especially `<` in `.tsx`). Address these as you encounter them.

### 5. **Incremental Commits**
Commit after each day's work. It makes rollbacks easier and tracks your progress.

### 6. **Test with Real Code**
Regularly test your parser against real TypeScript files from popular projects (React, Vue, etc.).

### 7. **Don't Skip the Easy Wins**
The early phases have lots of simple keywords that work immediately—these build momentum!

### 8. **Celebrate Milestones**
After each phase, test with a real TypeScript file and watch it parse. It's incredibly satisfying!

---

## 🎯 Key Architecture Decisions

### Type Context
You'll need to track when you're in a "type context" vs. an "expression context". Add a flag to `ParserContext`:

```zig
const ParserContext = struct {
    in_async: bool = false,
    in_generator: bool = false,
    allow_in: bool = true,
    in_function: bool = false,
    in_type: bool = false,  // NEW: Track type context
    // ...
};
```

### Lookahead for Ambiguity
TypeScript requires more lookahead than JavaScript (especially for `<` vs JSX). Your existing `lookAhead` function will be crucial.

### Separate Type Parser
Consider creating a dedicated type parsing function similar to how you parse expressions:

```zig
pub fn parseType(parser: *Parser, precedence: u8) Error!?ast.NodeIndex
```

### Reuse Pattern Matching
Many TypeScript constructs mirror JavaScript patterns. For example, object type literals are like object patterns with type annotations.

---

## 🚨 Common Pitfalls to Avoid

1. **JSX/TSX Ambiguity**: `<T>` could be a type parameter or JSX. In `.tsx`, prefer JSX unless followed by `(` or `extends`.

2. **Arrow Function Ambiguity**: `(x) => x` could be a value or a type. Context matters!

3. **Index Signature vs Computed Property**: `[key: string]` is an index signature in types, but computed property in objects.

4. **Type vs Value Namespace**: TypeScript has separate type and value namespaces. `type Foo = ...` doesn't conflict with `const Foo = ...`.

5. **Modifier Ordering**: TypeScript is strict about modifier order. `public static readonly` is valid, `static public readonly` is not.

---

## 🎉 Motivation Boosts

### Week 1-2: Foundation
"You'll parse your first typed TypeScript file by day 10!"

### Week 3-4: Functions
"Generics are the heart of TypeScript—this makes you a TypeScript parser!"

### Week 5-6: Interfaces
"Classes and interfaces working = you can parse most real-world TypeScript!"

### Week 7-8: Advanced
"These advanced types power TypeScript's type system. Almost there!"

### Week 9-10: Declarations
"Module and namespace support = you can parse any TypeScript project structure!"

### Week 11-13: Polish
"Final stretch! Your parser will soon handle the full TypeScript language!"

---

## 📚 Resources

- **TypeScript Handbook**: https://www.typescriptlang.org/docs/handbook/
- **TypeScript AST Viewer**: https://ts-ast-viewer.com/
- **ESTree TypeScript**: https://github.com/typescript-eslint/typescript-eslint/tree/main/packages/ast-spec
- **Your Success**: `ast-reference.ts` + your existing parser architecture!

---

## 🏁 Final Thoughts

This roadmap is designed to give you early wins (weeks 1-2) while building toward the complex features (weeks 7-8). Each day's work is scoped to 1-2 hours, and you'll have working TypeScript features by the end of week 2!

The progressive structure means:
- **Days 1-30**: You'll see immediate results and build confidence
- **Days 31-60**: You'll tackle the powerful features that make TypeScript special
- **Days 61-90**: You'll polish and complete the full language implementation

Remember: You've already built JavaScript and JSX parsers. TypeScript is just JavaScript with types—and types follow similar parsing patterns to expressions. You've got this! 💪

Start with Day 1 tomorrow. Read the tokens. See them parse. Feel the momentum. By day 14, you'll have typed variables working. By day 30, you'll have generic functions. By day 90, you'll have a complete TypeScript parser!

**Let's do this! 🚀**
