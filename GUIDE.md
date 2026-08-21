# 🤖 SwiftDataAnalyst-Agent — DSL Grammar & RAG Architecture Guide

This guide details the Domain-Specific Language (DSL) execution engine and RAG context generator used by **SwiftDataAnalyst-Agent**.

---

## 1. Sandboxed DSL Grammar Specification

To guarantee safety against arbitrary code execution (prompt injection attacks), `SwiftAgentEvaluator` utilizes an AST parser supporting strict grammar primitives:

```
<Command>  ::= "filter" <Condition> | "select" <IdentList> | "head" <Int> | "tail" <Int> | "groupby" <Ident>
<Condition>::= <Ident> <Op> <Literal>
<Op>       ::= "==" | "!=" | ">" | "<" | ">=" | "<="
```

---

## 2. Token-Efficient RAG Context Synthesis

`RAGContextGenerator` inspects in-memory `DataFrame` buffers to emit minimal-token schema summaries:

```markdown
## Dataset Profile
- Rows: 500, Columns: 6
- Columns: [customer_id (Int64), category (String), order_value (Double), churn_risk (Double)]
- Numeric Summary:
  - order_value: min=12.4, mean=248.9, max=980.2
```
