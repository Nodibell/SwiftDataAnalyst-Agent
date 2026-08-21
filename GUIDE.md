# 🤖 SwiftDataAnalyst-Agent — Technical Architecture & Agent DSL Guide

This guide details the Sandboxed AST Domain-Specific Language (DSL), RAG context synthesis, and native wire protocol drivers in **SwiftDataAnalyst-Agent**.

---

## 1. System Pipeline & Agent Loop

```mermaid
flowchart TD
    subgraph Natural Language Ingestion
        A[User Business Query] --> B[LLM Reasoning & Intent Decomposition]
    end

    subgraph Context Synthesis
        C[SwiftDataFrame Schema Profile] --> D[SwiftAgent: RAGContextGenerator]
        D --> B
    end

    subgraph Sandboxed Execution
        B --> E[Structured AST DSL Pipeline]
        E --> F[SwiftAgentEvaluator Safe Execution Engine]
        F --> G[SwiftDataFrame Vectorized Query]
    end

    subgraph Reporting
        G --> H[Tabular Summary & Key Findings Output]
    end
```

---

## 2. Sandboxed DSL Grammar Specification

To prevent code injection vulnerabilities and prompt-leakage risks, the agent uses an Abstract Syntax Tree (AST) grammar evaluator without relying on dynamic runtime code evaluation:

```ebnf
<Command>     ::= "filter" <Condition>
                | "select" <IdentifierList>
                | "head" <Integer>
                | "tail" <Integer>
                | "sample" <Integer>
                | "groupby" <Identifier>
                | "rename" <Identifier> "to" <Identifier>
                | "dropnulls"
                | "fillnulls" <Literal>

<Condition>   ::= <Identifier> <Operator> <Literal>
<Operator>    ::= "==" | "!=" | ">" | "<" | ">=" | "<="
<Literal>     ::= <StringLiteral> | <NumberLiteral>
```

---

## 3. Token-Efficient RAG Schema Extraction

`RAGContextGenerator` analyzes tabular data buffers in memory to generate compact markdown descriptors for Large Language Model (LLM) prompts:

```markdown
## Dataset Profile
- Rows: 500, Columns: 6
- Schema: customer_id (Int64), age (Double), country (String), category (String), order_value (Double), churn_risk (Double)
- Numeric Distribution:
  - order_value: [min: 12.5, mean: 556.0, max: 998.4]
  - churn_risk:  [min: 0.05, mean: 0.48, max: 0.95]
```
